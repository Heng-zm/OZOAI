import Foundation
import SwiftUI

struct WelcomeView: View {
    let model: AIModel
    let hasAPIKey: Bool
    let onSuggestion: (String) -> Void
    let onConnect: () -> Void
    let onChooseModel: () -> Void

    @EnvironmentObject private var settings: AppSettings
    @State private var appeared = false

    private static let suggestions: [Suggestion] = [
        Suggestion(
            icon: "lightbulb.fill",
            title: "Explain something",
            prompt: "Explain how quantum computers work in a way that's easy to understand.",
            tint: Color(hex: 0xF59E0B)
        ),
        Suggestion(
            icon: "curlybraces",
            title: "Write code",
            prompt: "Write a polished SwiftUI screen for a todo app with add, complete and delete actions.",
            tint: Color(hex: 0x3B82F6)
        ),
        Suggestion(
            icon: "checklist",
            title: "Make a plan",
            prompt: "Help me plan a productive week. Ask me a few questions first, then give me a realistic schedule.",
            tint: Color(hex: 0x10B981)
        ),
        Suggestion(
            icon: "sparkles",
            title: "Brainstorm ideas",
            prompt: "Brainstorm 10 creative names and concepts for a personal AI assistant app.",
            tint: Color(hex: 0x8B5CF6)
        )
    ]

    var body: some View {
        VStack(spacing: 24) {
            hero
            connectBanner
            suggestionGrid
            footer
        }
        .frame(maxWidth: 620)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 6)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
                appeared = true
            }
        }
    }

    private var hero: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(OZOTheme.accent.opacity(0.13))
                    .frame(width: 140, height: 140)
                    .blur(radius: 32)

                OZOLogo(size: 76)
            }
            .frame(height: 108)
            .scaleEffect(appeared ? 1 : 0.85)
            .opacity(appeared ? 1 : 0)

            VStack(spacing: 7) {
                Text(greeting)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)

                Text("What can I help with?")
                    .font(.system(size: 31, weight: .bold, design: .rounded))
                    .tracking(-0.8)
                    .multilineTextAlignment(.center)

                Text("Ten powerful AI models. One beautiful chat.")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .offset(y: appeared ? 0 : 8)
            .opacity(appeared ? 1 : 0)

            Button(action: onChooseModel) {
                HStack(spacing: 7) {
                    Circle()
                        .fill(model.tint)
                        .frame(width: 7, height: 7)

                    Text(model.shortName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if let badge = model.badgeText(on: settings.provider) {
                        OZOBadge(text: badge, tint: badgeTint(for: badge))
                    }

                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.primary.opacity(0.055)))
                .overlay(Capsule().strokeBorder(OZOTheme.hairline, lineWidth: 0.8))
            }
            .buttonStyle(OZOPressStyle())
            .accessibilityLabel("Choose model. Currently \(model.name)")

            if model.supportsVision {
                Label("This model can see images — attach one with +", systemImage: "photo.badge.plus")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(model.tint)
            }
        }
        .padding(.top, 12)
    }

    @ViewBuilder
    private var connectBanner: some View {
        if !hasAPIKey {
            Button(action: onConnect) {
                HStack(spacing: 13) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(OZOTheme.brandGradient)
                            .frame(width: 42, height: 42)
                        Image(systemName: "key.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Connect \(settings.provider.displayName)")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.primary)
                        Text(settings.provider == .openCode
                             ? "Add a free API key to unlock all 10 models."
                             : "Add your OpenRouter key to use free and paid models.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer(minLength: 6)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(14)
                .background(OZOTheme.accent.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(OZOTheme.accent.opacity(0.18), lineWidth: 0.8)
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(OZOPressStyle())
        }
    }

    private var suggestionGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ],
            spacing: 10
        ) {
            ForEach(Self.suggestions) { suggestion in
                Button {
                    Haptics.tap(settings.hapticsEnabled)
                    onSuggestion(suggestion.prompt)
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        Image(systemName: suggestion.icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(suggestion.tint)
                            .frame(width: 30, height: 30)
                            .background(suggestion.tint.opacity(0.11), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

                        Spacer(minLength: 0)

                        Text(suggestion.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(13)
                    .frame(height: 102)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(OZOTheme.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(OZOTheme.hairline, lineWidth: 0.8)
                    )
                }
                .buttonStyle(OZOPressStyle())
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: "lock.shield.fill")
                Text("Your API key stays in your iPhone's Keychain")
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.tertiary)

            Text(settings.provider == .openCode
                 ? "All 10 included models are free for a limited time"
                 : "Free OpenRouter models are marked in the picker")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.quaternary)
        }
        .padding(.top, 4)
        .padding(.bottom, 18)
    }

    private func badgeTint(for badge: String) -> Color {
        switch badge {
        case "Free": return .green
        case "Credits": return .orange
        case "OpenCode only": return .gray
        default: return OZOTheme.accent
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Late night ideas?"
        }
    }

    private struct Suggestion: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let prompt: String
        let tint: Color
    }
}
