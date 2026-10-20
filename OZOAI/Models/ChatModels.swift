import Foundation

struct ChatMessage: Identifiable, Codable, Hashable {
    enum Role: String, Codable, Hashable {
        case user
        case assistant
    }

    var id: UUID
    var role: Role
    var text: String
    var imageData: Data?
    var createdAt: Date
    var modelName: String?

    init(
        id: UUID = UUID(),
        role: Role,
        text: String,
        imageData: Data? = nil,
        createdAt: Date = Date(),
        modelName: String? = nil
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.imageData = imageData
        self.createdAt = createdAt
        self.modelName = modelName
    }
}

struct Conversation: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var modelID: String
    var messages: [ChatMessage]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String = "New chat",
        modelID: String = AIModel.defaultID,
        messages: [ChatMessage] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.modelID = modelID
        self.messages = messages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var isEmpty: Bool { messages.isEmpty }

    var lastMessage: ChatMessage? { messages.last }

    var preview: String {
        guard let last = messages.last else { return "No messages yet" }
        if last.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return last.imageData == nil ? "No messages yet" : "Photo"
        }
        return last.text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func matches(_ query: String) -> Bool {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return true }
        if title.localizedCaseInsensitiveContains(needle) { return true }
        if preview.localizedCaseInsensitiveContains(needle) { return true }
        return messages.contains { $0.text.localizedCaseInsensitiveContains(needle) }
    }
}

struct ConversationArchive: Codable {
    var conversations: [Conversation]
    var currentID: UUID?

    init(conversations: [Conversation] = [], currentID: UUID? = nil) {
        self.conversations = conversations
        self.currentID = currentID
    }
}
