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

    @Published var provider: AIProvider = .openCode {
        didSet {
            defaults.set(provider.rawValue, forKey: "ozo.provider")
        }
    }
    @Published private(set) var openCodeAPIKey: String = ""
    @Published private(set) var openRouterAPIKey: String = ""
    @Published private(set) var anthropicAPIKey: String = ""
    @Published var systemPrompt: String
    @Published var temperature: Double
    @Published var hapticsEnabled: Bool
    @Published var appearance: Appearance
    @Published var defaultModelID: String
    @Published var baseURLOverrides: [String: String] = [:]

    private let defaults = UserDefaults.standard

    init() {
        if let raw = defaults.string(forKey: "ozo.provider"),
           let savedProvider = AIProvider(rawValue: raw) {
            provider = savedProvider
        } else {
            provider = .openCode
        }

        openCodeAPIKey = KeychainStore.readAPIKey(for: .openCode)
        openRouterAPIKey = KeychainStore.readAPIKey(for: .openRouter)
        anthropicAPIKey = KeychainStore.readAPIKey(for: .anthropic)

        var loadedBaseURLs: [String: String] = [:]
        if let savedURLs = defaults.dictionary(forKey: "ozo.baseURLs") as? [String: String] {
            for (rawProvider, value) in savedURLs {
                guard let savedProvider = AIProvider(rawValue: rawProvider),
                      (try? savedProvider.endpoint(baseURL: value)) != nil else {
                    continue
                }
                loadedBaseURLs[rawProvider] = value
            }
        }

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
        baseURLOverrides = loadedBaseURLs

        ensureDefaultModelAvailable(for: provider)
    }

    var apiKey: String {
        get {
            switch provider {
            case .openCode: return openCodeAPIKey
            case .openRouter: return openRouterAPIKey
            case .anthropic: return anthropicAPIKey
            }
        }
        set {
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            switch provider {
            case .openCode: openCodeAPIKey = trimmed
            case .openRouter: openRouterAPIKey = trimmed
            case .anthropic: anthropicAPIKey = trimmed
            }
        }
    }

    var hasAPIKey: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func hasAPIKey(for provider: AIProvider) -> Bool {
        switch provider {
        case .openCode:
            return !openCodeAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .openRouter:
            return !openRouterAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .anthropic:
            return !anthropicAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    func baseURL(for provider: AIProvider) -> String {
        baseURLOverrides[provider.rawValue] ?? provider.defaultBaseURLString
    }

    func isUsingDefaultBaseURL(for provider: AIProvider) -> Bool {
        baseURLOverrides[provider.rawValue] == nil
    }

    func resolvedEndpoint(for provider: AIProvider) throws -> URL {
        try provider.endpoint(baseURL: baseURL(for: provider))
    }

    func setBaseURL(_ value: String, for provider: AIProvider) throws {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == provider.defaultBaseURLString {
            baseURLOverrides.removeValue(forKey: provider.rawValue)
        } else {
            _ = try provider.endpoint(baseURL: trimmed)
            baseURLOverrides[provider.rawValue] = trimmed
        }
        defaults.set(baseURLOverrides, forKey: "ozo.baseURLs")
    }

    func resetBaseURL(for provider: AIProvider) {
        baseURLOverrides.removeValue(forKey: provider.rawValue)
        defaults.set(baseURLOverrides, forKey: "ozo.baseURLs")
    }

    var defaultModel: AIModel {
        AIModel.model(for: defaultModelID)
    }

    func savePreferences() {
        defaults.set(provider.rawValue, forKey: "ozo.provider")
        defaults.set(systemPrompt, forKey: "ozo.systemPrompt")
        defaults.set(temperature, forKey: "ozo.temperature")
        defaults.set(hapticsEnabled, forKey: "ozo.haptics")
        defaults.set(appearance.rawValue, forKey: "ozo.appearance")
        defaults.set(defaultModelID, forKey: "ozo.defaultModelID")
        defaults.set(baseURLOverrides, forKey: "ozo.baseURLs")
    }

    @discardableResult
    func persistAPIKey() -> Bool {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        apiKey = trimmed
        if trimmed.isEmpty {
            KeychainStore.deleteAPIKey(for: provider)
            return true
        }
        return KeychainStore.saveAPIKey(trimmed, for: provider)
    }

    func removeAPIKey() {
        apiKey = ""
        KeychainStore.deleteAPIKey(for: provider)
    }

    func setDefaultModel(_ id: String) {
        guard AIModel.all.contains(where: { $0.id == id }) else { return }
        defaultModelID = id
        defaults.set(id, forKey: "ozo.defaultModelID")
    }

    /// Keeps new chats usable when the provider changes. The OpenCode/OpenRouter
    /// default stays GLM; Anthropic falls back to Claude Sonnet.
    func ensureDefaultModelAvailable(for provider: AIProvider) {
        guard !defaultModel.isAvailable(on: provider) else { return }

        let preferredID: String
        switch provider {
        case .openCode, .openRouter:
            preferredID = AIModel.defaultID
        case .anthropic:
            preferredID = "claude-sonnet-5-5"
        }

        if AIModel.model(for: preferredID).isAvailable(on: provider) {
            setDefaultModel(preferredID)
        } else if let fallback = AIModel.all.first(where: { $0.isAvailable(on: provider) }) {
            setDefaultModel(fallback.id)
        }
    }

    func resetSystemPrompt() {
        systemPrompt = Self.defaultSystemPrompt
        defaults.set(systemPrompt, forKey: "ozo.systemPrompt")
    }
}
