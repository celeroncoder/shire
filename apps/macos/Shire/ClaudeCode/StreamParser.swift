import Foundation

/// Parses newline-delimited JSON from Claude Code's stream-json output
final class StreamParser {

    private let decoder = JSONDecoder()

    struct ParsedLine {
        let type: String
        let raw: Data
    }

    /// Parse a single line of NDJSON into a StreamEvent
    func parseLine(_ line: String) -> StreamEvent? {
        guard !line.isEmpty else { return nil }
        guard let data = line.data(using: .utf8) else { return nil }

        // First, determine the type
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            return nil
        }

        switch type {
        case "system":
            if let event = try? decoder.decode(StreamEvent.SystemEvent.self, from: data) {
                return .system(event)
            }

        case "assistant":
            if let event = try? decoder.decode(StreamEvent.AssistantEvent.self, from: data) {
                return .assistant(event)
            }

        case "result":
            if let event = try? decoder.decode(StreamEvent.ResultEvent.self, from: data) {
                return .result(event)
            }

        default:
            // Unknown event type — could be stream_event or other
            // Try to extract text or thinking deltas from stream_event
            if let subType = json["event"] as? String {
                // Handle content_block_delta events
                if subType.contains("delta"),
                   let delta = json["delta"] as? [String: Any] {
                    // Text delta
                    if let text = delta["text"] as? String {
                        let content = StreamEvent.AssistantEvent.ContentBlock(
                            type: "text", text: text, thinking: nil, id: nil, name: nil, input: nil
                        )
                        let message = StreamEvent.AssistantEvent.AssistantMessage(
                            role: "assistant", content: [content]
                        )
                        let event = StreamEvent.AssistantEvent(type: "stream_delta", message: message)
                        return .assistant(event)
                    }
                    // Thinking delta
                    if let thinking = delta["thinking"] as? String {
                        let content = StreamEvent.AssistantEvent.ContentBlock(
                            type: "thinking", text: nil, thinking: thinking, id: nil, name: nil, input: nil
                        )
                        let message = StreamEvent.AssistantEvent.AssistantMessage(
                            role: "assistant", content: [content]
                        )
                        let event = StreamEvent.AssistantEvent(type: "stream_delta", message: message)
                        return .assistant(event)
                    }
                }
            }
        }

        return nil
    }

    /// Parse multiple lines (from a data chunk that may contain partial lines)
    func parseChunk(_ chunk: String) -> [StreamEvent] {
        let lines = chunk.split(separator: "\n", omittingEmptySubsequences: true)
        return lines.compactMap { parseLine(String($0)) }
    }
}
