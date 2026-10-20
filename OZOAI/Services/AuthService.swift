import AuthenticationServices
import CryptoKit
import Foundation
import UIKit

// MARK: - Models

struct SupabaseConfig: Equatable {
    var projectURL: String
    var anonKey: String

    var baseURL: URL? {
        Self.normalizedProjectURL(projectURL)
    }

    var isConfigured: Bool {
        baseURL != nil && !anonKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var host: String {
        baseURL?.host ?? "Supabase"
    }

    static func normalizedProjectURL(_ raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !trimmed.contains("$("),
              var components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(),
              let host = components.host,
              !host.isEmpty,
              components.query == nil,
              components.fragment == nil else {
            return nil
        }

        let isLocal = host == "localhost" || host == "127.0.0.1"
        guard scheme == "https" || (scheme == "http" && isLocal) else {
            return nil
        }

        var path = components.path
        while path.count > 1 && path.hasSuffix("/") {
            path.removeLast()
        }
        if path == "/" {
            path = ""
        }
        if path.hasSuffix("/auth/v1") {
            path.removeLast("/auth/v1".count)
        }
        components.path = path

        return components.url
    }
}

struct AuthUser: Codable, Equatable, Identifiable {
    let id: String
    let email: String?
}

struct AuthSession: Codable, Equatable {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date
    let user: AuthUser

    var isExpiringSoon: Bool {
        expiresAt.timeIntervalSinceNow < 120
    }
}

enum SupabaseOAuthProvider: String, CaseIterable, Identifiable, Hashable {
    case google
    case apple

    var id: String { rawValue }

    var title: String {
        switch self {
        case .google: return "Google"
        case .apple: return "Apple"
        }
    }
}

enum AuthSignUpResult {
    case signedIn
    case confirmationRequired
}

enum AuthError: LocalizedError, Equatable {
    case notConfigured
    case invalidConfiguration
    case invalidResponse
    case cancelled
    case network(String)
    case server(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Set up your account server before signing in."
        case .invalidConfiguration:
            return "The account server URL or publishable key doesn't look right."
        case .invalidResponse:
            return "The account server returned an unexpected response."
        case .cancelled:
            return "Sign-in was cancelled."
        case .network(let message):
            return message
        case .server(let message):
            return message
        }
    }
}

// MARK: - Auth service

@MainActor
final class AuthService: ObservableObject {
    @Published private(set) var session: AuthSession?
    @Published private(set) var config: SupabaseConfig
    @Published private(set) var isRefreshing = false
    @Published private(set) var enabledOAuthProviders: Set<SupabaseOAuthProvider> = []
    @Published private(set) var oauthSettingsLoaded = false

    static let redirectURL = URL(string: "ozoai://auth-callback")!
    static let callbackScheme = "ozoai"

    private let defaults = UserDefaults.standard
    private let sessionAccount = "supabase-session"
    private let pendingEmailPKCEAccount = "supabase-email-pkce"
    private let httpSession: URLSession
    private let webAuth = OAuthWebSession()

    private enum Keys {
        static let projectURL = "ozo.auth.projectURL"
        static let anonKey = "ozo.auth.anonKey"
        static let disabled = "ozo.auth.disabled"
    }

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        configuration.waitsForConnectivity = true
        httpSession = URLSession(configuration: configuration)

        config = Self.loadConfig()
        session = nil

