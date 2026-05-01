import Foundation

enum MessageRole: String, Codable {
    case user
    case assistant
    case system

    var label: String {
        switch self {
        case .user: "You"
        case .assistant: "Talkie"
        case .system: "System"
        }
    }
}

struct ChatMessage: Identifiable, Codable, Equatable {
    let id: UUID
    var role: MessageRole
    var text: String
    var createdAt: Date

    init(id: UUID = UUID(), role: MessageRole, text: String, createdAt: Date = Date()) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = createdAt
    }
}

struct GenerationSettings: Equatable {
    var temperature: Double = 0.0
    var topP: Double = 0.9
    var maxTokens: Int = 256
}

enum ConversationMode: String, CaseIterable, Identifiable {
    case chat = "Chat"
    case ask = "Ask"
    case rewrite = "Rewrite"
    case debug = "Debug"

    var id: String { rawValue }
}

enum ContextMode: String, CaseIterable, Identifiable {
    case latest = "Latest"
    case pinned = "Pinned"
    case none = "None"

    var id: String { rawValue }

    var caption: String {
        switch self {
        case .latest: "Latest user turn"
        case .pinned: "Pinned turns + latest"
        case .none: "Prompt only"
        }
    }
}

struct RuntimeMetrics: Equatable {
    var promptTokens: Int = 0
    var promptTokensPerSecond: Double = 0
    var generationTokens: Int = 0
    var generationTokensPerSecond: Double = 0
    var peakMemoryGB: Double = 0
    var loadSeconds: Double = 0
}

struct PromptPreset: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let subtitle: String
    let prompt: String
}

enum RuntimeState: Equatable {
    case idle
    case loading
    case ready
    case generating
    case failed(String)

    var title: String {
        switch self {
        case .idle: "Idle"
        case .loading: "Loading MLX"
        case .ready: "Ready"
        case .generating: "On the air"
        case .failed: "Needs attention"
        }
    }

    var detail: String {
        switch self {
        case .idle:
            "Waiting for the local worker."
        case .loading:
            "Opening the q4 MLX cabinet."
        case .ready:
            "Local MLX q4 is warmed and listening."
        case .generating:
            "Talkie is composing a reply."
        case .failed(let message):
            message
        }
    }
}

struct TalkieServerEvent: Decodable {
    let type: String
    let id: String?
    let status: String?
    let text: String?
    let message: String?
    let model: String?
    let loadSeconds: Double?
    let promptTokens: Int?
    let promptTps: Double?
    let generationTokens: Int?
    let generationTps: Double?
    let peakMemory: Double?
    let finishReason: String?
}
