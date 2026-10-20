import Foundation
import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @AppStorage("ozo.onboardingDismissed") private var onboardingDismissed = false

    @State private var keyDraft = ""
    @State private var showKey = false
    @State private var saveError: String?
    @State private var appeared = false

    var body: some View {
        ZStack {
            background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 25) {
                    topBar
                    hero
                    features
                    connectCard
                    exploreButton
                    privacyNote
                }
                .padding(.horizontal, 22)
                .padding(.top, 8)
                .padding(.bottom, 28)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.85)) {
                appeared = true
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
            Spacer()

            Button {
                onboardingDismissed = true
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
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
        VStack(spacing: 15) {
            ZStack {
                Circle()
                    .fill(Color(hex: 0x14B8A6).opacity(0.25))
                    .frame(width: 150, height: 150)
                    .blur(radius: 36)

                OZOLogo(size: 90)
            }
            .frame(height: 120)
            .scaleEffect(appeared ? 1 : 0.82)
            .opacity(appeared ? 1 : 0)

            VStack(spacing: 8) {
                Text("OZO AI")
                    .font(.system(size: 43, weight: .bold, design: .rounded))
                    .tracking(-1.4)
                    .foregroundStyle(.white)

                Text("Ten powerful models. One beautiful chat.")
                    .font(.system(size: 15.5))
                    .foregroundStyle(.white.opacity(0.58))
                    .multilineTextAlignment(.center)

                HStack(spacing: 6) {
                    tag("10 free models", color: Color(hex: 0x2DD4BF))
                    tag("Vision", color: Color(hex: 0x8B5CF6))
                    tag("Voice", color: Color(hex: 0x60A5FA))
                }
                .padding(.top, 3)
            }
            .offset(y: appeared ? 0 : 10)
            .opacity(appeared ? 1 : 0)
        }
        .padding(.top, 2)
    }

    private func tag(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(color.opacity(0.11), in: Capsule())
            .overlay(Capsule().strokeBorder(color.opacity(0.16), lineWidth: 0.7))
    }

    // MARK: - Features

    private var features: some View {
        VStack(spacing: 10) {
            featureRow(
                icon: "sparkles",
                tint: Color(hex: 0xF59E0B),
                title: "Every model in one place",
                subtitle: "DeepSeek, GLM, MiniMax, Nemotron and more — switch brains with one tap."
            )
            featureRow(
                icon: "eye.fill",
                tint: Color(hex: 0x8B5CF6),
                title: "See and speak",
                subtitle: "Analyze photos with a vision model and dictate messages with your voice."
            )
            featureRow(
                icon: "lock.shield.fill",
                tint: Color(hex: 0x2DD4BF),
                title: "Private by design",
                subtitle: "Your API key lives in Keychain. Chat history stays on this iPhone."
            )
        }
    }

    private func featureRow(icon: String, tint: Color, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.52))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(13)
        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.07), lineWidth: 0.7)
        )
    }

    // MARK: - Connect

    private var connectCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 9) {
                Image(systemName: "key.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x2DD4BF))

                Text("Connect OpenCode Zen")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Spacer()

                Text("FREE")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(0.6)
                    .foregroundStyle(Color(hex: 0x2DD4BF))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color(hex: 0x14B8A6).opacity(0.13), in: Capsule())
            }

            Text("Paste your OpenCode API key to unlock all ten models. The key is stored securely on this iPhone.")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Group {
                    if showKey {
                        TextField("sk-…", text: $keyDraft)
                    } else {
                        SecureField("sk-…", text: $keyDraft)
                    }
                }
                .font(.system(size: 13.5, design: .monospaced))
                .foregroundStyle(.white)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .tint(Color(hex: 0x2DD4BF))

                Button {
                    showKey.toggle()
                } label: {
                    Image(systemName: showKey ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.45))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 12)
            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(.white.opacity(0.09), lineWidth: 0.8)
            )

            if let saveError {
                Text(saveError)
                    .font(.system(size: 11))
                    .foregroundStyle(Color(hex: 0xFCA5A5))
            }

            Button {
                connect()
            } label: {
                HStack(spacing: 7) {
                    Text("Start chatting")
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .bold))
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    OZOTheme.brandGradient,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                .opacity(keyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.42 : 1)
            }
            .buttonStyle(OZOPressStyle())
            .disabled(keyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Link(destination: URL(string: "https://opencode.ai/console")!) {
                HStack(spacing: 3) {
                    Text("Get your free API key")
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 8, weight: .bold))
                }
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(Color(hex: 0x2DD4BF))
                .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 21, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 21, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 0.8)
        )
    }

    // MARK: - Explore + privacy

    private var exploreButton: some View {
        Button {
            onboardingDismissed = true
            Haptics.tap(settings.hapticsEnabled)
            dismiss()
        } label: {
            Text("Explore first")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.48))
                .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private var privacyNote: some View {
        HStack(spacing: 5) {
            Image(systemName: "lock.fill")
            Text("Your key is never sent anywhere except OpenCode")
        }
        .font(.system(size: 9.5, weight: .medium))
        .foregroundStyle(.white.opacity(0.28))
    }

    // MARK: - Actions

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
}