        if config.isConfigured,
           let data = KeychainStore.readData(account: sessionAccount),
           let saved = try? JSONDecoder().decode(AuthSession.self, from: data) {
            session = saved
        }
    }

    // MARK: Account state

    var isSignedIn: Bool {
        session != nil
    }

    var accountEmail: String {
        session?.user.email ?? "Signed in"
    }

    var accountName: String {
        guard let email = session?.user.email, let local = email.split(separator: "@").first else {
            return "OZO account"
        }
        return String(local)
    }

    var initials: String {
        guard let first = accountName.first else { return "O" }
        return String(first).uppercased()
    }

    /// `nil` means the server settings haven't loaded yet, so the app lets the
    /// user try and reports the server's error if the provider is disabled.
    func isOAuthProviderEnabled(_ provider: SupabaseOAuthProvider) -> Bool? {
        guard oauthSettingsLoaded else { return nil }
        return enabledOAuthProviders.contains(provider)
    }

    func refreshOAuthProviders() async {
        await refreshOAuthAvailability()
    }

    // MARK: Startup and refresh

    func bootstrap() async {
        await refreshOAuthAvailability()

        guard let current = session else { return }
        guard config.isConfigured else {
            clearSession()
            return
        }

        if current.isExpiringSoon {
            await refreshSession(force: true)
        }
    }

    func refreshIfNeeded() async {
        guard session != nil else { return }
        await refreshSession(force: false)
    }

    private func refreshSession(force: Bool) async {
        guard !isRefreshing,
              let current = session,
              let refreshToken = current.refreshToken,
              !refreshToken.isEmpty else {
            return
        }
        guard force || current.isExpiringSoon else { return }

        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let body = try JSONEncoder().encode(RefreshPayload(refreshToken: refreshToken))
            let request = try makeRequest(
                path: "token",
                query: [URLQueryItem(name: "grant_type", value: "refresh_token")],
                method: "POST",
                body: body
            )
            let response: TokenResponse = try await perform(request, as: TokenResponse.self)
            let refreshed = try await makeSession(
                from: response,
                fallbackUser: current.user,
                fallbackRefreshToken: refreshToken
            )
            setSession(refreshed)
        } catch let error as AuthError {
            switch error {
            case .network:
                // Keep the existing session and try again when the app is active.
                break
            default:
                clearSession()
            }
        } catch {
            clearSession()
        }
    }

    // MARK: Email and password

    func signUp(email: String, password: String) async throws -> AuthSignUpResult {
        try requireConfiguration()

        // PKCE makes the email-confirmation link return a short-lived code
        // instead of putting tokens in the URL fragment.
        let pkce = Self.makePKCE()
        let payload = SignUpPayload(
            email: normalizedEmail(email),
            password: password,
            codeChallenge: pkce.challenge,
            codeChallengeMethod: "s256"
        )
        let body = try JSONEncoder().encode(payload)
        let request = try makeRequest(
            path: "signup",
            query: [URLQueryItem(name: "redirect_to", value: Self.redirectURL.absoluteString)],
            method: "POST",
            body: body
        )
        let response: SignUpResponse = try await perform(request, as: SignUpResponse.self)

        if let accessToken = response.accessToken, !accessToken.isEmpty {
            let tokenResponse = TokenResponse(
                accessToken: accessToken,
                refreshToken: response.refreshToken,
                expiresIn: response.expiresIn,
                user: response.user
            )
            let user = response.user?.authUser
                ?? response.id.map { AuthUser(id: $0, email: response.email ?? normalizedEmail(email)) }
            let newSession = try await makeSession(
                from: tokenResponse,
                fallbackUser: user,
                fallbackRefreshToken: response.refreshToken
            )
            clearPendingEmailPKCE()
            setSession(newSession)
            return .signedIn
        }

        if response.user != nil || response.id != nil {
            savePendingEmailPKCE(pkce.verifier)
            return .confirmationRequired
        }

        throw AuthError.invalidResponse
    }

    func signIn(email: String, password: String) async throws {
        try requireConfiguration()

        let payload = PasswordPayload(email: normalizedEmail(email), password: password)
        let body = try JSONEncoder().encode(payload)
        let request = try makeRequest(
            path: "token",
            query: [URLQueryItem(name: "grant_type", value: "password")],
            method: "POST",
            body: body
        )
        let response: TokenResponse = try await perform(request, as: TokenResponse.self)
        let newSession = try await makeSession(
            from: response,
            fallbackUser: nil,
            fallbackRefreshToken: nil
        )
        setSession(newSession)
    }

    // MARK: OAuth

    func signInWithOAuth(_ provider: SupabaseOAuthProvider) async throws {
        try requireConfiguration()
        guard let baseURL = config.baseURL else { throw AuthError.invalidConfiguration }

        if let enabled = isOAuthProviderEnabled(provider), !enabled {
            throw AuthError.server(
                "\(provider.title) sign-in isn't enabled on this account server yet. Enable it in Supabase → Authentication → Providers."
            )
        }

        let pkce = Self.makePKCE()
        var components = URLComponents(
            url: baseURL.appendingPathComponent("auth/v1/authorize"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "provider", value: provider.rawValue),
            URLQueryItem(name: "redirect_to", value: Self.redirectURL.absoluteString),
            URLQueryItem(name: "code_challenge", value: pkce.challenge),
            URLQueryItem(name: "code_challenge_method", value: "s256")
        ]

        guard let authorizationURL = components?.url else {
            throw AuthError.invalidConfiguration
        }

        let callback = try await webAuth.start(
            url: authorizationURL,
            callbackScheme: Self.callbackScheme
        )

        let callbackComponents = URLComponents(url: callback, resolvingAgainstBaseURL: false)
        let queryItems = (callbackComponents?.queryItems ?? [])
            + Self.fragmentItems(from: callback)

        func callbackValue(_ name: String) -> String? {
            queryItems.first(where: { $0.name == name })?.value
        }

        if let error = callbackValue("error_description") ?? callbackValue("error") {
            throw Self.mappedServerError(error, status: 400)
        }

        if let code = callbackValue("code"), !code.isEmpty {
            let body = try JSONEncoder().encode(
                PKCEPayload(authCode: code, codeVerifier: pkce.verifier)
            )
            let request = try makeRequest(
                path: "token",
                query: [URLQueryItem(name: "grant_type", value: "pkce")],
                method: "POST",
                body: body
            )
            let response: TokenResponse = try await perform(request, as: TokenResponse.self)
            let newSession = try await makeSession(
                from: response,
                fallbackUser: nil,
                fallbackRefreshToken: nil
            )
            setSession(newSession)
            return
        }

        // Some projects still use the implicit flow and return the session in
        // the callback fragment. Accept it as a fallback.
        if let accessToken = callbackValue("access_token"), !accessToken.isEmpty {
            let response = TokenResponse(
                accessToken: accessToken,
                refreshToken: callbackValue("refresh_token"),
                expiresIn: Int(callbackValue("expires_in") ?? "3600"),
                user: nil
            )
            let newSession = try await makeSession(
                from: response,
                fallbackUser: nil,
                fallbackRefreshToken: nil
            )
            setSession(newSession)
            return
        }

        throw AuthError.invalidResponse
    }

    /// Handles the custom-scheme redirect used by email confirmation. OAuth
    /// browser sign-in is completed inside `ASWebAuthenticationSession`; this
    /// path covers links opened from Mail.
    @discardableResult
    func handleCallback(_ url: URL) async -> Bool {
        guard url.scheme?.lowercased() == Self.callbackScheme else { return false }

        let callbackComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = (callbackComponents?.queryItems ?? [])
            + Self.fragmentItems(from: url)

        func callbackValue(_ name: String) -> String? {
            queryItems.first(where: { $0.name == name })?.value
        }

        if callbackValue("error") != nil || callbackValue("error_description") != nil {
            return false
        }

        if let code = callbackValue("code"), !code.isEmpty,
           let verifier = takePendingEmailPKCE() {
            do {
                let body = try JSONEncoder().encode(
                    PKCEPayload(authCode: code, codeVerifier: verifier)
                )
                let request = try makeRequest(
                    path: "token",
                    query: [URLQueryItem(name: "grant_type", value: "pkce")],
                    method: "POST",
                    body: body
                )
                let response: TokenResponse = try await perform(request, as: TokenResponse.self)
                let newSession = try await makeSession(
                    from: response,
                    fallbackUser: nil,
                    fallbackRefreshToken: nil
                )
                setSession(newSession)
                return true
            } catch {
                return false
            }
        }

        // Older projects can still return an implicit-flow fragment.
        if let accessToken = callbackValue("access_token"), !accessToken.isEmpty {
            clearPendingEmailPKCE()
            let response = TokenResponse(
                accessToken: accessToken,
                refreshToken: callbackValue("refresh_token"),
                expiresIn: Int(callbackValue("expires_in") ?? "3600"),
                user: nil
            )
            do {
                let newSession = try await makeSession(
                    from: response,
                    fallbackUser: nil,
                    fallbackRefreshToken: nil
                )
                setSession(newSession)
                return true
            } catch {
                return false
            }
        }

        return false
    }

    // MARK: Server configuration

    /// Validates the project with `/auth/v1/settings`, then saves it.
    func configure(projectURL: String, anonKey: String) async throws {
        let candidate = try await validatedConfiguration(
            projectURL: projectURL,
            anonKey: anonKey
        )

        let changed = candidate != config
        config = candidate
        defaults.set(candidate.projectURL, forKey: Keys.projectURL)
        defaults.set(candidate.anonKey, forKey: Keys.anonKey)
        defaults.removeObject(forKey: Keys.disabled)

        if changed {
            clearSession()
        }

        oauthSettingsLoaded = false
        enabledOAuthProviders = []
        await refreshOAuthAvailability()
    }

    func testConfiguration(projectURL: String, anonKey: String) async throws {
        _ = try await validatedConfiguration(projectURL: projectURL, anonKey: anonKey)
    }

    func clearConfiguration() {
        defaults.removeObject(forKey: Keys.projectURL)
        defaults.removeObject(forKey: Keys.anonKey)
        defaults.set(true, forKey: Keys.disabled)
        config = SupabaseConfig(projectURL: "", anonKey: "")
        enabledOAuthProviders = []
        oauthSettingsLoaded = false
        clearPendingEmailPKCE()
        clearSession()
    }

    // MARK: Sign out

    func signOut() async {
        if let token = session?.accessToken,
           let request = try? makeRequest(
                path: "logout",
                method: "POST",
                body: Data("{}".utf8),
                accessToken: token
           ) {
            _ = try? await httpSession.data(for: request)
        }
        clearSession()
    }

    // MARK: Session storage

    private func setSession(_ newSession: AuthSession) {
        session = newSession
        clearPendingEmailPKCE()
        guard let data = try? JSONEncoder().encode(newSession) else { return }
        KeychainStore.saveData(
            data,
            account: sessionAccount,
            label: "OZO AI — Account session"
        )
    }

    private func clearSession() {
        session = nil
        KeychainStore.delete(account: sessionAccount)
    }

    // MARK: Email confirmation PKCE

    private func savePendingEmailPKCE(_ verifier: String) {
        _ = KeychainStore.saveString(
            verifier,
            account: pendingEmailPKCEAccount,
            label: "OZO AI — Email confirmation"
        )
    }

    private func takePendingEmailPKCE() -> String? {
        let verifier = KeychainStore.readString(account: pendingEmailPKCEAccount)
        KeychainStore.delete(account: pendingEmailPKCEAccount)
        return verifier
    }

    private func clearPendingEmailPKCE() {
        KeychainStore.delete(account: pendingEmailPKCEAccount)
    }

    private func makeSession(
        from response: TokenResponse,
        fallbackUser: AuthUser?,
        fallbackRefreshToken: String?
    ) async throws -> AuthSession {
        guard let accessToken = response.accessToken, !accessToken.isEmpty else {
            throw AuthError.invalidResponse
        }

        let user: AuthUser
        if let responseUser = response.user?.authUser {
            user = responseUser
        } else if let fallbackUser {
            user = fallbackUser
        } else {
            user = try await fetchUser(accessToken: accessToken)
        }

        let refreshToken = response.refreshToken ?? fallbackRefreshToken
        let expiresAt = Date().addingTimeInterval(TimeInterval(response.expiresIn ?? 3600))

        return AuthSession(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: expiresAt,
            user: user
        )
    }

    private func fetchUser(accessToken: String) async throws -> AuthUser {
        let request = try makeRequest(
            path: "user",
            method: "GET",
            body: nil,
            accessToken: accessToken
        )
        let user: UserResponse = try await perform(request, as: UserResponse.self)
        guard let authUser = user.authUser else {
            throw AuthError.invalidResponse
        }
        return authUser
    }

    // MARK: Configuration validation

    private func requireConfiguration() throws {
        guard config.isConfigured else { throw AuthError.notConfigured }
    }

    private func refreshOAuthAvailability() async {
        guard config.isConfigured, let baseURL = config.baseURL else {
            oauthSettingsLoaded = false
            enabledOAuthProviders = []
            return
        }

        var components = URLComponents(
            url: baseURL.appendingPathComponent("auth/v1/settings"),
            resolvingAgainstBaseURL: false
        )
        components?.query = nil
        guard let url = components?.url else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("OZO-AI-iOS/1.0", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await httpSession.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else {
                return
            }
            let settings = try JSONDecoder().decode(AuthSettingsResponse.self, from: data)
            var providers: Set<SupabaseOAuthProvider> = []
            if settings.external?.google == true { providers.insert(.google) }
            if settings.external?.apple == true { providers.insert(.apple) }
            enabledOAuthProviders = providers
            oauthSettingsLoaded = true
        } catch {
            // Keep the buttons usable. If a provider is still disabled, the
            // sign-in request returns a clear provider-not-enabled message.
        }
    }

    private func validatedConfiguration(
        projectURL: String,
        anonKey: String
    ) async throws -> SupabaseConfig {
        guard let normalizedURL = SupabaseConfig.normalizedProjectURL(projectURL) else {
            throw AuthError.invalidConfiguration
        }

        let key = anonKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            throw AuthError.invalidConfiguration
        }

        let candidate = SupabaseConfig(
            projectURL: normalizedURL.absoluteString,
            anonKey: key
        )

        var components = URLComponents(
            url: normalizedURL.appendingPathComponent("auth/v1/settings"),
            resolvingAgainstBaseURL: false
        )
        components?.query = nil
        guard let url = components?.url else {
            throw AuthError.invalidConfiguration
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        request.setValue(key, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("OZO-AI-iOS/1.0", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await httpSession.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw AuthError.invalidResponse
            }
            guard (200..<300).contains(http.statusCode) else {
                throw Self.error(from: data, status: http.statusCode)
            }
        } catch let error as AuthError {
            throw error
        } catch let error as URLError {
            throw AuthError.network(Self.networkMessage(error))
        } catch {
            throw AuthError.network(error.localizedDescription)
        }

        return candidate
    }

    private static func loadConfig() -> SupabaseConfig {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Keys.disabled) else {
            return SupabaseConfig(projectURL: "", anonKey: "")
        }

        let savedURL = defaults.string(forKey: Keys.projectURL)
        let savedKey = defaults.string(forKey: Keys.anonKey)

        let infoURL = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String
        let infoKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String

        let rawURL = savedURL ?? infoURL ?? ""
        let rawKey = savedKey ?? infoKey ?? ""

        let url = SupabaseConfig.normalizedProjectURL(rawURL)?.absoluteString ?? rawURL
        return SupabaseConfig(
            projectURL: url,
            anonKey: rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    // MARK: HTTP

    private func makeRequest(
        path: String,
        query: [URLQueryItem] = [],
        method: String,
        body: Data?,
        accessToken: String? = nil
    ) throws -> URLRequest {
        guard let baseURL = config.baseURL else {
            throw AuthError.notConfigured
        }

        var components = URLComponents(
            url: baseURL.appendingPathComponent("auth/v1/\(path)"),
            resolvingAgainstBaseURL: false
        )
        if !query.isEmpty {
            components?.queryItems = query
        }
        guard let url = components?.url else {
            throw AuthError.invalidConfiguration
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("OZO-AI-iOS/1.0", forHTTPHeaderField: "User-Agent")
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if let accessToken, !accessToken.isEmpty {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = body
        return request
    }

    private func perform<T: Decodable>(_ request: URLRequest, as type: T.Type) async throws -> T {
        do {
            let (data, response) = try await httpSession.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw AuthError.invalidResponse
            }
            guard (200..<300).contains(http.statusCode) else {
                throw Self.error(from: data, status: http.statusCode)
            }
            guard !data.isEmpty else {
                throw AuthError.invalidResponse
            }
            return try JSONDecoder().decode(T.self, from: data)
        } catch let error as AuthError {
            throw error
        } catch let error as URLError {
            throw AuthError.network(Self.networkMessage(error))
        } catch is DecodingError {
            throw AuthError.invalidResponse
        } catch {
            throw AuthError.network(error.localizedDescription)
        }
    }

    private static func error(from data: Data, status: Int) -> AuthError {
        let message = serverMessage(from: data)
        guard !message.isEmpty else {
            return .server("The account server returned an error (HTTP \(status)).")
        }
        return mappedServerError(message, status: status)
    }

    private static func mappedServerError(_ raw: String, status: Int) -> AuthError {
        let message = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = message.lowercased()

        if lower.contains("invalid login credentials") {
            return .server("Email or password is incorrect.")
        }
        if lower.contains("email not confirmed") {
            return .server("Confirm your email first, then sign in.")
        }
        if lower.contains("user already registered") || lower.contains("already been registered") {
            return .server("An account with this email already exists. Try signing in.")
        }
        if lower.contains("provider is not enabled") || lower.contains("unsupported provider") {
            return .server("That sign-in provider isn't enabled for this account server yet.")
        }
        if lower.contains("redirect_uri_mismatch") || lower.contains("redirect url") {
            return .server("Add ozoai://auth-callback to the Supabase redirect URLs.")
        }
        if lower.contains("invalid api key") || lower.contains("no api key") {
            return .server("The Supabase publishable key wasn't accepted.")
        }
        if lower.contains("password should be") || lower.contains("weak password") {
            return .server(message)
        }
        if lower.contains("rate limit") || lower.contains("too many requests") {
            return .server("Too many attempts. Wait a moment, then try again.")
        }
        if lower.contains("failed to fetch") || lower.contains("network") {
            return .network(message)
        }
        return .server(message)
    }

    private static func serverMessage(from data: Data) -> String {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return String((String(data: data, encoding: .utf8) ?? "").prefix(320))
        }

        if let error = object["error"] as? String, !error.isEmpty {
            return error
        }
        if let error = object["error"] as? [String: Any],
           let message = error["message"] as? String {
            return message
        }
        for key in ["error_description", "msg", "message", "error_code"] {
            if let value = object[key] as? String, !value.isEmpty {
                return value
            }
        }
        return ""
    }

    private static func networkMessage(_ error: URLError) -> String {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost:
            return "You're offline. Check your connection and try again."
        case .timedOut:
            return "The account server took too long to respond. Try again."
        case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            return "Can't reach the account server. Check the project URL."
        case .secureConnectionFailed, .serverCertificateUntrusted:
            return "A secure connection to the account server couldn't be established."
        default:
            return error.localizedDescription
        }
    }

    private func normalizedEmail(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    // MARK: PKCE

    private struct PKCE {
        let verifier: String
        let challenge: String
    }

    private static func makePKCE() -> PKCE {
        let key = SymmetricKey(size: .bits256)
        let verifier = key.withUnsafeBytes { Data($0) }.base64URLEncodedString()
        let digest = SHA256.hash(data: Data(verifier.utf8))
        let challenge = Data(digest).base64URLEncodedString()
        return PKCE(verifier: verifier, challenge: challenge)
    }

    private static func fragmentItems(from url: URL) -> [URLQueryItem] {
        guard let fragment = URLComponents(url: url, resolvingAgainstBaseURL: false)?.fragment else {
            return []
        }
        var components = URLComponents()
        components.query = fragment
        return components.queryItems ?? []
    }
}

