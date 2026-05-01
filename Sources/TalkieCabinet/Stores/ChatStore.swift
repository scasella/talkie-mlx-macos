import AppKit
import Foundation

@MainActor
final class ChatStore: ObservableObject {
    @Published var messages: [ChatMessage] = [
        ChatMessage(role: .assistant, text: "Good evening. I am Talkie, presently resident in a local MLX cabinet. Ask, and I shall endeavor to answer in a suitable hand.")
    ]
    @Published var draft = ""
    @Published var runtimeState: RuntimeState = .idle
    @Published var settings = GenerationSettings()
    @Published var metrics = RuntimeMetrics()
    @Published var selectedPresetID: PromptPreset.ID?
    @Published var workerLog = ""
    @Published var showSidebar = true
    @Published var showInspector = true
    @Published var sidebarFilter = ""
    @Published var selectedMessageID: UUID?
    @Published var pinnedMessageIDs: Set<UUID> = []
    @Published var showPayloadPreview = false
    @Published var conversationMode: ConversationMode = .chat
    @Published var contextMode: ContextMode = .latest
    @Published var branchLabel = "Main"
    @Published var findingNote = "Mac q4-safe default: deterministic decode, BF16 LM head and value projections, app identity kept out of ordinary prompts."
    @Published var findingTags: Set<String> = ["good"]

    let presets: [PromptPreset] = [
        PromptPreset(
            title: "Wireless Note",
            subtitle: "A short radio-era reply",
            prompt: "Write one short sentence in the style of early twentieth century prose about a wireless radio."
        ),
        PromptPreset(
            title: "Future Essay",
            subtitle: "A 1930 view of tomorrow",
            prompt: "Write an essay predicting what life will be like in the year 1960."
        ),
        PromptPreset(
            title: "Etiquette",
            subtitle: "Advice from the parlor",
            prompt: "How should a young person compose a courteous letter declining an invitation?"
        ),
        PromptPreset(
            title: "Reference Desk",
            subtitle: "Concise historical explanation",
            prompt: "Explain the principal causes of the French Revolution in plain language."
        )
    ]

    private let service = TalkieProcessService()
    private var eventTask: Task<Void, Never>?
    private var activeAssistantID: UUID?
    private var activeRequestID: UUID?

