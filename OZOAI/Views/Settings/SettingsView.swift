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
            ScrollView {
                VStack(spacing: 22) {
                    identityCard

                    settingsSection(
                        "AI provider",
                        footer: "OpenCode Zen includes all ten models free. OpenRouter is optional; free and credit-based models are marked in the picker."
                    ) {
                        providerChoices
                    }

                    settingsSection("Connection") {
                        connectionCard
                    }

                    settingsSection(
                        "Model",
                        footer: "New chats start with this model. The in-chat picker marks the active model with a filled bullet."
                    ) {
                        modelCard
                    }

                    settingsSection(
                        "Personalization",
                        footer: "Custom instructions are sent as the system prompt with every new request."
                    ) {
                        personalizationCard
                    }

                    settingsSection("Appearance") {
                        appearanceCard
                    }

                    settingsSection(
                        "Data",
                        footer: "Chats are saved locally on this iPhone. Clearing them can't be undone."
                    ) {
                        dataCard
                    }

                    settingsSection("About") {
                        aboutCard
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 34)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(settingsBackground.ignoresSafeArea())
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
            .onChange(of: settings.provider) { _, _ in
                apiKeyDraft = settings.apiKey
                showKey = false
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
                Text("You'll need to add a \(settings.provider.displayName) key again to chat.")
            }
        }
        .presentationDragIndicator(.visible)
        .presentationDetents([.large])
        .presentationCornerRadius(28)
    }

    // MARK: - Identity

    private var identityCard: some View {
        HStack(spacing: 14) {
            OZOLogo(size: 54)

            VStack(alignment: .leading, spacing: 3) {
                Text("OZO AI")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .tracking(-0.4)

                Text("Ten models, one beautiful chat.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                HStack(spacing: 4) {
                    Image(systemName: "lock.shield.fill")
                    Text("Private by design")
                }
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(.tertiary)
                .padding(.top, 1)
            }

            Spacer(minLength: 6)

            Text(versionLabel)
                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.045), in: Capsule())
        }
        .padding(16)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(OZOTheme.surface)

                LinearGradient(
                    colors: [OZOTheme.accent.opacity(0.075), OZOTheme.violet.opacity(0.045)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(OZOTheme.hairline, lineWidth: 0.8)
        )
        .shadow(color: .black.opacity(0.04), radius: 14, y: 6)
    }

    // MARK: - Sections

    private func settingsSection<Content: View>(
        _ title: String,
        footer: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                .tracking(1.0)
                .foregroundStyle(.tertiary)
                .padding(.leading, 4)

            VStack(alignment: .leading, spacing: 14) {
                content()
            }
            .padding(15)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(OZOTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(OZOTheme.hairline, lineWidth: 0.8)
            )
            .shadow(color: .black.opacity(0.035), radius: 12, y: 5)

            if let footer {
                Text(footer)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .lineSpacing(1.5)
                    .padding(.horizontal, 4)
            }
        }
    }

    // MARK: - Provider

    private var providerChoices: some View {
        HStack(spacing: 9) {
            ForEach(AIProvider.allCases) { provider in
                providerChoice(provider)
            }
        }
    }

    private func providerChoice(_ provider: AIProvider) -> some View {
        let isSelected = settings.provider == provider
        let tint = provider == .openCode ? OZOTheme.accent : OZOTheme.violet
        let isConnected = settings.hasAPIKey(for: provider)

        return Button {
            selectProvider(provider)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(tint.opacity(0.13))
                            .frame(width: 32, height: 32)

                        Image(systemName: provider.symbol)
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundStyle(tint)
                    }

                    Spacer(minLength: 4)

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isSelected ? tint : Color.secondary.opacity(0.22))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(provider.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Text(provider == .openCode ? "All 10 models · Free" : "4 free · 4 with credits")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                HStack(spacing: 4) {
                    Circle()
                        .fill(isConnected ? OZOTheme.positive : OZOTheme.warning)
                        .frame(width: 4.5, height: 4.5)

                    Text(isConnected ? "Connected" : "Key needed")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(isConnected ? OZOTheme.positive : OZOTheme.warning)
                }
            }
            .padding(11)
            .frame(maxWidth: .infinity, minHeight: 124, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? tint.opacity(0.075) : Color.primary.opacity(0.025))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        isSelected ? tint.opacity(0.34) : OZOTheme.hairline,
                        lineWidth: isSelected ? 1.1 : 0.8
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(OZOPressStyle(scale: 0.985))
        .accessibilityLabel("\(provider.displayName), \(isConnected ? "connected" : "key needed")")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }

    private func selectProvider(_ provider: AIProvider) {
        guard provider != settings.provider else { return }

        if apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines) != settings.apiKey {
            guard saveKey() else { return }
        }

        settings.provider = provider
        apiKeyDraft = settings.apiKey
        showKey = false
        testResult = nil
        Haptics.tap(settings.hapticsEnabled)
    }

    // MARK: - Connection

    private var connectionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(OZOTheme.accent.opacity(0.12))
                        .frame(width: 34, height: 34)

                    Image(systemName: "key.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(OZOTheme.accent)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("\(settings.provider.displayName) API key")
                        .font(.system(size: 13.5, weight: .semibold))
                        .lineLimit(1)

                    Text(settings.provider.keyPlaceholder)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }

                Spacer(minLength: 4)

                connectionPill
            }

            HStack(spacing: 9) {
                Image(systemName: "key.horizontal.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.tertiary)

                Group {
                    if showKey {
                        TextField(settings.provider.keyPlaceholder, text: $apiKeyDraft)
                    } else {
                        SecureField(settings.provider.keyPlaceholder, text: $apiKeyDraft)
                    }
                }
                .font(.system(size: 13, design: .monospaced))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.password)
                .submitLabel(.done)

                Button {
                    showKey.toggle()
                } label: {
                    Image(systemName: showKey ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(showKey ? "Hide API key" : "Show API key")
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(0.035))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(OZOTheme.hairline, lineWidth: 0.8)
            )

            HStack(spacing: 9) {
                Button {
                    _ = saveKey()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text(apiKeyDraft == settings.apiKey ? "Saved" : "Save key")
                            .font(.system(size: 12.5, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
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
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "bolt.horizontal.fill")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        Text(isTesting ? "Testing…" : "Test")
                            .font(.system(size: 12.5, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                .tint(OZOTheme.accent)
                .disabled(apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isTesting)
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
                .padding(9)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    resultColor(testResult).opacity(0.07),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(resultColor(testResult).opacity(0.14), lineWidth: 0.7)
                )
                .transition(.opacity)
            }

            HStack(spacing: 5) {
                Image(systemName: "lock.fill")
                Text("Sent only to \(settings.provider.displayName)")

                Spacer(minLength: 4)

                Link(destination: settings.provider.consoleURL) {
                    HStack(spacing: 2) {
                        Text(settings.provider.consoleLinkTitle)
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 7.5, weight: .bold))
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(OZOTheme.accent)
                }
            }
            .font(.system(size: 9.5, weight: .medium))
            .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private var connectionPill: some View {
        if settings.hasAPIKey {
            HStack(spacing: 4) {
                Circle()
                    .fill(OZOTheme.positive)
                    .frame(width: 5, height: 5)
                Text("Connected")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(OZOTheme.positive)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3.5)
            .background(OZOTheme.positive.opacity(0.10), in: Capsule())
        } else {
            HStack(spacing: 4) {
                Circle()
                    .fill(OZOTheme.warning)
                    .frame(width: 5, height: 5)
                Text("Not connected")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(OZOTheme.warning)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3.5)
            .background(OZOTheme.warning.opacity(0.10), in: Capsule())
        }
    }

    // MARK: - Model

    private var modelCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Menu {
                ForEach(AIModel.all) { model in
                    Button {
                        settings.setDefaultModel(model.id)
                        Haptics.tap(settings.hapticsEnabled)
                    } label: {
                        if model.id == settings.defaultModelID {
                            Label(model.name, systemImage: "checkmark")
                        } else {
                            Text(model.name)
                        }
                    }
                }
            } label: {
                HStack(spacing: 11) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(settings.defaultModel.tint.opacity(0.12))
                            .frame(width: 38, height: 38)

                        Image(systemName: settings.defaultModel.symbol)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(settings.defaultModel.tint)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(settings.defaultModel.name)
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)

                        Text(settings.defaultModel.vendor.uppercased())
                            .font(.system(size: 8.5, weight: .bold, design: .rounded))
                            .tracking(0.7)
                            .foregroundStyle(.tertiary)
                    }

                    Spacer(minLength: 4)

                    if let badge = settings.defaultModel.badgeText(on: settings.provider) {
                        OZOBadge(
                            text: badge,
                            tint: badge == "Credits" ? .orange : OZOTheme.accent
                        )
                    }

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if let note = settings.defaultModel.availabilityNote(on: settings.provider),
               !settings.defaultModel.isAvailable(on: settings.provider) {
                Label(note, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.orange)
            }
        }
    }

    // MARK: - Personalization

    private var personalizationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Label("Custom instructions", systemImage: "text.quote")
                        .font(.system(size: 13.5, weight: .semibold))

                    Spacer()

                    Button("Reset") {
                        settings.resetSystemPrompt()
                        Haptics.tap(settings.hapticsEnabled)
                    }
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(OZOTheme.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(OZOTheme.accent.opacity(0.08), in: Capsule())
                }

                TextEditor(text: $settings.systemPrompt)
                    .font(.system(size: 13))
                    .lineSpacing(2)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 108)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.primary.opacity(0.03))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(OZOTheme.hairline, lineWidth: 0.8)
                    )
            }

            Divider()
                .opacity(0.55)

            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Label("Creativity", systemImage: "slider.horizontal.3")
                        .font(.system(size: 13.5, weight: .semibold))

                    Spacer()

                    Text(String(format: "%.2f", settings.temperature))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.primary.opacity(0.045), in: Capsule())
                }

                Slider(value: $settings.temperature, in: 0...1, step: 0.05)
                    .tint(OZOTheme.accent)

                HStack {
                    Text("Precise")
                    Spacer()
                    Text("Creative")
                }
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Appearance

    private var appearanceCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 2) {
                ForEach(AppSettings.Appearance.allCases) { appearance in
                    appearanceButton(appearance)
                }
            }
            .padding(3)
            .background(
                Color.primary.opacity(0.035),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )

            Divider()
                .opacity(0.55)

            Toggle(isOn: $settings.hapticsEnabled) {
                HStack(spacing: 9) {
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(OZOTheme.accent)
                        .frame(width: 22)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Haptic feedback")
                            .font(.system(size: 13.5, weight: .medium))
                        Text("A subtle tap for key actions")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .tint(OZOTheme.accent)
        }
    }

    private func appearanceButton(_ appearance: AppSettings.Appearance) -> some View {
        let isSelected = settings.appearance == appearance

        return Button {
            settings.appearance = appearance
            Haptics.tap(settings.hapticsEnabled)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: appearance.symbol)
                    .font(.system(size: 11, weight: .semibold))
                Text(appearance.title)
                    .font(.system(size: 11.5, weight: .semibold))
            }
            .foregroundStyle(isSelected ? OZOTheme.accent : Color.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                isSelected ? OZOTheme.accent.opacity(0.10) : Color.clear,
                in: RoundedRectangle(cornerRadius: 9, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }

    // MARK: - Data

    private var dataCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 9) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(OZOTheme.accent)
                    .frame(width: 22)

                Text("Conversations")
                    .font(.system(size: 13.5, weight: .medium))

                Spacer()

                Text("\(store.conversations.count)")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.primary.opacity(0.045), in: Capsule())
            }

            Divider()
                .opacity(0.55)

            Button(role: .destructive) {
                showClearHistoryConfirmation = true
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .medium))
                        .frame(width: 22)
                    Text("Clear all conversations")
                        .font(.system(size: 13.5, weight: .medium))
                    Spacer()
                }
                .foregroundStyle(.red)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(store.conversations.isEmpty)

            if settings.hasAPIKey {
                Button(role: .destructive) {
                    showRemoveKeyConfirmation = true
                } label: {
                    HStack(spacing: 9) {
                        Image(systemName: "key.slash")
                            .font(.system(size: 13, weight: .medium))
                            .frame(width: 22)
                        Text("Remove \(settings.provider.shortName) API key")
                            .font(.system(size: 13.5, weight: .medium))
                        Spacer()
                    }
                    .foregroundStyle(.red.opacity(0.86))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - About

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Version")
                    .font(.system(size: 13.5, weight: .medium))
                Spacer()
                Text(versionLabel)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Divider()
                .opacity(0.55)

            Link(destination: settings.provider.consoleURL) {
                aboutLinkRow(
                    title: "\(settings.provider.displayName) console",
                    symbol: "globe"
                )
            }

            Link(destination: settings.provider.docsURL) {
                aboutLinkRow(
                    title: "Model & pricing docs",
                    symbol: "doc.text"
                )
            }
        }
    }

    private func aboutLinkRow(title: String, symbol: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(OZOTheme.accent)
                .frame(width: 22)

            Text(title)
                .font(.system(size: 13.5, weight: .medium))
                .foregroundStyle(.primary)

            Spacer()

            Image(systemName: "arrow.up.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
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
                try await AIClient.shared.validate(provider: settings.provider, apiKey: key)
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

    // MARK: - Helpers

    private var versionLabel: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func resultIcon(_ result: TestResult) -> String {
        switch result {
        case .success: return "checkmark.circle.fill"
        case .failure: return "exclamationmark.circle.fill"
        }
    }

    private func resultColor(_ result: TestResult) -> Color {
        switch result {
        case .success: return OZOTheme.positive
        case .failure: return OZOTheme.warning
        }
    }

    private func resultText(_ result: TestResult) -> String {
        switch result {
        case .success(let text), .failure(let text): return text
        }
    }

    private var settingsBackground: some View {
        ZStack {
            OZOTheme.groupedBackground

            RadialGradient(
                colors: [OZOTheme.accent.opacity(0.05), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 430
            )

            RadialGradient(
                colors: [OZOTheme.violet.opacity(0.04), .clear],
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: 470
            )
        }
    }
}
