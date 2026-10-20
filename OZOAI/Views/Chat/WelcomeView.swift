import Foundation
import SwiftUI

struct WelcomeView: View {
    let model: AIModel
    let hasAPIKey: Bool
    let onSuggestion: (String) -> Void
    let onConnect: () -> Void
    let onChooseModel: () -> Void

    @EnvironmentObject private var settings: AppSettings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    private static let suggestions: [Suggestion] = [
        Suggestion(
            icon: "lightbulb.fill",
            title: "Explain something",
            subtitle: "Make a tricky idea simple",
            prompt: "Explain how quantum computers work in a way that's easy to understand.",
            tint: Color(hex: 0xF59E0B)
        ),
        Suggestion(
            icon: "curlybraces",
            title: "Write code",
            subtitle: "Build something useful",
            prompt: "Write a polished SwiftUI screen for a todo app with add, complete and delete actions.",
            tint: Color(hex: 0x3B82F6)
        ),
        Suggestion(
            icon: "checklist",
            title: "Make a plan",
            subtitle: "Turn goals into next steps",
            prompt: "Help me plan a productive week. Ask me a few questions first, then give me a realistic schedule.",
            tint: Color(hex: 0x10B981)
        ),
        Suggestion(
            icon: "sparkles",
            title: "Brainstorm ideas",
            subtitle: "Find a fresh direction",
            prompt: "Brainstorm 10 creative names and concepts for a personal AI assistant app.",
            tint: Color(hex: 0x8B5CF6)
        )
    ]

    var body: some View {
        VStack(spacing: 22) {
            hero
            connectBanner
            suggestionGrid
            footer
        }
        .frame(maxWidth: 620)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 6)
        .onAppear {
            guard !appeared else { return }
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.spring(response: 0.65, dampingFraction: 0.86)) {
                    appeared = true
                }
            }
        }
    }

    private var hero: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(OZOTheme.accent.opacity(0.13))
                    .frame(width: 150, height: 150)
                    .blur(radius: 34)

                Circle()
                    .strokeBorder(OZOTheme.accent.opacity(0.10), lineWidth: 1)
                    .frame(width: 108, height: 108)

                OZOLogo(size: 74)
            }
            .frame(height: 108)
            .scaleEffect(appeared ? 1 : 0.86)
            .opacity(appeared ? 1 : 0)

            VStack(spacing: 7) {
                Text(greeting.uppercased())
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(OZOTheme.accent)

                Text("What can I help with?")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .tracking(-0.9)
                    .multilineTextAlignment(.center)

                Text("Ask anything. Claude, Zen, and more.")
                    .font(.system(size: 14.5))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .offset(y: appeared ? 0 : 10)
            .opacity(appeared ? 1 : 0)

            Button(action: onChooseModel) {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(model.tint.opacity(0.14))
                            .frame(width: 26, height: 26)

                        Image(systemName: model.symbol)
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(model.tint)
                    }

                    Text(model.shortName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if let badge = model.badgeText(on: settings.provider) {
                        OZOBadge(text: badge, tint: badgeTint(for: badge))
                    }

                    Image(systemName: "chevron.down")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.leading, 5)
                .padding(.trailing, 12)
                .padding(.vertical, 5)
                .background(Capsule().fill(OZOTheme.surface.opacity(0.94)))
                .overlay(Capsule().strokeBorder(OZOTheme.hairline, lineWidth: 0.8))
                .shadow(color: .black.opacity(0.035), radius: 8, y: 3)
            }
            .buttonStyle(OZOPressStyle())
            .accessibilityLabel("Choose model. Currently \(model.name)")

            if model.supportsVision {
                Label("This model can see photos — attach one with +", systemImage: "photo.badge.plus")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(model.tint)
                    .padding(.top, 1)
            }
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private var connectBanner: some View {
        if !hasAPIKey {
            Button(action: onConnect) {
                HStack(spacing: 13) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(OZOTheme.brandGradient)
                            .frame(width: 44, height: 44)
                        Image(systemName: "key.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .shadow(color: OZOTheme.accent.opacity(0.22), radius: 8, y: 3)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Connect \(settings.provider.displayName)")
                            .font(.system(size: 14.5, weight: .semibold))
                            .foregroundStyle(.primary)

                        Text(connectDescription)
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 4)

                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(OZOTheme.accent)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(OZOTheme.accent.opacity(0.10)))
                }
                .padding(13)
                .background(
                    RoundedRectangle(cornerRadius: 19, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [OZOTheme.accent.opacity(0.10), OZOTheme.violet.opacity(0.055)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 19, style: .continuous)
                        .strokeBorder(OZOTheme.accent.opacity(0.19), lineWidth: 0.9)
                )
            }
            .buttonStyle(OZOPressStyle())
            .accessibilityHint("Opens settings to add an API key")
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
            ForEach(0..<Self.suggestions.count, id: \.self) { index in
                let suggestion = Self.suggestions[index]

                Button {
                    Haptics.tap(settings.hapticsEnabled)
                    onSuggestion(suggestion.prompt)
                } label: {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .top) {
                            Image(systemName: suggestion.icon)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(suggestion.tint)
                                .frame(width: 31, height: 31)
                                .background(
                                    suggestion.tint.opacity(0.11),
                                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                                )

                            Spacer(minLength: 0)

                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.quaternary)
                                .padding(.top, 3)
                        }

                        Spacer(minLength: 10)

                        Text(suggestion.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(1)

                        Text(suggestion.subtitle)
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                            .padding(.top, 2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(13)
                    .frame(height: 118)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(OZOTheme.surface.opacity(0.94))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(OZOTheme.hairline, lineWidth: 0.8)
                    )
                }
                .buttonStyle(OZOPressStyle(scale: 0.98))
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 9)
                .animation(
                    reduceMotion
                        ? nil
                        : .spring(response: 0.5, dampingFraction: 0.86)
                            .delay(0.06 + Double(index) * 0.045),
                    value: appeared
                )
                .accessibilityHint("Sends this prompt")
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 7) {
            if hasAPIKey {
                HStack(spacing: 5) {
                    Circle()
                        .fill(OZOTheme.positive)
                        .frame(width: 5, height: 5)
                    Text("Connected to \(settings.provider.displayName)")
                }
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.035), in: Capsule())
            }

            HStack(spacing: 5) {
                Image(systemName: "lock.shield.fill")
                Text("Your API key stays in your iPhone's Keychain")
            }
            .font(.system(size: 9.5, weight: .medium))
            .foregroundStyle(.tertiary)

            Text(footerNote)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(.quaternary)
        }
        .padding(.top, 2)
        .padding(.bottom, 16)
    }

    private var connectDescription: String {
        switch settings.provider {
        case .openCode:
            return "Add your free key to unlock all 10 models."
        case .openRouter:
            return "Add your OpenRouter key to get started."
        case .anthropic:
            return "Add your Anthropic key to chat with Claude."
        }
    }

    private var footerNote: String {
        switch settings.provider {
        case .openCode:
            return "All 10 included models are free for a limited time"
        case .openRouter:
            return "Free OpenRouter models are marked in the picker"
        case .anthropic:
            return "Claude usage is billed through your Anthropic account"
        }
    }

    private func badgeTint(for badge: String) -> Color {
        switch badge {
        case "Free": return .green
        case "Credits": return .orange
        case "OpenCode only", "Claude only", "Unavailable": return .gray
        default: return OZOTheme.accent
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Late night ideas"
        }
    }

    private struct Suggestion: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let subtitle: String
        let prompt: String
        let tint: Color
    }
}
