import SwiftUI
import UIKit

// MARK: - Brand palette

enum OZOTheme {
    static let accent = Color(hex: 0x10B5A5)
    static let accentDeep = Color(hex: 0x0E7490)

    static let brandGradient = LinearGradient(
        colors: [Color(hex: 0x2DD4BF), Color(hex: 0x3B82F6), Color(hex: 0x8B5CF6)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let userBubbleGradient = LinearGradient(
        colors: [Color(hex: 0x11B8A6), Color(hex: 0x0B7FD1)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let ambient = LinearGradient(
        stops: [
            .init(color: Color(hex: 0x14B8A6).opacity(0.08), location: 0.0),
            .init(color: Color.clear, location: 0.45),
            .init(color: Color(hex: 0x8B5CF6).opacity(0.06), location: 1.0)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let groupedBackground = Color(uiColor: .systemGroupedBackground)
    static let background = Color(uiColor: .systemBackground)
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)
    static let elevated = Color(uiColor: .tertiarySystemGroupedBackground)
    static let codeBackground = Color(uiColor: .secondarySystemGroupedBackground)
    static let hairline = Color.primary.opacity(0.07)
}

extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

// MARK: - Brand mark

struct OZOLogo: View {
    var size: CGFloat = 32
    var glowing: Bool = true

    var body: some View {
        ZStack {
            Circle()
                .fill(OZOTheme.brandGradient)

            Circle()
                .strokeBorder(Color.white.opacity(0.94), lineWidth: max(1.5, size * 0.072))
                .padding(size * 0.28)

            Circle()
                .fill(Color.white)
                .frame(width: size * 0.115, height: size * 0.115)
                .offset(x: size * 0.29, y: -size * 0.29)
        }
        .frame(width: size, height: size)
        .shadow(
            color: OZOTheme.accent.opacity(glowing ? 0.35 : 0),
            radius: size * 0.22,
            x: 0,
            y: size * 0.09
        )
        .accessibilityHidden(true)
    }
}

struct OZOWordmark: View {
    var compact: Bool = false
    var body: some View {
        HStack(spacing: compact ? 8 : 10) {
            OZOLogo(size: compact ? 28 : 34)
            Text("OZO AI")
                .font(.system(size: compact ? 17 : 20, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .tracking(-0.3)
        }
    }
}

// MARK: - Haptics

enum Haptics {
    static func tap(_ enabled: Bool) {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.7)
    }

    static func soft(_ enabled: Bool) {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.6)
    }

    static func success(_ enabled: Bool) {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func error(_ enabled: Bool) {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}

// MARK: - Button style

struct OZOPressStyle: ButtonStyle {
    var scale: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.86 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Date helpers

extension Date {
    var ozoRelativeLabel: String {
        let interval = Date().timeIntervalSince(self)
        if interval < 60 { return "Just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86_400 { return "\(Int(interval / 3600))h ago" }
        if interval < 604_800 { return "\(Int(interval / 86_400))d ago" }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: self)
    }
}

// MARK: - Shared surfaces

extension View {
    func ozoCard(cornerRadius: CGFloat = 20) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(OZOTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(OZOTheme.hairline, lineWidth: 0.8)
        )
    }
}
