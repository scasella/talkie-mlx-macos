import Foundation

final class TalkieProcessService {
    private static let defaultSystemPrompt = "Answer naturally in clear English. Do not mention Talkie unless the user asks your name."
    private static let modelDirectoryName = "talkie-1930-13b-it-MLX-q4"

    private var process: Process?
    private var input: FileHandle?
    private let outputPipe = Pipe()
    private let errorPipe = Pipe()
    private let inputPipe = Pipe()
    private let decodeQueue = DispatchQueue(label: "TalkieProcessService.decode")
    private var outputBuffer = Data()
    private var continuation: AsyncStream<TalkieServerEvent>.Continuation?

    lazy var events: AsyncStream<TalkieServerEvent> = {
        AsyncStream { continuation in
            self.continuation = continuation
        }
    }()

    var isRunning: Bool {
        process?.isRunning == true
    }

    func startIfNeeded() {
        guard process?.isRunning != true else { return }

        let root = Self.resolveRoot()
        let appHome = Self.resolveAppHome()
        let python = Self.firstExistingExecutable(Self.pythonCandidates(root: root, appHome: appHome))
            ?? Self.pythonCandidates(root: root, appHome: appHome)[0]
        let model = Self.firstExistingPath(Self.modelCandidates(root: root, appHome: appHome))
            ?? Self.modelCandidates(root: root, appHome: appHome)[0]
        let server = Bundle.main.url(forResource: "talkie_mlx_server", withExtension: "py")?
            .path ?? "\(root)/Sources/TalkieCabinet/Resources/talkie_mlx_server.py"

        guard FileManager.default.isExecutableFile(atPath: python) else {
            yield(.init(type: "error", id: nil, status: nil, text: nil, message: "Python worker not found. Run scripts/download_model.sh or set TALKIE_MLX_PYTHON. Tried \(python)", model: nil, loadSeconds: nil, promptTokens: nil, promptTps: nil, generationTokens: nil, generationTps: nil, peakMemory: nil, finishReason: nil))
            return
        }

        guard FileManager.default.fileExists(atPath: model) else {
            yield(.init(type: "error", id: nil, status: nil, text: nil, message: "MLX model not found. Run scripts/download_model.sh or set TALKIE_MLX_MODEL. Tried \(model)", model: nil, loadSeconds: nil, promptTokens: nil, promptTps: nil, generationTokens: nil, generationTps: nil, peakMemory: nil, finishReason: nil))
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: python)
        process.arguments = [server, "--model", model]
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        var environment = ProcessInfo.processInfo.environment
        environment["PYTHONUNBUFFERED"] = "1"
        process.environment = environment

        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            self?.decodeQueue.async {
                self?.consumeOutput(data)
            }
        }

        errorPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            self?.yield(.init(type: "log", id: nil, status: nil, text: nil, message: text.trimmingCharacters(in: .whitespacesAndNewlines), model: nil, loadSeconds: nil, promptTokens: nil, promptTps: nil, generationTokens: nil, generationTps: nil, peakMemory: nil, finishReason: nil))
        }

        process.terminationHandler = { [weak self] process in
            self?.yield(.init(type: "exit", id: nil, status: nil, text: nil, message: "Worker exited with status \(process.terminationStatus)", model: nil, loadSeconds: nil, promptTokens: nil, promptTps: nil, generationTokens: nil, generationTps: nil, peakMemory: nil, finishReason: nil))
        }

        do {
            try process.run()
            self.process = process
            self.input = inputPipe.fileHandleForWriting
        } catch {
            yield(.init(type: "error", id: nil, status: nil, text: nil, message: error.localizedDescription, model: nil, loadSeconds: nil, promptTokens: nil, promptTps: nil, generationTokens: nil, generationTps: nil, peakMemory: nil, finishReason: nil))
        }
    }

    func generate(id: UUID, messages: [ChatMessage], settings: GenerationSettings) throws {
        let payloadMessages = Self.modelMessages(from: messages)

        let payload: [String: Any] = [
            "type": "generate",
            "id": id.uuidString,
            "messages": payloadMessages,
            "temperature": settings.temperature,
            "top_p": settings.topP,
            "max_tokens": settings.maxTokens,
            "stop_after_sentence": Self.shouldStopAfterSentence(payloadMessages)
        ]
        try write(payload)
    }

    func cancel() {
        try? write(["type": "cancel"])
    }

    func stop() {
        outputPipe.fileHandleForReading.readabilityHandler = nil
        errorPipe.fileHandleForReading.readabilityHandler = nil
        process?.terminate()
        process = nil
    }

    private func write(_ object: [String: Any]) throws {
        guard let input else { throw TalkieProcessError.notRunning }
        let data = try JSONSerialization.data(withJSONObject: object, options: [])
        input.write(data)
        input.write(Data([0x0a]))
    }

    private func consumeOutput(_ data: Data) {
        outputBuffer.append(data)
        while let newline = outputBuffer.firstIndex(of: 0x0a) {
            let line = outputBuffer.prefix(upTo: newline)
            outputBuffer.removeSubrange(...newline)
            guard !line.isEmpty else { continue }
            do {
                let event = try JSONDecoder().decode(TalkieServerEvent.self, from: line)
                yield(event)
            } catch {
                let raw = String(data: line, encoding: .utf8) ?? "<binary>"
                yield(.init(type: "log", id: nil, status: nil, text: nil, message: "Could not parse worker line: \(raw)", model: nil, loadSeconds: nil, promptTokens: nil, promptTps: nil, generationTokens: nil, generationTps: nil, peakMemory: nil, finishReason: nil))
            }
        }
    }

    private func yield(_ event: TalkieServerEvent) {
        continuation?.yield(event)
    }

    private static func modelMessages(from messages: [ChatMessage]) -> [[String: String]] {
        guard let latestUser = messages.last(where: { $0.role == .user }) else {
            return []
        }

        let userContent = modelUserContent(for: sanitizedModelContent(latestUser.text))
        guard !userContent.isEmpty else {
            return []
        }

        return [
            [
                "role": "system",
                "content": defaultSystemPrompt
            ],
            [
                "role": "user",
                "content": userContent
            ]
        ]
    }

    private static func sanitizedModelContent(_ text: String) -> String {
        var sanitized = text
        for token in ["<|endoftext|>", "<|end|>", "<|user|>", "<|assistant|>", "<|system|>"] {
            sanitized = sanitized.replacingOccurrences(of: token, with: "")
        }
        return sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func modelUserContent(for text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let lowercased = trimmed.lowercased()
        if lowercased.contains("story") || lowercased.contains("tale") {
            return "Write a short original story in response to this request: \"\(trimmed)\" Begin with the first sentence of the story, without preface or permission."
        }

        if isGreetingQuestion(lowercased) {
            return "\(trimmed) Reply warmly in one complete sentence."
        }

        return trimmed
    }

    private static func isGreetingQuestion(_ lowercased: String) -> Bool {
        let hasGreeting = ["hello", "hi", "good morning", "good afternoon", "good evening", "how do you do"].contains {
            lowercased.contains($0)
        }
        return hasGreeting && lowercased.contains("how") && lowercased.contains("you")
    }

    private static func shouldStopAfterSentence(_ messages: [[String: String]]) -> Bool {
        guard let userContent = messages.last(where: { $0["role"] == "user" })?["content"] else {
            return false
        }

        let lowercased = userContent.lowercased()
        if lowercased.contains("one sentence") || lowercased.contains("one short sentence") {
            return true
        }

        let longFormMarkers = [
            "essay", "story", "poem", "list", "explain", "describe", "paragraph",
            "letter", "write ", "compose", "draft", "analyze", "summarize",
            "compare", "why ", "how "
        ]

        if userContent.count > 160 {
            return false
        }

        return !longFormMarkers.contains { lowercased.contains($0) }
    }

    private static func resolveRoot() -> String {
        if let root = Bundle.main.object(forInfoDictionaryKey: "TalkieCabinetRoot") as? String {
            return root
        }
        return FileManager.default.currentDirectoryPath
    }

    private static func resolveAppHome() -> String {
        if let home = ProcessInfo.processInfo.environment["TALKIE_CABINET_HOME"], !home.isEmpty {
            return NSString(string: home).expandingTildeInPath
        }

        return FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Talkie Cabinet")
            .path
    }

    private static func pythonCandidates(root: String, appHome: String) -> [String] {
        if let python = ProcessInfo.processInfo.environment["TALKIE_MLX_PYTHON"], !python.isEmpty {
            return [NSString(string: python).expandingTildeInPath]
        }

        return [
            "\(appHome)/.venv/bin/python",
            "\(root)/.venv/bin/python",
            "/opt/homebrew/bin/python3",
            "/usr/bin/python3"
        ]
    }

    private static func modelCandidates(root: String, appHome: String) -> [String] {
        if let model = ProcessInfo.processInfo.environment["TALKIE_MLX_MODEL"], !model.isEmpty {
            return [NSString(string: model).expandingTildeInPath]
        }

        return [
            "\(appHome)/Models/\(modelDirectoryName)",
            "\(root)/Models/\(modelDirectoryName)"
        ]
    }

    private static func firstExistingExecutable(_ paths: [String]) -> String? {
        paths.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    private static func firstExistingPath(_ paths: [String]) -> String? {
        paths.first { FileManager.default.fileExists(atPath: $0) }
    }
}

enum TalkieProcessError: LocalizedError {
    case notRunning

    var errorDescription: String? {
        switch self {
        case .notRunning: "Talkie worker is not running."
        }
    }
}
