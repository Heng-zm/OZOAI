import Foundation
import SwiftUI
import UIKit

struct OnboardingView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("ozo.onboardingDismissed") private var onboardingDismissed = false

    @State private var keyDraft = ""
    @State private var showKey = false
    @State private var saveError: String?
    @State private var appeared = false
    @FocusState private var keyFocused: Bool

    var body: some View {
        ZStack {
            background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    topBar
                    hero
                    connectCard
                    exploreButton
                    featureStrip
                    privacyNote
                }
                .padding(.horizontal, 22)
                .padding(.top, 8)
                .padding(.bottom, 28)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollIndicators(.hidden)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            guard !appeared else { return }
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.spring(response: 0.7, dampingFraction: 0.85)) {
                    appeared = true
                }
            }
        }
        .onChange(of: keyDraft) { _, _ in
            if saveError != nil {
                saveError = nil
            }
        }
    }

    // MARK: - Background

    private var background: some View {
        ZStack {
            Color(hex: 0x070B12)

            Circle()
                .fill(Color(hex: 0x0D9488).opacity(0.30))
                .frame(width: 360, height: 360)
                .blur(radius: 110)
                .offset(x: -130, y: -260)

            Circle()
                .fill(Color(hex: 0x6D28D9).opacity(0.28))
                .frame(width: 340, height: 340)
                .blur(radius: 120)
                .offset(x: 150, y: 280)

            LinearGradient(
                colors: [Color.clear, Color(hex: 0x070B12).opacity(0.55)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    // MARK: - Top

    private var topBar: some View {
        HStack {
            Text("WELCOME TO OZO")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.34))

            Spacer()

            Button {
                finishOnboarding()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(.white.opacity(0.72))
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(.white.opacity(0.08)))
                    .overlay(Circle().strokeBorder(.white.opacity(0.08), lineWidth: 0.7))
            }
            .buttonStyle(OZOPressStyle())
            .accessibilityLabel("Skip onboarding")
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: 13) {
            ZStack {
                Circle()
                    .fill(Color(hex: 0x14B8A6).opacity(0.23))
                    .frame(width: 150, height: 150)
                    .blur(radius: 36)

                Circle()
                    .strokeBorder(Color(hex: 0x2DD4BF).opacity(0.13), lineWidth: 1)
                    .frame(width: 106, height: 106)

                OZOLogo(size: 74)
            }
            .frame(height: 102)
            .scaleEffect(appeared ? 1 : 0.84)
            .opacity(appeared ? 1 : 0)

            VStack(spacing: 6) {
                Text("OZO AI")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .tracking(-1.3)
                    .foregroundStyle(.white)

                Text("Claude, Zen, and more. One beautiful chat.")
                    .font(.system(size: 14.5))
                    .foregroundStyle(.white.opacity(0.58))
                    .multilineTextAlignment(.center)

                HStack(spacing: 6) {
                    tag("\(AIModel.all.count) models", color: Color(hex: 0x2DD4BF))
                    tag("Vision", color: Color(hex: 0x8B5CF6))
                    tag("Voice", color: Color(hex: 0x60A5FA))
                }
                .padding(.top, 2)
            }
            .offset(y: appeared ? 0 : 10)
            .opacity(appeared ? 1 : 0)
        }
    }

    private func tag(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 9.5, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(color.opacity(0.11), in: Capsule())
            .overlay(Capsule().strokeBorder(color.opacity(0.16), lineWidth: 0.7))
    }

    // MARK: - Connect

    private var connectCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 9) {
                Image(systemName: "key.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x2DD4BF))

                Text("Connect \(settings.provider.displayName)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Spacer(minLength: 4)

                Text(providerTag(settings.provider))
                    .font(.system(size: 8.5, weight: .bold, design: .rounded))
                    .tracking(0.6)
                    .foregroundStyle(providerTint(settings.provider))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(providerTint(settings.provider).opacity(0.13), in: Capsule())
            }

            HStack(spacing: 3) {
                ForEach(AIProvider.allCases) { provider in
                    providerButton(provider)
                }
            }
            .padding(3)
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.07), lineWidth: 0.7)
            )

            Text(providerDescription(settings.provider))
                .font(.system(size: 11.5))
                .foregroundStyle(.white.opacity(0.53))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 7) {
                Group {
                    if showKey {
                        TextField(settings.provider.keyPlaceholder, text: $keyDraft)
                            .focused($keyFocused)
                    } else {
                        SecureField(settings.provider.keyPlaceholder, text: $keyDraft)
                            .focused($keyFocused)
                    }
                }
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.white)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.password)
                .tint(Color(hex: 0x2DD4BF))
                .submitLabel(.done)

                Button("Paste") {
                    pasteKey()
                }
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color(hex: 0x2DD4BF))
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(Color(hex: 0x14B8A6).opacity(0.12), in: Capsule())
                .buttonStyle(.plain)
                .accessibilityLabel(keyDraft.isEmpty ? "Paste key from clipboard" : "Replace key from clipboard")

                Button {
                    showKey.toggle()
                } label: {
                    Image(systemName: showKey ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.45))
                        .frame(width: 22, height: 24)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(showKey ? "Hide API key" : "Show API key")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(
                Color.white.opacity(keyFocused ? 0.075 : 0.055),
                in: RoundedRectangle(cornerRadius: 13, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(
                        keyFocused ? Color(hex: 0x2DD4BF).opacity(0.55) : Color.white.opacity(0.09),
                        lineWidth: keyFocused ? 1.1 : 0.8
                    )
            )
            .animation(.easeOut(duration: 0.18), value: keyFocused)

            if let saveError {
                Text(saveError)
                    .font(.system(size: 11))
                    .foregroundStyle(Color(hex: 0xFCA5A5))
            }

            Button {
                connect()
            } label: {
                HStack(spacing: 6) {
                    Text("Start chatting")
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11.5, weight: .bold))
                }
                .font(.system(size: 14.5, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    OZOTheme.brandGradient,
                    in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                )
                .shadow(
                    color: canConnect ? Color(hex: 0x10B5A5).opacity(0.26) : .clear,
                    radius: 12,
                    y: 5
                )
                .opacity(canConnect ? 1 : 0.42)
            }
            .buttonStyle(OZOPressStyle())
            .disabled(!canConnect)

            Link(destination: settings.provider.consoleURL) {
                HStack(spacing: 3) {
                    Text(settings.provider.consoleLinkTitle)
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 7.5, weight: .bold))
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(providerTint(settings.provider))
                .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .background(
            Color.white.opacity(0.045),
            in: RoundedRectangle(cornerRadius: 21, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 21, style: .continuous)
                .strokeBorder(Color.white.opacity(0.09), lineWidth: 0.8)
        )
        .shadow(color: .black.opacity(0.20), radius: 24, y: 12)
        .offset(y: appeared ? 0 : 12)
        .opacity(appeared ? 1 : 0)
    }

    private var canConnect: Bool {
        !keyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func providerTint(_ provider: AIProvider) -> Color {
        switch provider {
        case .openCode: return Color(hex: 0x2DD4BF)
        case .openRouter: return Color(hex: 0x8B5CF6)
        case .anthropic: return Color(hex: 0xF97316)
        }
    }

    private func providerTag(_ provider: AIProvider) -> String {
        switch provider {
        case .openCode: return "FREE"
        case .openRouter: return "OPTIONAL"
        case .anthropic: return "CREDITS"
        }
    }

    private func providerDescription(_ provider: AIProvider) -> String {
        switch provider {
        case .openCode:
            return "Paste your OpenCode key to unlock all ten free models. It's stored securely on this iPhone."
        case .openRouter:
            return "Paste your OpenRouter key to use supported models. Free models are marked in the picker."
        case .anthropic:
            return "Paste your Anthropic key to chat with Claude. Usage is billed through your Anthropic account."
        }
    }

    private func providerButton(_ provider: AIProvider) -> some View {
        let isSelected = settings.provider == provider

        return Button {
            guard provider != settings.provider else { return }
            settings.provider = provider
            settings.ensureDefaultModelAvailable(for: provider)
            keyDraft = settings.apiKey
            saveError = nil
            showKey = false
            Haptics.tap(settings.hapticsEnabled)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: provider.symbol)
                    .font(.system(size: 10.5, weight: .semibold))
                Text(provider.shortName)
                    .font(.system(size: 10.5, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.50))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                isSelected ? Color.white.opacity(0.12) : Color.clear,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.white.opacity(0.10) : Color.clear,
                        lineWidth: 0.7
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }

    // MARK: - Features + escape

    private var exploreButton: some View {
        Button {
            finishOnboarding()
        } label: {
            Text("Explore first")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.44))
                .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
    }

    private var featureStrip: some View {
        HStack(spacing: 8) {
            featureChip(
                icon: "square.stack.3d.up.fill",
                tint: Color(hex: 0x2DD4BF),
                title: "\(AIModel.all.count) models",
                detail: "Claude + Zen"
            )
            featureChip(
                icon: "eye.fill",
                tint: Color(hex: 0x8B5CF6),
                title: "Vision",
                detail: "Photos + voice"
            )
            featureChip(
                icon: "lock.shield.fill",
                tint: Color(hex: 0x60A5FA),
                title: "Private",
                detail: "On-device"
            )
        }
    }

    private func featureChip(icon: String, tint: Color, title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Text(detail)
                .font(.system(size: 8.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.42))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(Color.white.opacity(0.065), lineWidth: 0.7)
        )
    }

    private var privacyNote: some View {
        HStack(spacing: 5) {
            Image(systemName: "lock.fill")
            Text("Your key stays in Keychain and is sent only to \(settings.provider.displayName)")
        }
        .font(.system(size: 9, weight: .medium))
        .foregroundStyle(.white.opacity(0.28))
        .multilineTextAlignment(.center)
    }

    // MARK: - Actions

    private func pasteKey() {
        guard let value = UIPasteboard.general.string else { return }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        keyDraft = trimmed
        saveError = nil
        Haptics.soft(settings.hapticsEnabled)
    }

    private func connect() {
        let trimmed = keyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        settings.apiKey = trimmed
        let success = settings.persistAPIKey()

        guard success else {
            saveError = "The key couldn't be saved to Keychain. Please try again."
            Haptics.error(settings.hapticsEnabled)
            return
        }

        saveError = nil
        onboardingDismissed = true
        Haptics.success(settings.hapticsEnabled)
        dismiss()
    }

    private func finishOnboarding() {
        onboardingDismissed = true
        Haptics.tap(settings.hapticsEnabled)
        dismiss()
    }
}
