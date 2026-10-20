import Foundation

// MARK: - Shared wire types

struct WireMessage: Encodable {
    let role: String
    let content: WireContent
}

enum WireContent: Encodable {
    case text(String)
    case parts([WirePart])

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let value):
            try container.encode(value)
        case .parts(let parts):
            try container.encode(parts)
        }
    }
}

struct WirePart: Encodable {
    let type: String
    let text: String?
    let image_url: WireImageURL?

    struct WireImageURL: Encodable {
        let url: String
    }

    static func text(_ value: String) -> WirePart {
        WirePart(type: "text", text: value, image_url: nil)
    }

    static func image(dataURL: String) -> WirePart {
        WirePart(type: "image_url", text: nil, image_url: WireImageURL(url: dataURL))
    }
}

// MARK: - OpenAI-compatible wire types

private struct ChatRequest: Encodable {
    let model: String
    let messages: [WireMessage]
    let stream: Bool
    let temperature: Double
    let max_tokens: Int?
}

private struct StreamEnvelope: Decodable {
    struct Choice: Decodable {
        let delta: Content?
        let message: Content?
    }

    struct Content: Decodable {
        let content: String?
    }

    struct APIError: Decodable {
        let message: String?
    }

    let choices: [Choice]?
    let error: APIError?
}

// MARK: - Anthropic wire types

private struct AnthropicRequest: Encodable {
    let model: String
    let max_tokens: Int
    let messages: [AnthropicMessage]
    let system: String?
    let stream: Bool
    let temperature: Double
}

private struct AnthropicMessage: Encodable {
    let role: String
    let content: [AnthropicBlock]
}

private enum AnthropicBlock: Encodable {
    case text(String)
    case image(mediaType: String, base64: String)

    private enum CodingKeys: String, CodingKey {
        case type
        case text
        case source
    }

    private enum SourceCodingKeys: String, CodingKey {
        case type
        case mediaType = "media_type"
        case data
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .text(let value):
            try container.encode("text", forKey: .type)
            try container.encode(value, forKey: .text)

        case .image(let mediaType, let base64):
            try container.encode("image", forKey: .type)
            var source = container.nestedContainer(keyedBy: SourceCodingKeys.self, forKey: .source)
            try source.encode("base64", forKey: .type)
            try source.encode(mediaType, forKey: .mediaType)
            try source.encode(base64, forKey: .data)
        }
    }
}

private struct AnthropicStreamEnvelope: Decodable {
    struct Delta: Decodable {
        let type: String?
        let text: String?
    }

    struct APIError: Decodable {
        let type: String?
        let message: String?
    }

    let type: String?
    let delta: Delta?
    let error: APIError?
}

// MARK: - Errors

enum AIClientError: LocalizedError {
    case missingAPIKey(AIProvider)
    case modelUnavailable(AIProvider)
    case invalidResponse
    case emptyResponse
    case http(provider: AIProvider, status: Int, message: String)
    case network(AIProvider, String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let provider):
            return "Add your \(provider.displayName) API key in Settings to start chatting."
        case .modelUnavailable(let provider):
            return "This model isn't available on \(provider.displayName). Pick another model or switch providers."
        case .invalidResponse:
            return "OZO AI couldn't read the model response. Please try again."
        case .emptyResponse:
            return "The model returned an empty response. Try again or pick another model."
        case .http(let provider, let status, let message):
            switch status {
            case 401:
                return "That \(provider.shortName) API key wasn't accepted. Update it in Settings."
            case 402:
                return "This model needs credits on \(provider.displayName). Pick another model or add credits, then try again."
            case 403:
                return "Access was denied. Check your API key and that this model is available in your region."
            case 404:
                return "That model isn't available on \(provider.displayName) right now. Pick another model."
            case 429:
                return "Too many requests. Wait a few seconds, then try again."
            case 500...599:
                return "The model service is having trouble right now. Please try again shortly."
            default:
                return message.isEmpty ? "Request failed (HTTP \(status))." : message
            }
        case .network(let provider, let message):
            return message.isEmpty
                ? "Can't reach \(provider.displayName) right now. Check your connection and try again."
                : message
        }
    }
}

// MARK: - Client

