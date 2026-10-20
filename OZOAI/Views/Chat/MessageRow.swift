import SwiftUI
import UIKit

struct MessageRow: View {
    let message: ChatMessage
    let isLastAssistant: Bool
    let onRegenerate: () -> Void

    @EnvironmentObject private var settings: AppSettings
    @State private var copied = false

    var body: some View {
        if message.role == .user {
            userMessage
        } else {
            assistantMessage
        }
    }

    // MARK: - User

    private var userMessage: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Spacer(minLength: 48)

            VStack(alignment: .trailing, spacing: 7) {
                if let data = message.imageData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 240, maxHeight: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                        )
                }

                if !message.text.isEmpty {
                    Text(message.text)
                        .font(.system(size: 16))
                        .lineSpacing(3)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                        .background(
                            OZOTheme.userBubbleGradient,
                            in: RoundedRectangle(cornerRadius: 21, style: .continuous)
                        )
                        .textSelection(.enabled)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    // MARK: - Assistant

    private var assistantMessage: some View {
        HStack(alignment: .top, spacing: 10) {
            OZOLogo(size: 28)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 7) {
                    Text("OZO AI")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))

                    if let modelName = message.modelName {
                        Text(modelName)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }

                MarkdownMessageView(text: message.text)

                HStack(spacing: 16) {
                    Button {
                        UIPasteboard.general.string = message.text
                        Haptics.success(settings.hapticsEnabled)
                        withAnimation(.easeOut(duration: 0.18)) { copied = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation(.easeOut(duration: 0.18)) { copied = false }
                        }
                    } label: {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(copied ? OZOTheme.accent : Color.secondary)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(copied ? "Copied" : "Copy response")

                    if isLastAssistant {
                        Button(action: onRegenerate) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Regenerate response")
                    }
                }
                .padding(.top, 1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct StreamingRow: View {
    let text: String
    let model: AIModel

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            OZOLogo(size: 28)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 7) {
                    Text("OZO AI")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                    Text(model.shortName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }

                if text.isEmpty {
                    TypingIndicator(tint: model.tint)
                        .transition(.opacity)
                } else {
                    MarkdownMessageView(text: text, isStreaming: true)
                }
            }

            Spacer(minLength: 20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
