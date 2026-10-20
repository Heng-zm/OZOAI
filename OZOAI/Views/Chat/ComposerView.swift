import Photos
import PhotosUI
import SwiftUI
import UIKit

struct ComposerView: View {
    /// Changing this token clears the composer. Keeping the draft and photo
    /// local to the composer avoids re-rendering the entire chat on each key.
    let resetToken: UUID
    let isStreaming: Bool
    let model: AIModel
    @ObservedObject var speech: SpeechRecognizer
    let onSend: (String, UIImage?) -> Void
    let onStop: () -> Void
    let onSwitchToVision: () -> Void

    @EnvironmentObject private var settings: AppSettings
    @FocusState private var isFocused: Bool

    @State private var text = ""
    @State private var image: UIImage?
    @State private var photoItem: PhotosPickerItem?
    @State private var photoLoadID = UUID()
    @State private var ignoreTranscription = false
    @State private var showSpeechAlert = false
    @State private var speechPrefix = ""

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || image != nil
    }

    var body: some View {
        VStack(spacing: 7) {
            if let image {
                attachmentPreview(image)
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
            }

            if speech.isRecording {
                recordingBar
                    .transition(.opacity)
            }

            inputBar

            Text("OZO AI can make mistakes. Check important info.")
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(.tertiary)
                .padding(.bottom, 2)
        }
        .onChange(of: resetToken) { _, _ in
            resetComposer()
        }
        .onChange(of: photoItem) { _, newItem in
            loadPhoto(newItem)
        }
        .onChange(of: speech.transcript) { _, newTranscript in
            guard !ignoreTranscription else { return }
            guard speech.isRecording || !newTranscript.isEmpty else { return }
            let prefix = speechPrefix.trimmingCharacters(in: .whitespacesAndNewlines)
            let spoken = newTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
            if prefix.isEmpty {
                text = spoken
            } else if spoken.isEmpty {
                text = prefix
            } else {
                text = prefix + " " + spoken
            }
        }
        .onChange(of: speech.errorMessage) { _, newValue in
            showSpeechAlert = newValue != nil
        }
        .alert("Voice input", isPresented: $showSpeechAlert) {
            Button("OK", role: .cancel) { speech.clearError() }
        } message: {
            Text(speech.errorMessage ?? "Something went wrong with voice input.")
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: image != nil)
        .animation(.easeInOut(duration: 0.2), value: speech.isRecording)
    }

    // MARK: - Input bar

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 2) {
            PhotosPicker(
                selection: $photoItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                composerButtonLabel(
                    systemName: "plus",
                    foreground: isStreaming ? Color.secondary.opacity(0.35) : Color.secondary
                )
            }
            .buttonStyle(OZOPressStyle())
            .disabled(isStreaming)
            .accessibilityLabel("Attach a photo")

            TextField("Ask anything…", text: $text, axis: .vertical)
                .focused($isFocused)
                .font(.system(size: 16))
                .lineLimit(1...6)
                .lineSpacing(2)
                .padding(.vertical, 9)
                .padding(.horizontal, 4)
                .textInputAutocapitalization(.sentences)
                .submitLabel(.return)
                .accessibilityLabel("Message")

            Button {
                if speech.isRecording {
                    speech.stop()
                } else {
                    ignoreTranscription = false
                    speechPrefix = text
                    Haptics.tap(settings.hapticsEnabled)
                    speech.start()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(speech.isRecording ? Color.red.opacity(0.12) : Color.clear)
                        .frame(width: 36, height: 36)

                    Image(systemName: speech.isRecording ? "waveform" : "mic.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(speech.isRecording ? Color.red : Color.secondary)
                }
            }
            .buttonStyle(OZOPressStyle())
            .disabled(isStreaming)
            .accessibilityLabel(speech.isRecording ? "Stop dictation" : "Dictate a message")

            if isStreaming {
                Button(action: onStop) {
                    ZStack {
                        Circle()
                            .fill(Color.primary)
                            .frame(width: 36, height: 36)
                        RoundedRectangle(cornerRadius: 2.2, style: .continuous)
                            .fill(Color(uiColor: .systemBackground))
                            .frame(width: 10, height: 10)
                    }
                }
                .buttonStyle(OZOPressStyle())
                .accessibilityLabel("Stop response")
                .transition(.scale.combined(with: .opacity))
            } else {
                Button {
                    guard canSend else { return }
                    Haptics.tap(settings.hapticsEnabled)
                    onSend(text, image)
                } label: {
                    ZStack {
                        Circle()
                            .fill(
                                canSend
                                    ? AnyShapeStyle(OZOTheme.userBubbleGradient)
                                    : AnyShapeStyle(Color.primary.opacity(0.08))
                            )
                            .frame(width: 36, height: 36)
                            .shadow(
                                color: canSend ? OZOTheme.accent.opacity(0.24) : .clear,
                                radius: 8,
                                y: 3
                            )

                        Image(systemName: "arrow.up")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(canSend ? Color.white : Color.secondary)
                    }
                }
                .buttonStyle(OZOPressStyle())
                .disabled(!canSend)
                .accessibilityLabel("Send message")
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.leading, 7)
        .padding(.trailing, 7)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 27, style: .continuous)
                .fill(OZOTheme.surface.opacity(0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 27, style: .continuous)
                .strokeBorder(
                    isFocused ? OZOTheme.accent.opacity(0.36) : OZOTheme.hairline,
                    lineWidth: isFocused ? 1.15 : 0.9
                )
        )
        .shadow(
            color: isFocused ? OZOTheme.accent.opacity(0.08) : Color.black.opacity(0.055),
            radius: isFocused ? 18 : 14,
            x: 0,
            y: 5
        )
        .animation(.easeOut(duration: 0.18), value: isFocused)
    }

    // MARK: - Attachment

    private func attachmentPreview(_ image: UIImage) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 62, height: 62)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text("Photo attached")
                    .font(.system(size: 13, weight: .semibold))

                if model.supportsVision {
                    Text("\(model.shortName) can analyze this image.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(model.shortName) can't see images. Sending will switch to \(AIModel.model(for: AIModel.visionModelID).shortName).")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Button(action: onSwitchToVision) {
                        HStack(spacing: 3) {
                            Image(systemName: "eye.fill")
                            Text("Switch now")
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(OZOTheme.accent)
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer(minLength: 4)

            Button {
                withAnimation(.easeOut(duration: 0.18)) { self.image = nil }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(Color.primary.opacity(0.06)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove photo")
        }
        .padding(9)
        .background(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(OZOTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .strokeBorder(OZOTheme.hairline, lineWidth: 0.8)
        )
    }

    // MARK: - Recording

    private var recordingBar: some View {
        HStack(spacing: 9) {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
                .shadow(color: .red.opacity(0.5), radius: 4)

            Text("Listening…")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                speech.stop()
            } label: {
                Text("Done")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(OZOTheme.accent)
            }
            .buttonStyle(.plain)

            Button {
                speech.stop()
                speech.reset()
                text = speechPrefix
            } label: {
                Text("Cancel")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color.red.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(Color.red.opacity(0.14), lineWidth: 0.8)
        )
    }

    // MARK: - Helpers

    private func composerButtonLabel(systemName: String, foreground: Color) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(foreground)
            .frame(width: 36, height: 36)
            .background(Circle().fill(Color.primary.opacity(0.045)))
            .overlay(Circle().strokeBorder(OZOTheme.hairline, lineWidth: 0.6))
    }

    private func resetComposer() {
        photoLoadID = UUID()
        photoItem = nil
        ignoreTranscription = true
        speechPrefix = ""

        if speech.isRecording {
            speech.stop()
        }
        if !text.isEmpty {
            text = ""
        }
        if image != nil {
            withAnimation(.easeOut(duration: 0.18)) {
                image = nil
            }
        }
    }

    private func loadPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }

        let loadID = UUID()
        photoLoadID = loadID

        Task { @MainActor in
            defer {
                if photoLoadID == loadID {
                    photoItem = nil
                }
            }

            guard let data = try? await item.loadTransferable(type: Data.self),
                  let raw = UIImage(data: data),
                  photoLoadID == loadID else {
                return
            }

            // Vision requests downscale to 1200 px, so avoid keeping a larger
            // decoded photo in memory (and in the saved conversation).
            let resized = raw.ozoResized(maxDimension: 1200)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                image = resized
            }
            Haptics.soft(settings.hapticsEnabled)
        }
    }
}
