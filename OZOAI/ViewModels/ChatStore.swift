import Foundation
import SwiftUI
import UIKit

@MainActor
final class ChatStore: ObservableObject {
    @Published private(set) var conversations: [Conversation]
    @Published var currentID: UUID?
    @Published var draft: String = ""
    @Published private(set) var streamingText: String = ""
    @Published private(set) var isStreaming: Bool = false
    @Published var errorText: String?

    private let storage = ConversationStorage()
    private let client = OpenCodeClient.shared
    private var streamTask: Task<Void, Never>?
    private var streamToken = UUID()
    private var activeConversationID: UUID?
    private var activeModelName: String?

    init() {
        var archive = storage.load()

        // If a model was retired since a chat was saved, fall back to the
        // default instead of sending an unknown model ID forever.
        for index in archive.conversations.indices {
            let id = archive.conversations[index].modelID
            if !AIModel.all.contains(where: { $0.id == id }) {
                archive.conversations[index].modelID = AIModel.defaultID
            }
        }

        let sorted = archive.conversations.sorted { $0.updatedAt > $1.updatedAt }
        conversations = sorted

        if let savedID = archive.currentID,
           sorted.contains(where: { $0.id == savedID }) {
            currentID = savedID
        } else {
            currentID = sorted.first?.id
        }
    }

    // MARK: - Read

    var currentConversation: Conversation? {
        guard let currentID else { return nil }
        return conversations.first(where: { $0.id == currentID })
    }

    var messages: [ChatMessage] {
        currentConversation?.messages ?? []
    }

    var lastAssistantID: UUID? {
        messages.last(where: { $0.role == .assistant })?.id
    }

    var sortedConversations: [Conversation] {
        conversations.sorted { $0.updatedAt > $1.updatedAt }
    }

    var selectedModelID: String? {
        currentConversation?.modelID
    }

    var exportText: String {
        guard let conversation = currentConversation, !conversation.messages.isEmpty else {
            return "OZO AI — a chat with ten free AI models."
        }

        var lines: [String] = [
            conversation.title,
            "Model: \(AIModel.model(for: conversation.modelID).name)",
            ""
        ]

        for message in conversation.messages {
            lines.append(message.role == .user ? "You" : "OZO AI")
            lines.append(message.text.isEmpty ? "[Photo]" : message.text)
            lines.append("")
        }

        lines.append("— Shared from OZO AI")
        return lines.joined(separator: "\n")
    }

    // MARK: - Conversations

    func newChat() {
        stop()
        draft = ""
        errorText = nil
        currentID = nil
        persist()
    }

    func select(_ conversation: Conversation) {
        if currentID == conversation.id { return }
        stop()
        currentID = conversation.id
        draft = ""
        errorText = nil
        persist()
    }

    func rename(_ conversation: Conversation, to newTitle: String) {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let index = conversations.firstIndex(where: { $0.id == conversation.id }) else {
            return
        }
        conversations[index].title = trimmed
        persist()
    }

    func delete(_ conversation: Conversation) {
        if activeConversationID == conversation.id {
            abortStreaming(keepPartial: false)
        }
        if currentID == conversation.id {
            currentID = nil
        }
        conversations.removeAll(where: { $0.id == conversation.id })
        persist()
    }

    func deleteAll() {
        abortStreaming(keepPartial: false)
        conversations = []
        currentID = nil
        errorText = nil
        draft = ""
        storage.clear()
    }

    func clearCurrentMessages() {
        guard var conversation = currentConversation else { return }
        stop()
        conversation.messages = []
        conversation.title = "New chat"
        conversation.updatedAt = Date()
        upsert(conversation)
        persist()
    }

    func setModel(_ modelID: String, for conversationID: UUID?) {
        guard let conversationID,
              let index = conversations.firstIndex(where: { $0.id == conversationID }) else {
            return
        }
        conversations[index].modelID = modelID
        persist()
    }

    // MARK: - Sending

    func send(
        text: String,
        imageData: Data?,
        modelID: String,
        apiKey: String,
        systemPrompt: String,
        temperature: Double
    ) {
        settleStreamingState()

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || imageData != nil else { return }
        guard !isStreaming else { return }
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorText = OpenCodeError.missingAPIKey.localizedDescription
            return
        }

