import SwiftUI
import UIKit

struct MessageRow: View, Equatable {
    let message: ChatMessage
    let isLastAssistant: Bool
    let onRegenerate: () -> Void

    @EnvironmentObject private var settings: AppSettings
    @State private var copied = false

    static func == (lhs: MessageRow, rhs: MessageRow) -> Bool {
        lhs.message == rhs.message && lhs.isLastAssistant == rhs.isLastAssistant
    }

    var body: some View {
        if message.role == .user {
            userMessage
        } else {
            assistantMessage
        }
    }

    private var assistantModel: AIModel? {
        guard let modelName = message.modelName else { return nil }
        return AIModel.all.first { $0.shortName == modelName }
    }

    // MARK: - User

    private var userMessage: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Spacer(minLength: 48)

            VStack(alignment: .trailing, spacing: 7) {
                if let data = message.imageData {
                    MessageImage(data: data)
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
                        .shadow(color: OZOTheme.accent.opacity(0.11), radius: 8, y: 3)
                        .textSelection(.enabled)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    // MARK: - Assistant

    private var assistantMessage: some View {
        HStack(alignment: .top, spacing: 10) {
            OZOLogo(size: 29)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 7) {
                    Text("OZO AI")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))

                    if let modelName = message.modelName {
                        AssistantModelTag(
                            name: modelName,
                            tint: assistantModel?.tint ?? .secondary
                        )
                    }

                    Spacer(minLength: 0)
                }

                MarkdownMessageView(text: message.text)

                HStack(spacing: 7) {
                    Button {
                        UIPasteboard.general.string = message.text
                        Haptics.success(settings.hapticsEnabled)
                        withAnimation(.easeOut(duration: 0.18)) { copied = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation(.easeOut(duration: 0.18)) { copied = false }
                        }
                    } label: {
                        messageActionLabel(
                            title: copied ? "Copied" : "Copy",
                            icon: copied ? "checkmark" : "doc.on.doc",
                            tint: copied ? OZOTheme.accent : Color.secondary
                        )
                    }
                    .buttonStyle(OZOPressStyle(scale: 0.96))
                    .accessibilityLabel(copied ? "Copied" : "Copy response")

                    if isLastAssistant {
                        Button(action: onRegenerate) {
                            messageActionLabel(
                                title: "Retry",
                                icon: "arrow.clockwise",
                                tint: Color.secondary
                            )
                        }
                        .buttonStyle(OZOPressStyle(scale: 0.96))
                        .accessibilityLabel("Regenerate response")
                    }
                }
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func messageActionLabel(title: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(title)
                .font(.system(size: 10.5, weight: .semibold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.primary.opacity(0.045), in: Capsule())
    }
}

private struct AssistantModelTag: View {
    let name: String
    let tint: Color

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(tint)
                .frame(width: 4.5, height: 4.5)

            Text(name)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2.5)
        .background(Color.primary.opacity(0.04), in: Capsule())
    }
}

/// Decodes an attachment once per row instead of on every parent re-render.
private struct MessageImage: View {
    let data: Data
    @State private var image: UIImage?

    init(data: Data) {
        self.data = data
        _image = State(initialValue: nil)
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 240, maxHeight: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                    )
            } else {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
                    .frame(width: 180, height: 140)
            }
        }
        .onAppear {
            if image == nil {
                image = UIImage(data: data)
            }
        }
    }
}

struct StreamingRow: View {
    let text: String
    let model: AIModel

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            OZOLogo(size: 29)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 7) {
                    Text("OZO AI")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))

                    AssistantModelTag(name: model.shortName, tint: model.tint)

                    Spacer(minLength: 0)

                    Text("Responding")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(OZOTheme.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(OZOTheme.accent.opacity(0.09), in: Capsule())
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
