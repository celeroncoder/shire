import Foundation
import GRDB

final class MessageRepository {
    static let shared = MessageRepository()

    private var dbPool: DatabasePool { DatabaseManager.shared.dbPool }

    private init() {}

    func listBySession(sessionId: String) -> [Message] {
        do {
            return try dbPool.read { db in
                try Message
                    .filter(Column("session_id") == sessionId)
                    .order(Column("order").asc)
                    .fetchAll(db)
            }
        } catch {
            print("Error listing messages: \(error)")
            return []
        }
    }

    @discardableResult
    func create(_ message: Message) -> Message {
        do {
            try dbPool.write { db in
                try message.insert(db)
            }
        } catch {
            print("Error creating message: \(error)")
        }
        return message
    }

    @discardableResult
    func createMany(_ messages: [Message]) -> [Message] {
        do {
            try dbPool.write { db in
                for msg in messages {
                    try msg.insert(db)
                }
            }
        } catch {
            print("Error creating messages: \(error)")
        }
        return messages
    }

    /// Update streaming content for a placeholder message (debounced partial saves)
    func updateStreamingContent(id: String, content: String?, thinkingContent: String?, toolCalls: String?) {
        do {
            try dbPool.write { db in
                try db.execute(
                    sql: """
                        UPDATE messages
                        SET content = ?, thinking_content = ?, tool_calls = ?
                        WHERE id = ?
                        """,
                    arguments: [content, thinkingContent, toolCalls, id]
                )
            }
        } catch {
            print("Error updating streaming content: \(error)")
        }
    }

    /// Finalize a placeholder message with final content and usage data
    func finalizeMessage(id: String, content: String?, thinkingContent: String?, toolCalls: String?, tokenCount: Int?, costUsd: Double?) {
        do {
            try dbPool.write { db in
                try db.execute(
                    sql: """
                        UPDATE messages
                        SET content = ?, thinking_content = ?, tool_calls = ?, token_count = ?, cost_usd = ?
                        WHERE id = ?
                        """,
                    arguments: [content, thinkingContent, toolCalls, tokenCount, costUsd, id]
                )
            }
        } catch {
            print("Error finalizing message: \(error)")
        }
    }

    /// Delete a message by ID (cleanup empty placeholders)
    func delete(id: String) {
        do {
            try dbPool.write { db in
                try db.execute(sql: "DELETE FROM messages WHERE id = ?", arguments: [id])
            }
        } catch {
            print("Error deleting message: \(error)")
        }
    }

    func getNextOrder(sessionId: String) -> Int {
        do {
            return try dbPool.read { db in
                let maxOrder = try Int.fetchOne(db, sql: """
                    SELECT MAX("order") FROM messages WHERE session_id = ?
                    """, arguments: [sessionId])
                return (maxOrder ?? -1) + 1
            }
        } catch {
            print("Error getting next order: \(error)")
            return 0
        }
    }

    func getTokenTotal(sessionId: String) -> Int {
        do {
            return try dbPool.read { db in
                let total = try Int.fetchOne(db, sql: """
                    SELECT COALESCE(SUM(token_count), 0) FROM messages WHERE session_id = ?
                    """, arguments: [sessionId])
                return total ?? 0
            }
        } catch {
            print("Error getting token total: \(error)")
            return 0
        }
    }
}
