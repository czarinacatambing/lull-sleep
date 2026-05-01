import Foundation

// Streams a boring story from the Claude API using server-sent events.
@MainActor
class ClaudeAPIService: ObservableObject {

    enum State: Equatable {
        case idle
        case loading          // waiting for first token
        case streaming        // tokens arriving
        case done
        case error(String)
    }

    @Published var state: State = .idle
    @Published var fullText = ""

    private var streamTask: Task<Void, Never>?

    // The prompt from PRD Appendix A
    static let storyPrompt = """
        Write a slow, meandering, descriptive passage about an ordinary place at night. \
        Use long unhurried sentences. Include specific but unimportant details. \
        Avoid narrative tension, conflict, characters with goals, or anything that creates anticipation. \
        Begin mid-thought as if the story has already been going for a while. \
        Write at least 500 words and keep going.
        """

    func generate(apiKey: String, onChunk: @escaping (String) -> Void) {
        streamTask?.cancel()
        fullText = ""
        state = .loading

        streamTask = Task {
            do {
                var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
                req.httpMethod = "POST"
                req.setValue(apiKey,       forHTTPHeaderField: "x-api-key")
                req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")

                let body: [String: Any] = [
                    "model": "claude-opus-4-7",
                    "max_tokens": 2048,
                    "stream": true,
                    "messages": [["role": "user", "content": Self.storyPrompt]],
                ]
                req.httpBody = try JSONSerialization.data(withJSONObject: body)

                let (bytes, response) = try await URLSession.shared.bytes(for: req)

                if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                    state = .error("API returned \(http.statusCode). Check your API key.")
                    return
                }

                state = .streaming

                for try await line in bytes.lines {
                    if Task.isCancelled { break }
                    guard line.hasPrefix("data: ") else { continue }
                    let payload = String(line.dropFirst(6))
                    if payload == "[DONE]" { break }

                    guard
                        let data  = payload.data(using: .utf8),
                        let chunk = try? JSONDecoder().decode(SSEChunk.self, from: data),
                        chunk.type == "content_block_delta",
                        let text  = chunk.delta?.text,
                        !text.isEmpty
                    else { continue }

                    fullText += text
                    onChunk(text)
                }

                if !Task.isCancelled { state = .done }

            } catch is CancellationError {
                // deliberate cancel — leave state alone

            } catch {
                state = .error(error.localizedDescription)
            }
        }
    }

    func cancel() {
        streamTask?.cancel()
        state = .idle
    }
}

// MARK: - SSE decoding

private struct SSEChunk: Decodable {
    let type: String
    let delta: Delta?

    struct Delta: Decodable {
        let type: String?
        let text: String?
    }
}
