import Foundation

/// Streams the text of a reply, piece by piece.
public protocol LLMProvider: Sendable {
    /// Identifies the provider and model, so cached results are not mixed up.
    var cacheID: String { get }
    func stream(_ request: LLMRequest) -> AsyncThrowingStream<String, Error>
}

public enum ProviderError: LocalizedError, Equatable {
    case http(status: Int, message: String)
    case refused(String)
    case server(String)
    case unavailable(String)

    public var errorDescription: String? {
        switch self {
        case .http(let status, let message): return "The server answered \(status): \(message)"
        case .refused(let detail): return "The model declined this text. \(detail)"
        case .server(let message): return message
        case .unavailable(let reason): return reason
        }
    }
}

/// Runs `body` in a task and finishes the stream with its result; cancelling the consumer cancels the task.
func makeStream(
    _ body: @escaping @Sendable (AsyncThrowingStream<String, Error>.Continuation) async throws -> Void
) -> AsyncThrowingStream<String, Error> {
    AsyncThrowingStream { continuation in
        let task = Task {
            do {
                try await body(continuation)
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
        continuation.onTermination = { _ in task.cancel() }
    }
}

/// Reads a server-sent events body line by line and passes each `data:` payload to `handle`.
/// `handle` returns false to stop reading.
func readEvents(
    _ request: URLRequest, session: URLSession,
    handle: (String) throws -> Bool
) async throws {
    let (bytes, response) = try await session.bytes(for: request)
    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
    guard status == 200 else {
        var body = ""
        for try await line in bytes.lines {
            body += line
            if body.count > 2000 { break }
        }
        throw ProviderError.http(status: status, message: errorMessage(fromBody: body))
    }
    for try await line in bytes.lines {
        try Task.checkCancellation()
        guard line.hasPrefix("data:") else { continue }
        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
        if try !handle(payload) { return }
    }
}

/// The `message` of an error body from either API, or the body itself.
func errorMessage(fromBody body: String) -> String {
    if let data = body.data(using: .utf8),
       let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
       let error = object["error"] as? [String: Any],
       let message = error["message"] as? String {
        return message
    }
    return body.isEmpty ? "No details." : String(body.prefix(300))
}

// MARK: - Anthropic

/// Claude through the Messages API, streamed. There is no official Swift SDK, so this is plain HTTP.
public struct AnthropicProvider: LLMProvider {
    public static let defaultModel = "claude-opus-5-5"
    public static let models: [(id: String, label: String)] = [
        ("claude-opus-5-5", "Claude Opus 5.5 — best"),
        ("claude-sonnet-5-5", "Claude Sonnet 5.5 — balanced"),
        ("claude-haiku-5-5", "Claude Haiku 5.5 — fastest"),
    ]

    public var apiKey: String
    public var model: String
    /// low for the chips; the agent will use more.
    public var effort: String
    public var endpoint: URL
    var session: URLSession

    public init(
        apiKey: String, model: String = defaultModel, effort: String = "low",
        endpoint: URL = URL(string: "https://api.anthropic.com/v1/messages")!
    ) {
        self.apiKey = apiKey
        self.model = model
        self.effort = effort
        self.endpoint = endpoint
        self.session = .shared
    }

    public var cacheID: String { "anthropic:\(model)" }

    /// Server-side refusal fallback is offered for these models.
    var usesFallbacks: Bool { model == "claude-opus-5-5" || model == "claude-sonnet-5-5" }

    public func urlRequest(for request: LLMRequest) throws -> URLRequest {
        var body: [String: Any] = [
            "model": model,
            "max_tokens": request.maxTokens,
            "stream": true,
            "system": request.system,
            "messages": [["role": "user", "content": request.prompt]],
            "output_config": ["effort": effort],
        ]
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        urlRequest.setValue("application/json", forHTTPHeaderField: "content-type")
        if usesFallbacks {
            body["fallbacks"] = "default"
            urlRequest.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
        }
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        urlRequest.timeoutInterval = 120
        return urlRequest
    }

    public func stream(_ request: LLMRequest) -> AsyncThrowingStream<String, Error> {
        let session = self.session
        let urlRequest: URLRequest
        do { urlRequest = try self.urlRequest(for: request) } catch {
            return AsyncThrowingStream { $0.finish(throwing: error) }
        }
        return makeStream { continuation in
            try await readEvents(urlRequest, session: session) { payload in
                switch try AnthropicEvents.parse(payload) {
                case .text(let text): continuation.yield(text)
                case .ignore: break
                case .stop: return false
                }
                return true
            }
        }
    }
}

/// Parses the `data:` payloads of a Messages API stream.
public enum AnthropicEvents {
    public enum Outcome: Equatable {
        case text(String)
        case ignore
        case stop
    }

    public static func parse(_ payload: String) throws -> Outcome {
        guard let data = payload.data(using: .utf8),
              let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = event["type"] as? String else { return .ignore }
        switch type {
        case "content_block_delta":
            // Only visible text; thinking deltas are skipped.
            if let delta = event["delta"] as? [String: Any],
               delta["type"] as? String == "text_delta",
               let text = delta["text"] as? String {
                return .text(text)
            }
            return .ignore
        case "message_delta":
            if let delta = event["delta"] as? [String: Any], delta["stop_reason"] as? String == "refusal" {
                let details = event["stop_details"] as? [String: Any] ?? delta["stop_details"] as? [String: Any]
                throw ProviderError.refused(details?["explanation"] as? String ?? "")
            }
            return .ignore
        case "message_stop":
            return .stop
        case "error":
            let error = event["error"] as? [String: Any]
            throw ProviderError.server(error?["message"] as? String ?? "The server reported an error.")
        default:
            return .ignore
        }
    }
}

// MARK: - OpenAI-compatible

/// Any server with an OpenAI-style /chat/completions endpoint: OpenRouter, DeepSeek, Ollama, LM Studio…
public struct OpenAICompatibleProvider: LLMProvider {
    public var baseURL: URL
    public var apiKey: String
    public var model: String
    var session: URLSession

    public init(baseURL: URL, apiKey: String, model: String) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.model = model
        self.session = .shared
    }

    public var cacheID: String { "openai:\(baseURL.absoluteString):\(model)" }

    public func urlRequest(for request: LLMRequest) throws -> URLRequest {
        let body: [String: Any] = [
            "model": model,
            "stream": true,
            "max_tokens": request.maxTokens,
            "messages": [
                ["role": "system", "content": request.system],
                ["role": "user", "content": request.prompt],
            ],
        ]
        var urlRequest = URLRequest(url: baseURL.appendingPathComponent("chat/completions"))
        urlRequest.httpMethod = "POST"
        if !apiKey.isEmpty { urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization") }
        urlRequest.setValue("application/json", forHTTPHeaderField: "content-type")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        urlRequest.timeoutInterval = 120
        return urlRequest
    }

    public func stream(_ request: LLMRequest) -> AsyncThrowingStream<String, Error> {
        let session = self.session
        let urlRequest: URLRequest
        do { urlRequest = try self.urlRequest(for: request) } catch {
            return AsyncThrowingStream { $0.finish(throwing: error) }
        }
        return makeStream { continuation in
            try await readEvents(urlRequest, session: session) { payload in
                switch try OpenAIEvents.parse(payload) {
                case .text(let text): continuation.yield(text)
                case .ignore: break
                case .stop: return false
                }
                return true
            }
        }
    }
}

public enum OpenAIEvents {
    public static func parse(_ payload: String) throws -> AnthropicEvents.Outcome {
        if payload == "[DONE]" { return .stop }
        guard let data = payload.data(using: .utf8),
              let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return .ignore }
        if let error = event["error"] as? [String: Any] {
            throw ProviderError.server(error["message"] as? String ?? "The server reported an error.")
        }
        guard let choices = event["choices"] as? [[String: Any]],
              let delta = choices.first?["delta"] as? [String: Any],
              let text = delta["content"] as? String, !text.isEmpty else { return .ignore }
        return .text(text)
    }
}

// MARK: - Demo

/// No network: answers with a fixed, recognisable text. Used by UI tests and the -demo launch argument.
public struct DemoProvider: LLMProvider {
    public var delay: Duration
    public init(delay: Duration = .milliseconds(40)) { self.delay = delay }

    public var cacheID: String { "demo" }

    public static func answer(for request: LLMRequest) -> String {
        "Demo · \(request.actionTitle) → \(request.outputLanguage.chipLabel)"
    }

    public func stream(_ request: LLMRequest) -> AsyncThrowingStream<String, Error> {
        let words = Self.answer(for: request).split(separator: " ", omittingEmptySubsequences: false)
        let delay = self.delay
        return makeStream { continuation in
            for (index, word) in words.enumerated() {
                try await Task.sleep(for: delay)
                continuation.yield(index == 0 ? String(word) : " " + word)
            }
        }
    }
}
