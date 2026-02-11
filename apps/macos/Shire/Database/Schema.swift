import GRDB

enum Schema {
    static func createInitialSchema(_ db: Database) throws {
        // Workspaces
        try db.create(table: "workspaces") { t in
            t.column("id", .text).primaryKey()
            t.column("name", .text).notNull()
            t.column("path", .text).notNull().unique()
            t.column("created_at", .integer).notNull()
            t.column("updated_at", .integer).notNull()
        }

        // Sessions
        try db.create(table: "sessions") { t in
            t.column("id", .text).primaryKey()
            t.column("workspace_id", .text).notNull()
                .references("workspaces", onDelete: .cascade)
            t.column("claude_session_id", .text)
            t.column("title", .text)
            t.column("created_at", .integer).notNull()
            t.column("updated_at", .integer).notNull()
        }
        try db.create(index: "idx_sessions_workspace", on: "sessions", columns: ["workspace_id", "updated_at"])

        // Messages
        try db.create(table: "messages") { t in
            t.column("id", .text).primaryKey()
            t.column("session_id", .text).notNull()
                .references("sessions", onDelete: .cascade)
            t.column("role", .text).notNull()
            t.column("content", .text)
            t.column("thinking_content", .text)
            t.column("tool_calls", .text)
            t.column("tool_call_id", .text)
            t.column("token_count", .integer)
            t.column("cost_usd", .double)
            t.column("created_at", .integer).notNull()
            t.column("order", .integer).notNull()
        }
        try db.create(index: "idx_messages_session", on: "messages", columns: ["session_id", "order"])

        // Artifacts
        try db.create(table: "artifacts") { t in
            t.column("id", .text).primaryKey()
            t.column("session_id", .text).notNull()
                .references("sessions", onDelete: .cascade)
            t.column("message_id", .text).notNull()
                .references("messages", onDelete: .cascade)
            t.column("file_path", .text).notNull()
            t.column("operation", .text).notNull()
            t.column("created_at", .integer).notNull()
        }
        try db.create(index: "idx_artifacts_session", on: "artifacts", columns: ["session_id"])

        // Settings
        try db.create(table: "settings") { t in
            t.column("key", .text).primaryKey()
            t.column("value", .text)
        }
    }
}
