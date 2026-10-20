import AVFoundation
import Foundation
import Speech

@MainActor
final class SpeechRecognizer: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var transcript = ""
    @Published var errorMessage: String?

    private let recognizer = (
        SFSpeechRecognizer(locale: Locale.current)
            ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    )
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var hasInstalledTap = false

    func toggle() {
        if isRecording {
            stop()
        } else {
            start()
        }
    }

    func start() {
        guard !isRecording else { return }
        errorMessage = nil
        transcript = ""

        guard SFSpeechRecognizer.authorizationStatus() != .denied else {
            errorMessage = "Speech Recognition is turned off. Enable it in iOS Settings → Privacy → Speech Recognition."
            return
        }

        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor in
                guard let self else { return }
                switch status {
                case .authorized:
                    self.requestMicrophoneAndRecord()
                case .denied, .restricted:
                    self.errorMessage = "Speech Recognition permission is required for voice input. You can enable it in iOS Settings."
                case .notDetermined:
                    self.errorMessage = "Speech Recognition permission wasn't granted."
                @unknown default:
                    self.errorMessage = "Speech Recognition isn't available right now."
                }
            }
        }
    }

    func stop() {
        audioEngine?.stop()
        if hasInstalledTap, let engine = audioEngine {
            engine.inputNode.removeTap(onBus: 0)
            hasInstalledTap = false
        }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func clearError() {
        errorMessage = nil
    }

    func reset() {
        stop()
        transcript = ""
    }

    // MARK: - Private

    private func requestMicrophoneAndRecord() {
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            Task { @MainActor in
                guard let self else { return }
                if granted {
                    self.beginRecording()
                } else {
                    self.errorMessage = "Microphone access is required for voice input. Enable it in iOS Settings → Privacy → Microphone."
                }
            }
        }
    }

    private func beginRecording() {
        guard let recognizer, recognizer.isAvailable else {
            errorMessage = "Speech recognition isn't available right now. Try again in a moment."
            return
        }

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            let engine = AVAudioEngine()
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            request.taskHint = .dictation

            let inputNode = engine.inputNode
            let format = inputNode.outputFormat(forBus: 0)
            guard format.channelCount > 0, format.sampleRate > 0 else {
                errorMessage = "No microphone input was found on this device."
                try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
                return
            }

            inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                request.append(buffer)
            }
            hasInstalledTap = true
            audioEngine = engine

            engine.prepare()
            try engine.start()

            recognitionRequest = request
            isRecording = true

            recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor in
                    guard let self else { return }

                    if let result {
                        self.transcript = result.bestTranscription.formattedString
                        if result.isFinal {
                            self.stop()
                            return
                        }
                    }

                    if let error, self.isRecording {
                        let nsError = error as NSError
                        if nsError.domain != "kAFAssistantErrorDomain" || nsError.code != 216 {
                            self.errorMessage = "Voice input stopped: \(error.localizedDescription)"
                        }
                        self.stop()
                    }
                }
            }
        } catch {
            if hasInstalledTap, let engine = audioEngine {
                engine.inputNode.removeTap(onBus: 0)
                hasInstalledTap = false
            }
            audioEngine?.stop()
            audioEngine = nil
            recognitionRequest = nil
            recognitionTask?.cancel()
            recognitionTask = nil
            isRecording = false
            errorMessage = "Couldn't start the microphone: \(error.localizedDescription)"
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }
}
