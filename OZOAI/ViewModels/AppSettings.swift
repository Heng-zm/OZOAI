import Foundation
import SwiftUI

@MainActor
final class AppSettings: ObservableObject {
    enum Appearance: String, CaseIterable, Identifiable, Hashable {
        case system
        case light
        case dark

        var id: String { rawValue }

        var title: String {
            switch self {
            case .system: return "System"
            case .light: return "Light"
            case .dark: return "Dark"
            }
        }

        var symbol: String {
            switch self {
            case .system: return "circle.lefthalf.filled"
            case .light: return "sun.max.fill"
            case .dark: return "moon.fill"
            }
        }

        var colorScheme: ColorScheme? {
            switch self {
            case .system: return nil
            case .light: return .light
            case .dark: return .dark
            }
        }
    }

    static let defaultSystemPrompt = """
    You are OZO AI, a friendly and highly capable assistant.

    - Be clear, accurate and concise by default; go deeper when the question deserves it.
    - Format answers with Markdown: short paragraphs, headings when useful, and fenced code blocks with a language tag.
    - When writing code, provide complete, runnable examples and briefly explain the important parts.
    - If you are unsure, say so and explain your reasoning instead of inventing facts.
    - Ask a short clarifying question only when a request is genuinely ambiguous.
    """

    @Published var apiKey: String
    @Published var systemPrompt: String
    @Published var temperature: Double
    @Published var hapticsEnabled: Bool
    @Published var appearance: Appearance
    @Published var defaultModelID: String

    private let defaults = UserDefaults.standard

    init() {
        apiKey = KeychainStore.readAPIKey()

        systemPrompt = defaults.object(forKey: "ozo.systemPrompt") as? String
            ?? Self.defaultSystemPrompt

        temperature = defaults.object(forKey: "ozo.temperature") as? Double ?? 0.7
        hapticsEnabled = defaults.object(forKey: "ozo.haptics") as? Bool ?? true

        if let raw = defaults.string(forKey: "ozo.appearance"),
           let value = Appearance(rawValue: raw) {
            appearance = value
        } else {
            appearance = .system
        }

        let savedModel = defaults.string(forKey: "ozo.defaultModelID") ?? AIModel.defaultID
        defaultModelID = AIModel.all.contains(where: { $0.id == savedModel }) ? savedModel : AIModel.defaultID
    }

    var hasAPIKey: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var defaultModel: AIModel {
        AIModel.model(for: defaultModelID)
    }

    func savePreferences() {
        defaults.set(systemPrompt, forKey: "ozo.systemPrompt")
        defaults.set(temperature, forKey: "ozo.temperature")
        defaults.set(hapticsEnabled, forKey: "ozo.haptics")
        defaults.set(appearance.rawValue, forKey: "ozo.appearance")
        defaults.set(defaultModelID, forKey: "ozo.defaultModelID")
    }

    @discardableResult
    func persistAPIKey() -> Bool {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        apiKey = trimmed
        if trimmed.isEmpty {
            KeychainStore.deleteAPIKey()
            return true
        }
        return KeychainStore.saveAPIKey(trimmed)
    }

    func removeAPIKey() {
        apiKey = ""
        KeychainStore.deleteAPIKey()
    }

    func setDefaultModel(_ id: String) {
        guard AIModel.all.contains(where: { $0.id == id }) else { return }
        defaultModelID = id
        defaults.set(id, forKey: "ozo.defaultModelID")
    }

    func resetSystemPrompt() {
        systemPrompt = Self.defaultSystemPrompt
        defaults.set(systemPrompt, forKey: "ozo.systemPrompt")
    }
}
