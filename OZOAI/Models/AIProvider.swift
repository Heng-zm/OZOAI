import Foundation

enum AIProvider: String, CaseIterable, Identifiable, Codable, Hashable {
    case openCode = "opencode"
    case openRouter = "openrouter"
    case anthropic = "anthropic"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openCode: return "OpenCode Zen"
        case .openRouter: return "OpenRouter"
        case .anthropic: return "Anthropic Claude"
        }
    }

    var shortName: String {
        switch self {
        case .openCode: return "OpenCode"
        case .openRouter: return "OpenRouter"
        case .anthropic: return "Claude"
        }
    }

    var symbol: String {
        switch self {
        case .openCode: return "terminal.fill"
        case .openRouter: return "arrow.triangle.branch"
        case .anthropic: return "sparkle"
        }
    }

    var keychainAccount: String {
        switch self {
        case .openCode: return "opencode-api-key"
        case .openRouter: return "openrouter-api-key"
        case .anthropic: return "anthropic-api-key"
        }
    }

    var keyPlaceholder: String {
        switch self {
        case .openCode: return "sk-…"
        case .openRouter: return "sk-or-v1-…"
        case .anthropic: return "sk-ant-api03-…"
        }
    }

    /// The root used by the editable API base URL setting. The app appends
    /// the provider's chat path unless the user pasted a full endpoint.
    var defaultBaseURLString: String {
        switch self {
        case .openCode: return "https://opencode.ai/inference/openai/v1"
        case .openRouter: return "https://openrouter.ai/api/v1"
        case .anthropic: return "https://api.anthropic.com"
        }
    }

    var chatPath: String {
        switch self {
        case .openCode, .openRouter: return "chat/completions"
        case .anthropic: return "v1/messages"
        }
    }

    var isOpenAICompatible: Bool {
        switch self {
        case .openCode, .openRouter: return true
        case .anthropic: return false
        }
    }

    var endpoint: URL {
        (try? endpoint(baseURL: defaultBaseURLString))
            ?? URL(string: "https://opencode.ai")!
    }

    /// Resolves a user-edited base URL. A full `/chat/completions` or
    /// `/v1/messages` URL is accepted as-is; otherwise the provider path is
    /// appended. Anthropic also accepts a base ending in `/v1`.
    func endpoint(baseURL: String) throws -> URL {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = trimmed.isEmpty ? defaultBaseURLString : trimmed

        guard var components = URLComponents(string: candidate),
              let scheme = components.scheme?.lowercased(),
              scheme == "https" || scheme == "http",
              let host = components.host,
              !host.isEmpty,
              components.fragment == nil else {
            throw AIProviderEndpointError.invalidURL(candidate)
        }

        var path = components.path
        while path.count > 1 && path.hasSuffix("/") {
            path.removeLast()
        }

        let suffix = "/" + chatPath
        if !path.hasSuffix(suffix) {
            if self == .anthropic, path.hasSuffix("/v1") {
                path += "/messages"
            } else {
                path += suffix
            }
        }

        components.path = path.hasPrefix("/") ? path : "/" + path
        guard let url = components.url else {
            throw AIProviderEndpointError.invalidURL(candidate)
        }
        return url
    }

    var consoleURL: URL {
        switch self {
        case .openCode:
            return URL(string: "https://opencode.ai/console")!
        case .openRouter:
            return URL(string: "https://openrouter.ai/keys")!
        case .anthropic:
            return URL(string: "https://console.anthropic.com/settings/keys")!
        }
    }

    var docsURL: URL {
        switch self {
        case .openCode:
            return URL(string: "https://opencode.ai/docs/zen")!
        case .openRouter:
            return URL(string: "https://openrouter.ai/docs")!
        case .anthropic:
            return URL(string: "https://platform.claude.com/docs/en/api/messages")!
        }
    }

    var connectionTitle: String {
        "\(displayName) connection"
    }

    var consoleLinkTitle: String {
        switch self {
        case .openCode: return "Get a free API key"
        case .openRouter: return "Get an OpenRouter key"
        case .anthropic: return "Get an Anthropic key"
        }
    }
}

enum AIProviderEndpointError: LocalizedError {
    case invalidURL(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Enter a valid HTTP or HTTPS API base URL."
        }
    }
}

// MARK: - Provider catalogs

private let openCodeModelIDs: Set<String> = [
    "big-pickle",
    "deepseek-v4.1-flash-free",
    "glm-5.3-flash-free",
    "minimax-m3.1-flash-free",
    "nemotron-3.5-super-vl-free",
    "beam-free",
    "longcat-2.5-preview-free",
    "mimo-v2.6-flash-free",
    "nemotron-3.5-lightning-free",
    "nemotron-3-ultra-free"
]

private let anthropicModelIDs: Set<String> = [
    "claude-fable-5-1",
    "claude-opus-5-5",
    "claude-sonnet-5-5",
    "claude-haiku-5-5"
]

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
    /// not available on that provider at all.
    func providerModelID(for provider: AIProvider) -> String? {
        switch provider {
        case .openCode:
            return openCodeModelIDs.contains(id) ? id : nil
        case .openRouter:
            return openRouterCatalog[id]?.id
        case .anthropic:
            return anthropicModelIDs.contains(id) ? id : nil
        }
    }

    func isAvailable(on provider: AIProvider) -> Bool {
        providerModelID(for: provider) != nil
    }

    func isFree(on provider: AIProvider) -> Bool {
        switch provider {
        case .openCode:
            return openCodeModelIDs.contains(id)
        case .openRouter:
            return openRouterCatalog[id]?.isFree == true
        case .anthropic:
            return false
        }
    }

    /// Small label shown beside a model in the current provider's catalog.
    func badgeText(on provider: AIProvider) -> String? {
        switch provider {
        case .openCode:
            if anthropicModelIDs.contains(id) { return "Claude only" }
            return showsFreeBadge ? "Free" : nil
        case .openRouter:
            if let info = openRouterCatalog[id] {
                return info.isFree ? "Free" : "Credits"
            }
            return anthropicModelIDs.contains(id) ? "Claude only" : "OpenCode only"
        case .anthropic:
            return anthropicModelIDs.contains(id) ? "Credits" : "Unavailable"
        }
    }

    func availabilityNote(on provider: AIProvider) -> String? {
        switch provider {
        case .openCode:
            if anthropicModelIDs.contains(id) {
                return "Available on Anthropic Claude only"
            }
            return nil
        case .openRouter:
            if let info = openRouterCatalog[id] {
                return info.isFree ? "Free on OpenRouter" : "Uses OpenRouter credits"
            }
            return anthropicModelIDs.contains(id)
                ? "Available on Anthropic Claude only"
                : "Available on OpenCode Zen only"
        case .anthropic:
            if anthropicModelIDs.contains(id) {
                return "Billed through your Anthropic account"
            }
            return "Available on OpenCode Zen or OpenRouter"
        }
    }
}