// MARK: - Wire payloads

private struct PasswordPayload: Encodable {
    let email: String
    let password: String
}

private struct SignUpPayload: Encodable {
    let email: String
    let password: String
    let codeChallenge: String
    let codeChallengeMethod: String

    enum CodingKeys: String, CodingKey {
        case email
        case password
        case codeChallenge = "code_challenge"
        case codeChallengeMethod = "code_challenge_method"
    }
}

private struct RefreshPayload: Encodable {
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}

private struct PKCEPayload: Encodable {
    let authCode: String
    let codeVerifier: String

    enum CodingKeys: String, CodingKey {
        case authCode = "auth_code"
        case codeVerifier = "code_verifier"
    }
}

private struct AuthSettingsResponse: Decodable {
    struct External: Decodable {
        let google: Bool?
        let apple: Bool?
    }

    let external: External?
}

private struct SupabaseUserResponse: Decodable {
    let id: String
    let email: String?

    var authUser: AuthUser {
        AuthUser(id: id, email: email)
    }
}

private struct UserResponse: Decodable {
    let id: String
    let email: String?

    var authUser: AuthUser? {
        id.isEmpty ? nil : AuthUser(id: id, email: email)
    }
}

private struct TokenResponse: Decodable {
    let accessToken: String?
    let refreshToken: String?
    let expiresIn: Int?
    let user: SupabaseUserResponse?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case user
    }
}

