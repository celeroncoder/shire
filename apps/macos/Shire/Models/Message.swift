import Foundation
import GRDB

struct Message: Codable, FetchableRecord, PersistableRecord, Hashable {
    static let databaseTableName = "messages"

    var id: String
    var sessionId: String
    var role: String         // "user" | "assistant" | "tool"
    var content: String?
    var thinkingContent: String?
    var toolCalls: String?   // JSON: [{ id, name, arguments }]
    var toolCallId: String?
    var tokenCount: Int?
    var costUsd: Double?
    var createdAt: Int64
    var order: Int

    enum CodingKeys: String, CodingKey {
        case id, role, content, order
        case sessionId = "session_id"
        case thinkingContent = "thinking_content"
        case toolCalls = "tool_calls"
        case toolCallId = "tool_call_id"
        case tokenCount = "token_count"
        case costUsd = "cost_usd"
        case createdAt = "created_at"
    }

    init(id: String = UUIDv7.generate(), sessionId: String, role: String, content: String? = nil,
         thinkingContent: String? = nil, toolCalls: String? = nil, toolCallId: String? = nil,
         tokenCount: Int? = nil, costUsd: Double? = nil, order: Int) {
        self.id = id
        self.sessionId = sessionId
        self.role = role
        self.content = content
        self.thinkingContent = thinkingContent
        self.toolCalls = toolCalls
        self.toolCallId = toolCallId
        self.tokenCount = tokenCount
        self.costUsd = costUsd
        self.createdAt = Int64(Date().timeIntervalSince1970 * 1000)
        self.order = order
    }
}
