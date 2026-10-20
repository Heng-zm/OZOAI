import Foundation

// MARK: - Wire types

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

    let choices: [Choice]
}

// MARK: - Errors

enum OpenCodeError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case emptyResponse
    case http(status: Int, message: String)
    case network(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Add your OpenCode API key in Settings to start chatting."
        case .invalidResponse:
            return "OZO AI couldn't read the model response. Please try again."
        case .emptyResponse:
            return "The model returned an empty response. Try again or pick another model."
        case .http(let status, let message):
            switch status {
            case 401:
                return "That API key wasn't accepted. Update it in Settings."
            case 402:
                return "This model needs credits on your OpenCode account. Free models should work without credits — try another free model."
            case 403:
                return "Access was denied. Check your API key and that this model is available in your region."
            case 404:
                return "That model isn't available right now. Pick another model."
            case 429:
                return "Too many requests. Wait a few seconds, then try again."
            case 500...599:
                return "The model service is having trouble right now. Please try again shortly."
            default:
                return message.isEmpty ? "Request failed (HTTP \(status))." : message
            }
        case .network(let message):
            return message
        }
    }
}

// MARK: - Client

final class OpenCodeClient {
    static let shared = OpenCodeClient()

    private let endpoint = URL(string: "https://opencode.ai/inference/openai/v1/chat/completions")!
    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 120
        configuration.timeoutIntervalForResource = 900
        configuration.waitsForConnectivity = true
        session = URLSession(configuration: configuration)
    }

    /// Streams an OpenAI-compatible server-sent-events response.
    func streamChat(
        apiKey: String,
        modelID: String,
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
                    let request = try makeRequest(
                        apiKey: apiKey,
                        body: body,
                        accept: "text/event-stream",
                        timeout: 300
                    )

                    let (bytes, response) = try await session.bytes(for: request)

                    guard let http = response as? HTTPURLResponse else {
                        throw OpenCodeError.invalidResponse
                    }

                    guard (200..<300).contains(http.statusCode) else {
                        var errorBody = ""
                        for try await line in bytes.lines {
                            errorBody += line
                            if errorBody.count > 2_000 { break }
                        }
                        throw OpenCodeError.http(
                            status: http.statusCode,
                            message: Self.serverMessage(from: errorBody)
                        )
                    }

                    for try await line in bytes.lines {
                        if Task.isCancelled { break }

                        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard trimmed.hasPrefix("data:") else { continue }

                        var payload = String(trimmed.dropFirst(5))
                        if payload.hasPrefix(" ") { payload.removeFirst() }
                        if payload.isEmpty { continue }
                        if payload == "[DONE]" { break }

                        guard let data = payload.data(using: .utf8),
                              let envelope = try? JSONDecoder().decode(StreamEnvelope.self, from: data),
                              let choice = envelope.choices.first else {
                            continue
                        }

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
                        throw OpenCodeError.emptyResponse
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch let error as URLError where error.code == .cancelled {
                    continuation.finish()
                } catch let error as URLError {
                    continuation.finish(throwing: OpenCodeError.network(Self.message(for: error)))
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    /// Sends a tiny request to verify that an API key works.
    func validate(apiKey: String) async throws {
        let body = ChatRequest(
            model: AIModel.defaultID,
            messages: [WireMessage(role: "user", content: .text("Reply with OK."))],
            stream: false,
            temperature: 0.2,
            max_tokens: 4
        )
        let request = try makeRequest(
            apiKey: apiKey,
            body: body,
            accept: "application/json",
            timeout: 45
        )

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw OpenCodeError.invalidResponse
            }
            guard (200..<300).contains(http.statusCode) else {
                let raw = String(data: data, encoding: .utf8) ?? ""
                throw OpenCodeError.http(status: http.statusCode, message: Self.serverMessage(from: raw))
            }
        } catch let error as URLError {
            throw OpenCodeError.network(Self.message(for: error))
        }
    }

    // MARK: - Helpers

    private func makeRequest(
        apiKey: String,
        body: ChatRequest,
        accept: String,
        timeout: TimeInterval
    ) throws -> URLRequest {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw OpenCodeError.missingAPIKey }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(accept, forHTTPHeaderField: "Accept")
        request.setValue("OZO-AI-iOS/1.0", forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

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

    private static func message(for error: URLError) -> String {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost:
            return "You're offline. Check your internet connection and try again."
        case .timedOut:
            return "The request timed out. The model may be busy — try again."
        case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            return "Can't reach OpenCode right now. Check your connection and try again."
        case .secureConnectionFailed, .serverCertificateUntrusted:
            return "A secure connection to OpenCode couldn't be established."
        default:
            return error.localizedDescription
        }
    }
}