    var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && runtimeState == .ready
            && !isGenerating
    }

    var isGenerating: Bool {
        if case .generating = runtimeState { return true }
        return false
    }

    var activePromptStack: [PromptPreset] {
        guard let selectedPresetID else { return [] }
        return presets.filter { $0.id == selectedPresetID }
    }

    var visiblePresets: [PromptPreset] {
        let query = sidebarFilter.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return presets }
        return presets.filter {
            $0.title.localizedCaseInsensitiveContains(query)
                || $0.subtitle.localizedCaseInsensitiveContains(query)
                || $0.prompt.localizedCaseInsensitiveContains(query)
        }
    }

    var contextEstimate: Int {
        let messageCharacters: Int
        switch contextMode {
        case .latest:
            messageCharacters = messages.suffix(4).map(\.text.count).reduce(0, +)
        case .pinned:
            messageCharacters = messages
                .filter { pinnedMessageIDs.contains($0.id) || $0.role == .user }
                .suffix(8)
                .map(\.text.count)
                .reduce(0, +)
        case .none:
            messageCharacters = 0
        }

        let draftCharacters = draft.count + activePromptStack.map(\.prompt.count).reduce(0, +)
        return max(1, Int(ceil(Double(messageCharacters + draftCharacters) / 4.0)))
    }

    var contextBudget: Int {
        4096
    }

    var contextFill: Double {
        min(1.0, Double(contextEstimate) / Double(contextBudget))
    }

    var payloadPreview: String {
        let system = "Answer naturally in clear English. Do not mention Talkie unless the user asks your name."
        let latestUser = draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? messages.last(where: { $0.role == .user })?.text ?? ""
            : draft.trimmingCharacters(in: .whitespacesAndNewlines)
        let slips = activePromptStack.map { "- \($0.title): \($0.prompt)" }.joined(separator: "\n")

        return """
        System
        \(system)

        Mode
        \(conversationMode.rawValue)

        Context
        \(contextMode.caption) • ~\(contextEstimate) tokens

        Prompt stack
        \(slips.isEmpty ? "None" : slips)

        User
        \(latestUser.isEmpty ? "No draft or prior user turn." : latestUser)
        """
    }

    func bootstrap() async {
        guard eventTask == nil else { return }
        runtimeState = .loading
        eventTask = Task { [weak self] in
            guard let self else { return }
            for await event in service.events {
                self.handle(event)
            }
        }
        service.startIfNeeded()
    }

    func applyPreset(_ preset: PromptPreset) {
        selectedPresetID = preset.id
        draft = preset.prompt
    }

    func sendDraft() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, runtimeState == .ready else { return }

        await send(text: text)
    }

    func retryLast() async {
        guard let text = messages.last(where: { $0.role == .user })?.text else { return }
        guard runtimeState == .ready else { return }
        await send(text: text)
    }

    func retry(from message: ChatMessage) async {
        guard runtimeState == .ready else { return }
        guard let index = messages.firstIndex(where: { $0.id == message.id }) else { return }
        let priorMessages = messages[...index]
        guard let user = priorMessages.reversed().first(where: { $0.role == .user }) else { return }
        await send(text: user.text)
    }

    func togglePin(_ message: ChatMessage) {
        if pinnedMessageIDs.contains(message.id) {
            pinnedMessageIDs.remove(message.id)
        } else {
            pinnedMessageIDs.insert(message.id)
        }
    }

    func copyMessage(_ message: ChatMessage) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(message.text, forType: .string)
    }

    func copyPayloadPreview() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(payloadPreview, forType: .string)
    }

    func startBranch(from message: ChatMessage) {
        selectedMessageID = message.id
        branchLabel = "Branch \(messages.firstIndex(where: { $0.id == message.id }).map { $0 + 1 } ?? 1)"
        pinnedMessageIDs.insert(message.id)
    }

    func requestRemoveMessage(_ message: ChatMessage) {
        let alert = NSAlert()
        alert.messageText = "Delete this transcript turn?"
        alert.informativeText = "This removes the selected turn from the local transcript."
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        removeMessage(message)
    }

    private func removeMessage(_ message: ChatMessage) {
        guard messages.count > 1 else { return }
        messages.removeAll { $0.id == message.id }
        pinnedMessageIDs.remove(message.id)
        if selectedMessageID == message.id {
            selectedMessageID = nil
        }
    }

    func requestClearConversation() {
        let alert = NSAlert()
        alert.messageText = "Clear this transcript?"
        alert.informativeText = "This starts a fresh local conversation and removes the visible transcript turns."
        alert.addButton(withTitle: "Clear")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        clearConversation()
    }

    private func clearConversation() {
        messages = [
            ChatMessage(role: .assistant, text: "Good evening. I am Talkie, presently resident in a local MLX cabinet. Ask, and I shall endeavor to answer in a suitable hand.")
        ]
        pinnedMessageIDs.removeAll()
        selectedMessageID = nil
        branchLabel = "Main"
    }

    func toggleFindingTag(_ tag: String) {
        if findingTags.contains(tag) {
            findingTags.remove(tag)
        } else {
            findingTags.insert(tag)
        }
    }

    private func send(text: String) async {
        guard runtimeState == .ready else { return }

        draft = ""
        messages.append(ChatMessage(role: .user, text: text))

        if let localReply = Self.localReply(for: text) {
            messages.append(ChatMessage(role: .assistant, text: localReply))
            runtimeState = .ready
            return
        }

        let assistantID = UUID()
        activeAssistantID = assistantID
        activeRequestID = UUID()
        messages.append(ChatMessage(id: assistantID, role: .assistant, text: ""))
        runtimeState = .generating

        do {
            let history = messages.filter { $0.id != assistantID }
            try service.generate(id: activeRequestID!, messages: history, settings: settings)
        } catch {
            runtimeState = .failed(error.localizedDescription)
        }
    }

    func stopGeneration() {
        service.cancel()
        runtimeState = .ready
    }

    private func handle(_ event: TalkieServerEvent) {
        switch event.type {
        case "status":
            if event.status == "loading" {
                runtimeState = .loading
            }
        case "ready":
            metrics.loadSeconds = event.loadSeconds ?? metrics.loadSeconds
            metrics.peakMemoryGB = event.peakMemory ?? metrics.peakMemoryGB
            runtimeState = .ready
        case "delta":
            appendAssistantText(event.text ?? "")
            updateMetrics(event)
        case "done":
            updateMetrics(event)
            runtimeState = .ready
            activeAssistantID = nil
            activeRequestID = nil
        case "error":
            runtimeState = .failed(event.message ?? "The worker reported an error.")
        case "exit":
            if runtimeState != .idle {
                runtimeState = .failed(event.message ?? "The worker exited.")
            }
        case "log":
            if let message = event.message, !message.isEmpty {
                workerLog = message
            }
        default:
            break
        }
    }

    private func appendAssistantText(_ text: String) {
        guard !text.isEmpty, let activeAssistantID else { return }
        guard let index = messages.firstIndex(where: { $0.id == activeAssistantID }) else { return }
        messages[index].text += text
    }

    private func updateMetrics(_ event: TalkieServerEvent) {
        metrics.promptTokens = event.promptTokens ?? metrics.promptTokens
        metrics.promptTokensPerSecond = event.promptTps ?? metrics.promptTokensPerSecond
        metrics.generationTokens = event.generationTokens ?? metrics.generationTokens
        metrics.generationTokensPerSecond = event.generationTps ?? metrics.generationTokensPerSecond
        metrics.peakMemoryGB = event.peakMemory ?? metrics.peakMemoryGB
    }

    private static func localReply(for text: String) -> String? {
        let lowercased = text.lowercased()
        let asksName = lowercased.contains("your name")
            || lowercased.contains("who are you")
            || lowercased.contains("what are you called")
        return asksName ? "My name is Talkie." : nil
    }
}
