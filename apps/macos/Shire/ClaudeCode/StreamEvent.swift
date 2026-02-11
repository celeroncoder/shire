import Foundation

/// Claude Code stream-json event types
enum StreamEvent {
    case system(SystemEvent)
    case assistant(AssistantEvent)
    case result(ResultEvent)

    struct SystemEvent: Codable {
        let type: String
        let sessionId: String?
        let model: String?
        let tools: [ToolInfo]?

        enum CodingKeys: String, CodingKey {
            case type
            case sessionId = "session_id"
            case model, tools
        }

        struct ToolInfo: Codable {
            let name: String
            let description: String?
        }
    }

    struct AssistantEvent: Codable {
        let type: String
        let message: AssistantMessage

        struct AssistantMessage: Codable {
            let role: String
            let content: [ContentBlock]
        }

        struct ContentBlock: Codable {
            let type: String
            let text: String?
            let thinking: String?
            let id: String?
            let name: String?
            let input: AnyCodable?

            enum CodingKeys: String, CodingKey {
                case type, text, thinking, id, name, input
            }
        }
    }

    struct ResultEvent: Codable {
        let type: String
        let sessionId: String?
        let costUsd: Double?
        let durationMs: Int?
        let usage: Usage?
        let result: String?

        enum CodingKeys: String, CodingKey {
            case type
            case sessionId = "session_id"
            case costUsd = "cost_usd"
            case durationMs = "duration_ms"
            case usage, result
        }

        struct Usage: Codable {
            let inputTokens: Int?
            let outputTokens: Int?

            enum CodingKeys: String, CodingKey {
                case inputTokens = "input_tokens"
                case outputTokens = "output_tokens"
            }
        }
    }
}

/// Type-erased Codable wrapper for arbitrary JSON
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode AnyCodable")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: [], debugDescription: "Cannot encode AnyCodable"))
        }
    }
}
