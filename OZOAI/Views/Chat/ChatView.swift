import SwiftUI
import UIKit

struct ChatView: View {
    @EnvironmentObject private var store: ChatStore
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject var speech: SpeechRecognizer

    let onOpenSidebar: () -> Void
    let onOpenSettings: () -> Void
    let onOpenModelPicker: () -> Void

    @State private var lastStreamScrollCount = 0
    @State private var showRenameAlert = false
    @State private var renameText = ""
    @State private var showClearConfirmation = false

    private var selectedModel: AIModel {
        AIModel.model(for: selectedModelID)
    }

    private var selectedModelID: String {
        store.selectedModelID ?? settings.defaultModelID
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if !selectedModel.isAvailable(on: settings.provider) {
                modelAvailabilityBanner
            }

            messageArea
            composerArea
        }
        .background(chatBackground)
        .onChange(of: store.currentID) { _, _ in
            speech.stop()
        }
        .onDisappear {
            speech.stop()
        }
        .alert("Rename chat", isPresented: $showRenameAlert) {
            TextField("Chat name", text: $renameText)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                if let conversation = store.currentConversation {
                    store.rename(conversation, to: renameText)
                    Haptics.success(settings.hapticsEnabled)
                }
            }
        } message: {
            Text("Give this conversation a short, memorable name.")
        }
        .confirmationDialog(
            "Clear this conversation?",
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear messages", role: .destructive) {
                store.clearCurrentMessages()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Every message will be removed. The chat will stay in your history.")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            HeaderIconButton(systemName: "sidebar.left") {
                Haptics.tap(settings.hapticsEnabled)
                onOpenSidebar()
            }

            Spacer(minLength: 2)

            Button {
                Haptics.tap(settings.hapticsEnabled)
                onOpenModelPicker()
            } label: {
                VStack(spacing: 1.5) {
                    Text(store.isStreaming ? "RESPONDING…" : "OZO AI")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(1.1)
                        .foregroundStyle(store.isStreaming ? OZOTheme.accent : Color.secondary)

                    HStack(spacing: 6) {
                        Circle()
                            .fill(selectedModel.tint)
                            .frame(width: 6, height: 6)

                        Text(selectedModel.shortName)
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)

                        Image(systemName: "chevron.down")
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: 205)
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 5.5)
                .background(Capsule().fill(Color.primary.opacity(0.05)))
                .overlay(Capsule().strokeBorder(OZOTheme.hairline, lineWidth: 0.7))
            }
            .buttonStyle(OZOPressStyle())
            .accessibilityLabel("Model: \(selectedModel.name). Tap to change.")

            Spacer(minLength: 2)

            Menu {
                if !store.messages.isEmpty {
                    ShareLink(item: store.exportText) {
                        Label("Share chat", systemImage: "square.and.arrow.up")
                    }
                }

                Button {
                    renameText = store.currentConversation?.title ?? "New chat"
                    showRenameAlert = true
                } label: {
                    Label("Rename chat", systemImage: "pencil")
                }
                .disabled(store.currentConversation == nil)

                Button(role: .destructive) {
                    showClearConfirmation = true
                } label: {
                    Label("Clear messages", systemImage: "trash")
                }
                .disabled(store.messages.isEmpty)

                Divider()

                Button {
                    onOpenSettings()
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.primary.opacity(0.06)))
                    .contentShape(Circle())
            }
            .accessibilityLabel("Chat options")

            HeaderIconButton(systemName: "square.and.pencil") {
                startNewChat()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .top)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(OZOTheme.hairline)
                .frame(height: 0.5)
        }
    }

    // MARK: - Messages

    private var modelAvailabilityBanner: some View {
        HStack(spacing: 9) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.orange)

            Text("\(selectedModel.shortName) isn't available on \(settings.provider.displayName).")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 4)

            Button("Change") {
                onOpenModelPicker()
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(OZOTheme.accent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.08))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(OZOTheme.hairline)
                .frame(height: 0.5)
        }
    }

    private var messageArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if store.messages.isEmpty && !store.isStreaming {
                    WelcomeView(
                        model: selectedModel,
                        hasAPIKey: settings.hasAPIKey,
                        onSuggestion: sendSuggestion,
                        onConnect: onOpenSettings,
                        onChooseModel: onOpenModelPicker
                    )
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                } else {
                    LazyVStack(spacing: 24) {
                        ForEach(store.messages) { message in
                            MessageRow(
                                message: message,
                                isLastAssistant: message.role == .assistant
                                    && message.id == store.messages.last?.id,
                                onRegenerate: regenerate
                            )
                            .equatable()
                            .id(message.id)
                        }

                        if store.isStreaming {
                            StreamingRow(text: store.streamingText, model: selectedModel)
                                .id("ozo-streaming")
                                .transition(.opacity)
                        }

                        if let error = store.errorText {
                            InlineErrorCard(
                                message: error,
                                onRetry: regenerate,
                                onOpenSettings: onOpenSettings,
                                onDismiss: dismissError
                            )
                        }

                        Color.clear
                            .frame(height: 1)
                            .id("ozo-bottom")
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 18)
                    .padding(.bottom, 14)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: store.messages.count) { _, _ in
                lastStreamScrollCount = 0
                DispatchQueue.main.async {
                    scrollToBottom(proxy, animated: true)
                }
            }
            .onChange(of: store.currentID) { _, _ in
                lastStreamScrollCount = 0
                DispatchQueue.main.async {
                    scrollToBottom(proxy, animated: false)
                }
            }
            .onChange(of: store.isStreaming) { _, streaming in
                guard streaming else { return }
                lastStreamScrollCount = 0
                DispatchQueue.main.async {
                    scrollToBottom(proxy, animated: true)
                }
            }
            .onChange(of: store.streamingText) { _, newValue in
                guard store.isStreaming else { return }

                // Scrolling on every token forces extra layout passes. Batching
                // it by a few words keeps the stream pinned to the bottom while
                // cutting the work roughly in half.
                let delta = newValue.count - lastStreamScrollCount
                guard delta >= 24 || delta < 0 else { return }
                lastStreamScrollCount = newValue.count
                scrollToBottom(proxy, animated: false)
            }
            .onChange(of: store.errorText) { _, newValue in
                if newValue != nil {
                    scrollToBottom(proxy, animated: true)
                }
            }
            .onAppear {
                guard !store.messages.isEmpty else { return }
                DispatchQueue.main.async {
                    proxy.scrollTo("ozo-bottom", anchor: .bottom)
                }
            }
        }
    }

    // MARK: - Composer

    private var composerArea: some View {
        VStack(spacing: 0) {
            ComposerView(
                resetToken: store.composerResetToken,
                isStreaming: store.isStreaming,
                model: selectedModel,
                speech: speech,
                onSend: sendDraft,
                onStop: {
                    Haptics.soft(settings.hapticsEnabled)
                    store.stop()
                },
                onSwitchToVision: switchToVisionModel
            )
            .padding(.horizontal, 12)
            .padding(.top, 7)
            .padding(.bottom, 7)
        }
        .background(
            LinearGradient(
                colors: [OZOTheme.background.opacity(0), OZOTheme.background],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
    }

    private var chatBackground: some View {
        ZStack {
            OZOTheme.background
            OZOTheme.ambient
        }
        .ignoresSafeArea()
    }

    // MARK: - Actions

    private func sendDraft(_ text: String, _ image: UIImage?) {
        guard settings.hasAPIKey else {
            onOpenSettings()
            return
        }
        guard selectedModel.isAvailable(on: settings.provider) else {
            onOpenModelPicker()
            return
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let imageData = image?.ozoJPEGData(maxDimension: 1200, quality: 0.68)
        guard !trimmed.isEmpty || imageData != nil else { return }

        speech.stop()

        var modelID = selectedModelID
        if imageData != nil, !AIModel.model(for: modelID).supportsVision {
            // Never send a photo to a text-only model. Switch automatically so
            // the attachment is actually useful.
            modelID = AIModel.visionModelID
            switchToVisionModel()
        }

        let apiKey = settings.apiKey
        let systemPrompt = settings.systemPrompt
        let temperature = settings.temperature

        store.send(
            text: trimmed,
            imageData: imageData,
            modelID: modelID,
            provider: settings.provider,
            apiKey: apiKey,
            systemPrompt: systemPrompt,
            temperature: temperature
        )
    }

    private func sendSuggestion(_ prompt: String) {
        guard settings.hasAPIKey else {
            onOpenSettings()
            return
        }
        guard selectedModel.isAvailable(on: settings.provider) else {
            onOpenModelPicker()
            return
        }
        speech.stop()
        store.send(
            text: prompt,
            imageData: nil,
            modelID: selectedModelID,
            provider: settings.provider,
            apiKey: settings.apiKey,
            systemPrompt: settings.systemPrompt,
            temperature: settings.temperature
        )
    }

    private func regenerate() {
        guard settings.hasAPIKey else {
            onOpenSettings()
            return
        }
        store.regenerate(
            provider: settings.provider,
            apiKey: settings.apiKey,
            systemPrompt: settings.systemPrompt,
            temperature: settings.temperature
        )
    }

    private func startNewChat() {
        Haptics.tap(settings.hapticsEnabled)
        speech.stop()
        withAnimation(.easeOut(duration: 0.2)) {
            store.newChat()
        }
    }

    private func switchToVisionModel() {
        let visionID = AIModel.visionModelID
        if let conversationID = store.currentID {
            store.setModel(visionID, for: conversationID)
        }
        settings.setDefaultModel(visionID)
        Haptics.success(settings.hapticsEnabled)
    }

    private func dismissError() {
        withAnimation(.easeOut(duration: 0.2)) {
            store.errorText = nil
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy, animated: Bool) {
        if animated {
            withAnimation(.easeOut(duration: 0.18)) {
                proxy.scrollTo("ozo-bottom", anchor: .bottom)
            }
        } else {
            proxy.scrollTo("ozo-bottom", anchor: .bottom)
        }
    }
}
