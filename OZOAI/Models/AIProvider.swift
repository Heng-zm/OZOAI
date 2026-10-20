import Foundation

enum AIProvider: String, CaseIterable, Identifiable, Codable, Hashable {
    case openCode = "opencode"
    case openRouter = "openrouter"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openCode: return "OpenCode Zen"
        case .openRouter: return "OpenRouter"
        }
    }

    var shortName: String {
        switch self {
        case .openCode: return "OpenCode"
        case .openRouter: return "OpenRouter"
        }
    }

    var symbol: String {
        switch self {
        case .openCode: return "terminal.fill"
        case .openRouter: return "arrow.triangle.branch"
        }
    }

    var keychainAccount: String {
        switch self {
        case .openCode: return "opencode-api-key"
        case .openRouter: return "openrouter-api-key"
        }
    }

    var keyPlaceholder: String {
        switch self {
        case .openCode: return "sk-…"
        case .openRouter: return "sk-or-v1-…"
        }
    }

    var endpoint: URL {
        switch self {
        case .openCode:
            return URL(string: "https://opencode.ai/inference/openai/v1/chat/completions")!
        case .openRouter:
            return URL(string: "https://openrouter.ai/api/v1/chat/completions")!
        }
    }

    var consoleURL: URL {
        switch self {
        case .openCode:
            return URL(string: "https://opencode.ai/console")!
        case .openRouter:
            return URL(string: "https://openrouter.ai/keys")!
        }
    }

    var docsURL: URL {
        switch self {
        case .openCode:
            return URL(string: "https://opencode.ai/docs/zen")!
        case .openRouter:
            return URL(string: "https://openrouter.ai/docs")!
        }
    }

    var connectionTitle: String {
        "\(displayName) connection"
    }

    var consoleLinkTitle: String {
        switch self {
        case .openCode: return "Get a free API key"
        case .openRouter: return "Get an OpenRouter key"
        }
    }
}

// MARK: - OpenRouter catalog bridge

private struct OpenRouterModelInfo {
    let id: String
    let isFree: Bool
}

private let openRouterCatalog: [String: OpenRouterModelInfo] = [
    "deepseek-v4.1-flash-free": OpenRouterModelInfo(
        id: "deepseek/deepseek-v4.1-flash",
        isFree: false
    ),
    "glm-5.3-flash-free": OpenRouterModelInfo(
        id: "z-ai/glm-5.3-flash",
        isFree: false
    ),
    "minimax-m3.1-flash-free": OpenRouterModelInfo(
        id: "minimax/minimax-m3.1-flash:free",
        isFree: true
    ),
    "nemotron-3.5-super-vl-free": OpenRouterModelInfo(
        id: "nvidia/nemotron-3.5-super-vl:free",
        isFree: true
    ),
    "beam-free": OpenRouterModelInfo(
        id: "reflection/beam-1.0-501b-a23b",
        isFree: false
    ),
    "mimo-v2.6-flash-free": OpenRouterModelInfo(
        id: "xiaomi/mimo-v2.6-flash",
        isFree: false
    ),
    "nemotron-3.5-lightning-free": OpenRouterModelInfo(
        id: "nvidia/nemotron-3.5-lightning:free",
        isFree: true
    ),
    "nemotron-3-ultra-free": OpenRouterModelInfo(
        id: "nvidia/nemotron-3-ultra-550b-a55b:free",
        isFree: true
    )
]

extension AIModel {
    /// The model ID sent to the selected provider. `nil` means this model is
    /// only available on OpenCode Zen (Big Pickle and LongCat 2.5 Preview).
    func providerModelID(for provider: AIProvider) -> String? {
        switch provider {
        case .openCode:
            return id
        case .openRouter:
            return openRouterCatalog[id]?.id
        }
    }

    func isAvailable(on provider: AIProvider) -> Bool {
        providerModelID(for: provider) != nil
    }

    func isFree(on provider: AIProvider) -> Bool {
        switch provider {
        case .openCode:
            return true
        case .openRouter:
            return openRouterCatalog[id]?.isFree == true
        }
    }

    /// Small label shown beside a model in the current provider's catalog.
    func badgeText(on provider: AIProvider) -> String? {
        switch provider {
        case .openCode:
            return showsFreeBadge ? "Free" : nil
        case .openRouter:
            guard let info = openRouterCatalog[id] else { return "OpenCode only" }
            return info.isFree ? "Free" : "Credits"
        }
    }

    func availabilityNote(on provider: AIProvider) -> String? {
        switch provider {
        case .openCode:
            return nil
        case .openRouter:
            if openRouterCatalog[id] == nil {
                return "Available on OpenCode Zen only"
            }
            return openRouterCatalog[id]?.isFree == true
                ? "Free on OpenRouter"
                : "Uses OpenRouter credits"
        }
    }
}