        errorText = nil

        var conversation = currentConversation ?? Conversation(modelID: modelID)
        let isFirstMessage = conversation.messages.isEmpty

        if isFirstMessage {
            conversation.title = Self.makeTitle(from: trimmed, hasImage: imageData != nil)
        }

        conversation.modelID = modelID
        conversation.messages.append(
            ChatMessage(role: .user, text: trimmed, imageData: imageData)
        )
        conversation.updatedAt = Date()

        upsert(conversation)
        currentID = conversation.id
        draft = ""
        persist()

        beginStreaming(
            conversation: conversation,
            apiKey: apiKey,
            systemPrompt: systemPrompt,
            temperature: temperature
        )
    }

    func regenerate(
        apiKey: String,
        systemPrompt: String,
        temperature: Double
    ) {
        guard !isStreaming, var conversation = currentConversation else { return }
        guard conversation.messages.contains(where: { $0.role == .user }) else { return }
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorText = OpenCodeError.missingAPIKey.localizedDescription
            return
        }

        if conversation.messages.last?.role == .assistant {
            conversation.messages.removeLast()
        }

        conversation.updatedAt = Date()
        upsert(conversation)
        currentID = conversation.id
        errorText = nil
        persist()

        beginStreaming(
            conversation: conversation,
            apiKey: apiKey,
            systemPrompt: systemPrompt,
            temperature: temperature
        )
    }

    func stop() {
        abortStreaming(keepPartial: true)
    }

    // MARK: - Streaming internals

    private func beginStreaming(
        conversation: Conversation,
        apiKey: String,
        systemPrompt: String,
        temperature: Double
    ) {
        settleStreamingState()

        let token = UUID()
        streamToken = token
        activeConversationID = conversation.id
        activeModelName = AIModel.model(for: conversation.modelID).shortName
        isStreaming = true
        streamingText = ""
        errorText = nil

        let conversationID = conversation.id
        let modelID = conversation.modelID
        let supportsVision = AIModel.model(for: modelID).supportsVision
        let wireMessages = Self.wireMessages(
            from: conversation,
            systemPrompt: systemPrompt,
            supportsVision: supportsVision
        )

        streamTask = Task { [weak self] in
            guard let self else { return }

            var accumulated = ""
            var pending = ""
            var lastFlush = Date.distantPast

            do {
                let stream = self.client.streamChat(
                    apiKey: apiKey,
                    modelID: modelID,
                    messages: wireMessages,
                    temperature: temperature
                )

                for try await piece in stream {
                    if Task.isCancelled { break }
                    pending += piece

                    let now = Date()
                    if now.timeIntervalSince(lastFlush) >= 0.03 {
                        accumulated += pending
                        pending = ""
                        lastFlush = now
                        if self.streamToken == token {
                            self.streamingText = accumulated
                        }
                    }
                }

                accumulated += pending

                guard !Task.isCancelled, self.streamToken == token else { return }
                self.finalizeStream(
                    conversationID: conversationID,
                    token: token,
                    text: accumulated
                )
            } catch {
                accumulated += pending

                guard self.streamToken == token else { return }

                let isCancellation = error is CancellationError
                    || (error as? URLError)?.code == .cancelled

                if isCancellation {
                    self.finalizeStream(
                        conversationID: conversationID,
                        token: token,
                        text: accumulated
                    )
                } else {
                    self.isStreaming = false
                    self.streamingText = ""
                    self.streamTask = nil
                    self.activeConversationID = nil
                    self.activeModelName = nil
                    self.streamToken = UUID()
                    self.errorText = Self.friendlyMessage(for: error)
                }
            }
        }
    }

    private func finalizeStream(conversationID: UUID, token: UUID, text: String) {
        guard streamToken == token else { return }

        isStreaming = false
        streamingText = ""
        streamTask = nil
        activeConversationID = nil
        streamToken = UUID()

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let index = conversations.firstIndex(where: { $0.id == conversationID }) else {
            activeModelName = nil
            return
        }

        let modelName = activeModelName
            ?? AIModel.model(for: conversations[index].modelID).shortName
        conversations[index].messages.append(
            ChatMessage(role: .assistant, text: trimmed, modelName: modelName)
        )
        conversations[index].updatedAt = Date()
        conversations.sort { $0.updatedAt > $1.updatedAt }
        activeModelName = nil
        persist()
    }

    private func abortStreaming(keepPartial: Bool) {
        guard isStreaming || streamTask != nil else {
            settleStreamingState()
            return
        }

        let partial = streamingText
        let targetID = activeConversationID
        let modelName = activeModelName

        streamToken = UUID()
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
        streamingText = ""
        activeConversationID = nil
        activeModelName = nil

        guard keepPartial,
              let targetID,
              !partial.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let index = conversations.firstIndex(where: { $0.id == targetID }) else {
            return
        }

        conversations[index].messages.append(
            ChatMessage(
                role: .assistant,
                text: partial,
                modelName: modelName ?? AIModel.model(for: conversations[index].modelID).shortName
            )
        )
        conversations[index].updatedAt = Date()
        conversations.sort { $0.updatedAt > $1.updatedAt }
        if currentID == targetID {
            persist()
        }
    }

    private func settleStreamingState() {
        if !isStreaming && streamTask == nil { return }
        streamToken = UUID()
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
        streamingText = ""
        activeConversationID = nil
        activeModelName = nil
    }

    // MARK: - Persistence

    private func upsert(_ conversation: Conversation) {
        if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
            conversations[index] = conversation
        } else {
            conversations.insert(conversation, at: 0)
        }
        conversations.sort { $0.updatedAt > $1.updatedAt }

        if conversations.count > 100 {
            conversations = Array(conversations.prefix(100))
            if let currentID, !conversations.contains(where: { $0.id == currentID }) {
                self.currentID = nil
            }
        }
    }

    private func persist() {
        let archive = ConversationArchive(conversations: conversations, currentID: currentID)
        storage.save(archive)
    }

    // MARK: - Helpers

    private static func makeTitle(from text: String, hasImage: Bool) -> String {
        if text.isEmpty {
            return hasImage ? "Photo analysis" : "New chat"
        }
        let firstLine = text
            .components(separatedBy: .newlines)
            .first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
            ?? text
        let cleaned = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.count <= 46 { return cleaned }
        return String(cleaned.prefix(46)).trimmingCharacters(in: .whitespaces) + "…"
    }

    private static func wireMessages(
        from conversation: Conversation,
        systemPrompt: String,
        supportsVision: Bool
    ) -> [WireMessage] {
        var wire: [WireMessage] = []

        let prompt = systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if !prompt.isEmpty {
            wire.append(WireMessage(role: "system", content: .text(prompt)))
        }

        for message in conversation.messages.suffix(24) {
            if let data = message.imageData {
                if supportsVision,
                   let image = UIImage(data: data),
                   let jpeg = image.ozoJPEGData(maxDimension: 1200, quality: 0.7) {
                    let dataURL = "data:image/jpeg;base64,\(jpeg.base64EncodedString())"
                    let text = message.text.isEmpty ? "Please analyze this image." : message.text
                    wire.append(
                        WireMessage(
                            role: message.role.rawValue,
                            content: .parts([
                                .text(text),
                                .image(dataURL: dataURL)
                            ])
                        )
                    )
                } else {
                    // Never send image payloads to a text-only model. Keep the
                    // conversation coherent with a short placeholder instead.
                    let fallback = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
                    wire.append(
                        WireMessage(
                            role: message.role.rawValue,
                            content: .text(
                                fallback.isEmpty
                                    ? "[A photo was attached earlier. This model cannot view images.]"
                                    : fallback
                            )
                        )
                    )
                }
            } else {
                wire.append(
                    WireMessage(
                        role: message.role.rawValue,
                        content: .text(message.text)
                    )
                )
            }
        }

        return wire
    }

    private static func friendlyMessage(for error: Error) -> String {
        if let localized = error as? LocalizedError,
           let description = localized.errorDescription,
           !description.isEmpty {
            return description
        }
        return error.localizedDescription
    }
}
