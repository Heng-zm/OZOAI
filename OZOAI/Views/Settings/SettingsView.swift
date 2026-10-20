import Foundation
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: ChatStore
    @Environment(\.dismiss) private var dismiss

    @State private var apiKeyDraft = ""
    @State private var showKey = false
    @State private var isTesting = false
    @State private var testResult: TestResult?
    @State private var showClearHistoryConfirmation = false
    @State private var showRemoveKeyConfirmation = false

    private enum TestResult {
        case success(String)
        case failure(String)
    }

    var body: some View {
        NavigationStack {
            Form {
                identitySection
                connectionSection
                modelSection
                personalizationSection
                appearanceSection
                dataSection
                aboutSection
            }
            .scrollContentBackground(.hidden)
            .background(OZOTheme.groupedBackground)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        if apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines) != settings.apiKey {
                            guard saveKey() else { return }
                        }
                        settings.savePreferences()
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .semibold))
                }
            }
            .onAppear {
                apiKeyDraft = settings.apiKey
            }
            .onDisappear {
                settings.savePreferences()
            }
            .onChange(of: apiKeyDraft) { _, _ in
                testResult = nil
            }
            .confirmationDialog(
                "Clear all conversations?",
                isPresented: $showClearHistoryConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete all chats", role: .destructive) {
                    store.deleteAll()
                    Haptics.success(settings.hapticsEnabled)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Every conversation on this iPhone will be permanently deleted.")
            }
            .confirmationDialog(
                "Remove your API key?",
                isPresented: $showRemoveKeyConfirmation,
                titleVisibility: .visible
            ) {
                Button("Remove key", role: .destructive) {
                    settings.removeAPIKey()
                    apiKeyDraft = ""
                    testResult = nil
                    Haptics.success(settings.hapticsEnabled)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You'll need to add a key again to chat with OZO AI.")
            }
        }
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
    }

    // MARK: - Identity

    private var identitySection: some View {
        Section {
            HStack(spacing: 14) {
                OZOLogo(size: 54)

                VStack(alignment: .leading, spacing: 3) {
                    Text("OZO AI")
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                    Text("Ten free models, one beautiful chat.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("1.0.0")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.05), in: Capsule())
            }
            .padding(.vertical, 4)
        }
        .listRowBackground(Color.clear)
    }

    // MARK: - Connection

    private var connectionSection: some View {
        Section {
            HStack(spacing: 10) {
                Image(systemName: "key.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(OZOTheme.accent)
                    .frame(width: 24)

                Group {
                    if showKey {
                        TextField("sk-…", text: $apiKeyDraft)
                    } else {
                        SecureField("sk-…", text: $apiKeyDraft)
                    }
                }
                .font(.system(size: 13.5, design: .monospaced))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.password)

                Button {
                    showKey.toggle()
                } label: {
                    Image(systemName: showKey ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(showKey ? "Hide API key" : "Show API key")
            }

            HStack(spacing: 10) {
                Button {
                    saveKey()
                } label: {
                    Label("Save key", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(OZOTheme.accent)
                .disabled(apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                          || apiKeyDraft == settings.apiKey)

                Button {
                    testConnection()
                } label: {
                    HStack(spacing: 5) {
                        if isTesting {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "bolt.horizontal.fill")
                        }
                        Text(isTesting ? "Testing…" : "Test")
                    }
                }
                .buttonStyle(.bordered)
                .tint(OZOTheme.accent)
                .disabled(apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isTesting)

                Spacer()

                connectionPill
            }

            if let testResult {
                HStack(alignment: .top, spacing: 7) {
                    Image(systemName: resultIcon(testResult))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(resultColor(testResult))
                        .padding(.top, 1)

                    Text(resultText(testResult))
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 2)
                .transition(.opacity)
            }
        } header: {
            Text("OpenCode Zen connection")
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                Text("Your key is stored only in this iPhone's Keychain and is sent directly to OpenCode. OZO AI never sees it.")
                Link(destination: URL(string: "https://opencode.ai/console")!) {
                    HStack(spacing: 3) {
                        Text("Get a free API key")
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 8, weight: .bold))
                    }
                }
                .fontWeight(.semibold)
                .foregroundStyle(OZOTheme.accent)
            }
        }
    }

    @ViewBuilder
    private var connectionPill: some View {
        if settings.hasAPIKey {
            HStack(spacing: 4) {
                Circle().fill(Color.green).frame(width: 5, height: 5)
                Text("Connected")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.green)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.green.opacity(0.10), in: Capsule())
        } else {
            HStack(spacing: 4) {
                Circle().fill(Color.orange).frame(width: 5, height: 5)
                Text("Not connected")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.orange)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.orange.opacity(0.10), in: Capsule())
        }
    }

    // MARK: - Model

    private var modelSection: some View {
        Section {
            Picker(selection: Binding(
                get: { settings.defaultModelID },
                set: { settings.setDefaultModel($0) }
            )) {
                ForEach(AIModel.all) { model in
                    Text(model.name).tag(model.id)
                }
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Default model")
                        Text(settings.defaultModel.shortName)
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                } icon: {
                    Image(systemName: "cpu")
                        .foregroundStyle(settings.defaultModel.tint)
                }
            }
            .pickerStyle(.navigationLink)
        } header: {
            Text("Model")
        } footer: {
            Text("New conversations start with this model. The model picker inside a chat marks the active model with a bullet.")
        }
    }

    // MARK: - Personalization

    private var personalizationSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Custom instructions", systemImage: "text.quote")
                        .font(.system(size: 14))
                    Spacer()
                    Button("Reset") {
                        settings.resetSystemPrompt()
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(OZOTheme.accent)
                }

                TextEditor(text: $settings.systemPrompt)
                    .font(.system(size: 13))
                    .lineSpacing(2)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 104)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(OZOTheme.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .strokeBorder(OZOTheme.hairline, lineWidth: 0.8)
                    )
            }
            .padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Label("Creativity", systemImage: "slider.horizontal.3")
                        .font(.system(size: 14))
                    Spacer()
                    Text(String(format: "%.2f", settings.temperature))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Slider(value: $settings.temperature, in: 0...1, step: 0.05)
                    .tint(OZOTheme.accent)

                Text("Lower is focused and predictable. Higher is more imaginative.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 3)
        } header: {
            Text("Personalization")
        } footer: {
            Text("Custom instructions are sent as the system prompt with every new request.")
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        Section {
            Picker("Appearance", selection: $settings.appearance) {
                ForEach(AppSettings.Appearance.allCases) { appearance in
                    Text(appearance.title).tag(appearance)
                }
            }
            .pickerStyle(.segmented)

            Toggle(isOn: $settings.hapticsEnabled) {
                Label("Haptic feedback", systemImage: "hand.tap.fill")
            }
            .tint(OZOTheme.accent)
        } header: {
            Text("Appearance")
        }
    }

    // MARK: - Data

    private var dataSection: some View {
        Section {
            HStack {
                Label("Conversations", systemImage: "bubble.left.and.bubble.right.fill")
                Spacer()
                Text("\(store.conversations.count)")
                    .foregroundStyle(.secondary)
            }

            Button(role: .destructive) {
                showClearHistoryConfirmation = true
            } label: {
                Label("Clear all conversations", systemImage: "trash")
            }
            .disabled(store.conversations.isEmpty)

            if settings.hasAPIKey {
                Button(role: .destructive) {
                    showRemoveKeyConfirmation = true
                } label: {
                    Label("Remove API key", systemImage: "key.slash")
                }
            }
        } header: {
            Text("Data")
        } footer: {
            Text("Chats are saved locally on this iPhone. Clearing them can't be undone.")
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section {
            HStack {
                Text("Version")
                Spacer()
                Text("1.0.0 (1)")
                    .foregroundStyle(.secondary)
            }

            Link(destination: URL(string: "https://opencode.ai/console")!) {
                HStack {
                    Label("OpenCode Console", systemImage: "globe")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }

            Link(destination: URL(string: "https://opencode.ai/docs/zen")!) {
                HStack {
                    Label("Model & pricing docs", systemImage: "doc.text")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
        } header: {
            Text("About")
        } footer: {
            Text("OZO AI is an independent SwiftUI client for OpenCode Zen. Models, availability and free periods are provided by OpenCode.")
        }
    }

    // MARK: - Actions

    @discardableResult
    private func saveKey() -> Bool {
        settings.apiKey = apiKeyDraft
        let success = settings.persistAPIKey()
        apiKeyDraft = settings.apiKey

        if success {
            testResult = .success("API key saved securely in your iPhone Keychain.")
            Haptics.success(settings.hapticsEnabled)
        } else {
            testResult = .failure("The key couldn't be saved to Keychain. Please try again.")
            Haptics.error(settings.hapticsEnabled)
        }
        return success
    }

    private func testConnection() {
        let key = apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }

        isTesting = true
        testResult = nil

        Task { @MainActor in
            do {
                try await OpenCodeClient.shared.validate(apiKey: key)
                testResult = .success("Connection works. Save the key to start chatting.")
                Haptics.success(settings.hapticsEnabled)
            } catch {
                let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                testResult = .failure(message)
                Haptics.error(settings.hapticsEnabled)
            }
            isTesting = false
        }
    }

    // MARK: - Test result helpers

    private func resultIcon(_ result: TestResult) -> String {
        switch result {
        case .success: return "checkmark.circle.fill"
        case .failure: return "exclamationmark.circle.fill"
        }
    }

    private func resultColor(_ result: TestResult) -> Color {
        switch result {
        case .success: return .green
        case .failure: return .orange
        }
    }

    private func resultText(_ result: TestResult) -> String {
        switch result {
        case .success(let text), .failure(let text): return text
        }
    }
}