private struct SignUpResponse: Decodable {
    let accessToken: String?
    let refreshToken: String?
    let expiresIn: Int?
    let user: SupabaseUserResponse?
    let id: String?
    let email: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case user
        case id
        case email
    }
}

// MARK: - Web authentication

private final class OAuthWebSession: NSObject, ASWebAuthenticationPresentationContextProviding {
    private var session: ASWebAuthenticationSession?

    func start(url: URL, callbackScheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            var didResume = false

            func finish(_ result: Result<URL, Error>) {
                guard !didResume else { return }
                didResume = true
                self.session = nil
                continuation.resume(with: result)
            }

            let authSession = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: callbackScheme
            ) { callbackURL, error in
                if let error {
                    if let authError = error as? ASWebAuthenticationSessionError,
                       authError.code == .canceledLogin {
                        finish(.failure(AuthError.cancelled))
                    } else {
                        finish(.failure(AuthError.network(error.localizedDescription)))
                    }
                    return
                }

                guard let callbackURL else {
                    finish(.failure(AuthError.invalidResponse))
                    return
                }
                finish(.success(callbackURL))
            }

            authSession.presentationContextProvider = self
            authSession.prefersEphemeralWebBrowserSession = false
            self.session = authSession

            if !authSession.start() {
                finish(.failure(AuthError.server("The sign-in browser couldn't be opened.")))
            }
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let windows = scenes.flatMap(\.windows)
        return windows.first(where: \.isKeyWindow)
            ?? windows.first
            ?? UIWindow(frame: .zero)
    }
}

// MARK: - Base64 URL

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