final class AIClient {
    static let shared = AIClient()

    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 120
        configuration.timeoutIntervalForResource = 900
        configuration.waitsForConnectivity = true
        session = URLSession(configuration: configuration)
    }

    /// Streams a response from the selected provider. OpenAI-compatible
    /// providers use SSE chat completions; Claude uses the Messages API.
    func streamChat(
        provider: AIProvider,
        apiKey: String,
        modelID: String,
        baseURL: String,
        messages: [WireMessage],
        temperature: Double
    ) -> AsyncThrowingStream<String, Error> {
        if provider == .anthropic {
            return streamAnthropic(
                provider: provider,
                apiKey: apiKey,
                modelID: modelID,
                baseURL: baseURL,
                messages: messages,
                temperature: temperature
            )
        }
        return streamOpenAI(
            provider: provider,
            apiKey: apiKey,
            modelID: modelID,
            baseURL: baseURL,
            messages: messages,
            temperature: temperature
        )
    }

    // MARK: - OpenAI-compatible streaming

    private func streamOpenAI(
        provider: AIProvider,
        apiKey: String,
        modelID: String,
        baseURL: String,
        messages: [WireMessage],
        temperature: Double
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                var receivedContent = false

                do {
                    let body = ChatRequest(
                        model: modelID,
                        messages: messages,
                        stream: true,
                        temperature: temperature,
                        max_tokens: nil
                    )
                    let request = try makeOpenAIRequest(
                        provider: provider,
                        apiKey: apiKey,
                        baseURL: baseURL,
                        body: body,
                        accept: "text/event-stream",
                        timeout: 300
                    )

                    let (bytes, response) = try await session.bytes(for: request)

                    guard let http = response as? HTTPURLResponse else {
                        throw AIClientError.invalidResponse
                    }

                    guard (200..<300).contains(http.statusCode) else {
                        var errorBody = ""
                        for try await line in bytes.lines {
                            errorBody += line
                            if errorBody.count > 2_000 { break }
                        }
                        throw AIClientError.http(
                            provider: provider,
                            status: http.statusCode,
                            message: Self.serverMessage(from: errorBody)
                        )
                    }

                    let decoder = JSONDecoder()

                    for try await line in bytes.lines {
                        if Task.isCancelled { break }

                        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard trimmed.hasPrefix("data:") else { continue }

                        var payload = String(trimmed.dropFirst(5))
                        if payload.hasPrefix(" ") { payload.removeFirst() }
                        if payload.isEmpty { continue }
                        if payload == "[DONE]" { break }

                        guard let data = payload.data(using: .utf8),
                              let envelope = try? decoder.decode(StreamEnvelope.self, from: data) else {
                            continue
                        }

                        if let message = envelope.error?.message, !message.isEmpty {
                            throw AIClientError.http(
                                provider: provider,
                                status: 200,
                                message: message
                            )
                        }

                        guard let choice = envelope.choices?.first else { continue }

                        if let piece = choice.delta?.content, !piece.isEmpty {
                            receivedContent = true
                            continuation.yield(piece)
                        } else if !receivedContent,
                                  let piece = choice.message?.content,
                                  !piece.isEmpty {
                            // Some providers only send the full text in the final frame.
                            receivedContent = true
                            continuation.yield(piece)
                        }
                    }

                    if Task.isCancelled {
                        continuation.finish()
                        return
                    }
                    if !receivedContent {
                        throw AIClientError.emptyResponse
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch let error as URLError where error.code == .cancelled {
                    continuation.finish()
                } catch let error as URLError {
                    continuation.finish(
                        throwing: AIClientError.network(provider, Self.message(for: error, provider: provider))
                    )
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    // MARK: - Anthropic streaming

    private func streamAnthropic(
        provider: AIProvider,
        apiKey: String,
        modelID: String,
        baseURL: String,
        messages: [WireMessage],
        temperature: Double
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                var receivedContent = false

                do {
                    let payload = Self.anthropicPayload(from: messages)
                    guard !payload.messages.isEmpty else {
                        throw AIClientError.invalidResponse
                    }

                    let body = AnthropicRequest(
                        model: modelID,
                        max_tokens: 8_192,
                        messages: payload.messages,
                        system: payload.system,
                        stream: true,
                        temperature: temperature
                    )
                    let request = try makeAnthropicRequest(
                        apiKey: apiKey,
                        baseURL: baseURL,
                        body: body,
                        accept: "text/event-stream",
                        timeout: 300
                    )

                    let (bytes, response) = try await session.bytes(for: request)

                    guard let http = response as? HTTPURLResponse else {
                        throw AIClientError.invalidResponse
                    }

                    guard (200..<300).contains(http.statusCode) else {
                        var errorBody = ""
                        for try await line in bytes.lines {
                            errorBody += line
                            if errorBody.count > 2_000 { break }
                        }
                        throw AIClientError.http(
                            provider: provider,
                            status: http.statusCode,
                            message: Self.serverMessage(from: errorBody)
                        )
                    }

                    let decoder = JSONDecoder()

                    for try await line in bytes.lines {
                        if Task.isCancelled { break }

                        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard trimmed.hasPrefix("data:") else { continue }

                        var dataString = String(trimmed.dropFirst(5))
                        if dataString.hasPrefix(" ") { dataString.removeFirst() }
                        if dataString.isEmpty { continue }

                        guard let data = dataString.data(using: .utf8),
                              let envelope = try? decoder.decode(AnthropicStreamEnvelope.self, from: data) else {
                            continue
                        }

                        if let message = envelope.error?.message, !message.isEmpty {
                            throw AIClientError.http(
                                provider: provider,
                                status: 200,
                                message: message
                            )
                        }

                        if envelope.type == "content_block_delta",
                           envelope.delta?.type == "text_delta",
                           let piece = envelope.delta?.text,
                           !piece.isEmpty {
                            receivedContent = true
                            continuation.yield(piece)
                        }

                        if envelope.type == "message_stop" {
                            break
                        }
                    }

                    if Task.isCancelled {
                        continuation.finish()
                        return
                    }
                    if !receivedContent {
                        throw AIClientError.emptyResponse
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch let error as URLError where error.code == .cancelled {
                    continuation.finish()
                } catch let error as URLError {
                    continuation.finish(
                        throwing: AIClientError.network(provider, Self.message(for: error, provider: provider))
                    )
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    // MARK: - Validation

    /// Sends a tiny request to verify that an API key and endpoint work.
    func validate(provider: AIProvider, apiKey: String, baseURL: String) async throws {
        let request: URLRequest

        switch provider {
        case .openCode, .openRouter:
            let modelID: String
            if provider == .openCode {
                modelID = AIModel.defaultID
            } else {
                // Use one of OpenRouter's free models so validation does not
                // require credits on the account.
                modelID = "nvidia/nemotron-3.5-lightning:free"
            }

            let body = ChatRequest(
                model: modelID,
                messages: [WireMessage(role: "user", content: .text("Reply with OK."))],
                stream: false,
                temperature: 0.2,
                max_tokens: 4
            )
            request = try makeOpenAIRequest(
                provider: provider,
                apiKey: apiKey,
                baseURL: baseURL,
                body: body,
                accept: "application/json",
                timeout: 45
            )

        case .anthropic:
            let body = AnthropicRequest(
                model: "claude-haiku-5-5",
                max_tokens: 8,
                messages: [
                    AnthropicMessage(
                        role: "user",
                        content: [.text("Reply with OK.")]
                    )
                ],
                system: nil,
                stream: false,
                temperature: 0.2
            )
            request = try makeAnthropicRequest(
                apiKey: apiKey,
                baseURL: baseURL,
                body: body,
                accept: "application/json",
                timeout: 45
            )
        }

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw AIClientError.invalidResponse
            }
            guard (200..<300).contains(http.statusCode) else {
                let raw = String(data: data, encoding: .utf8) ?? ""
                throw AIClientError.http(
                    provider: provider,
                    status: http.statusCode,
                    message: Self.serverMessage(from: raw)
                )
            }
        } catch let error as URLError {
            throw AIClientError.network(provider, Self.message(for: error, provider: provider))
        }
    }

    // MARK: - Requests

    private func makeOpenAIRequest(
        provider: AIProvider,
        apiKey: String,
        baseURL: String,
        body: ChatRequest,
        accept: String,
        timeout: TimeInterval
    ) throws -> URLRequest {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw AIClientError.missingAPIKey(provider) }

        var request = URLRequest(url: try provider.endpoint(baseURL: baseURL))
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(accept, forHTTPHeaderField: "Accept")
        request.setValue("OZO-AI-iOS/1.0", forHTTPHeaderField: "User-Agent")

        if provider == .openRouter {
            request.setValue("https://github.com/Heng-zm/OZOAI", forHTTPHeaderField: "HTTP-Referer")
            request.setValue("OZO AI", forHTTPHeaderField: "X-Title")
        }

        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    private func makeAnthropicRequest(
        apiKey: String,
        baseURL: String,
        body: AnthropicRequest,
        accept: String,
        timeout: TimeInterval
    ) throws -> URLRequest {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw AIClientError.missingAPIKey(.anthropic) }

        var request = URLRequest(url: try AIProvider.anthropic.endpoint(baseURL: baseURL))
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(accept, forHTTPHeaderField: "Accept")
        request.setValue("OZO-AI-iOS/1.0", forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    // MARK: - Anthropic conversion

    private static func anthropicPayload(
        from messages: [WireMessage]
    ) -> (system: String?, messages: [AnthropicMessage]) {
        var systemParts: [String] = []
        var result: [AnthropicMessage] = []

        for message in messages {
            if message.role == "system" {
                systemParts.append(contentsOf: textParts(from: message.content))
                continue
            }

            var blocks: [AnthropicBlock] = []
            switch message.content {
            case .text(let text):
                if !text.isEmpty {
                    blocks.append(.text(text))
                }
            case .parts(let parts):
                for part in parts {
                    if let text = part.text, !text.isEmpty {
                        blocks.append(.text(text))
                    } else if let image = part.image_url,
                              let block = anthropicImageBlock(from: image.url) {
                        blocks.append(block)
                    }
                }
            }

            if !blocks.isEmpty {
                result.append(
                    AnthropicMessage(
                        role: message.role == "assistant" ? "assistant" : "user",
                        content: blocks
                    )
                )
            }
        }

        let system = systemParts
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n\n")

        return (system.isEmpty ? nil : system, result)
    }

    private static func textParts(from content: WireContent) -> [String] {
        switch content {
        case .text(let text):
            return text.isEmpty ? [] : [text]
        case .parts(let parts):
            return parts.compactMap { $0.text }.filter { !$0.isEmpty }
        }
    }

    private static func anthropicImageBlock(from dataURL: String) -> AnthropicBlock? {
        guard dataURL.hasPrefix("data:"),
              let comma = dataURL.firstIndex(of: ",") else {
            return nil
        }

        let headerStart = dataURL.index(dataURL.startIndex, offsetBy: 5)
        let header = String(dataURL[headerStart..<comma])
        guard header.hasSuffix(";base64") else { return nil }

        let mediaType = String(header.dropLast(";base64".count))
        let base64 = String(dataURL[dataURL.index(after: comma)...])
        guard !base64.isEmpty else { return nil }

        return .image(
            mediaType: mediaType.isEmpty ? "image/jpeg" : mediaType,
            base64: base64
        )
    }

    // MARK: - Helpers

    private static func serverMessage(from raw: String) -> String {
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = cleaned.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return String(cleaned.prefix(320))
        }

        if let error = json["error"] as? [String: Any],
           let message = error["message"] as? String, !message.isEmpty {
            return String(message.prefix(320))
        }
        if let message = json["message"] as? String, !message.isEmpty {
            return String(message.prefix(320))
        }
        return String(cleaned.prefix(320))
    }

    private static func message(for error: URLError, provider: AIProvider) -> String {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost:
            return "You're offline. Check your internet connection and try again."
        case .timedOut:
            return "The request timed out. The model may be busy — try again."
        case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            return "Can't reach \(provider.displayName) right now. Check your connection and try again."
        case .secureConnectionFailed, .serverCertificateUntrusted:
            return "A secure connection to \(provider.displayName) couldn't be established."
        default:
            return error.localizedDescription
        }
    }
}
