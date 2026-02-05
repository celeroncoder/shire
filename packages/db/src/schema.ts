import { sqliteTable, text, integer, index } from "drizzle-orm/sqlite-core";
import { uuidv7 } from "uuidv7";

export const workspaces = sqliteTable("workspaces", {
  id: text("id")
    .primaryKey()
    .$defaultFn(() => uuidv7()),
  name: text("name").notNull(),
  path: text("path").notNull().unique(),
  createdAt: integer("created_at", { mode: "number" })
    .notNull()
    .$defaultFn(() => Date.now()),
  updatedAt: integer("updated_at", { mode: "number" })
    .notNull()
    .$defaultFn(() => Date.now()),
});

export const sessions = sqliteTable(
  "sessions",
  {
    id: text("id")
      .primaryKey()
      .$defaultFn(() => uuidv7()),
    workspaceId: text("workspace_id")
      .notNull()
      .references(() => workspaces.id, { onDelete: "cascade" }),
    title: text("title"),
    createdAt: integer("created_at", { mode: "number" })
      .notNull()
      .$defaultFn(() => Date.now()),
    updatedAt: integer("updated_at", { mode: "number" })
      .notNull()
      .$defaultFn(() => Date.now()),
  },
  (table) => [
    index("idx_sessions_workspace").on(table.workspaceId, table.updatedAt),
  ]
);

export const messages = sqliteTable(
  "messages",
  {
    id: text("id")
      .primaryKey()
      .$defaultFn(() => uuidv7()),
    sessionId: text("session_id")
      .notNull()
      .references(() => sessions.id, { onDelete: "cascade" }),
    role: text("role").notNull(),
    content: text("content"),
    toolCalls: text("tool_calls"),
    toolCallId: text("tool_call_id"),
    tokenCount: integer("token_count"),
    createdAt: integer("created_at", { mode: "number" })
      .notNull()
      .$defaultFn(() => Date.now()),
    order: integer("order").notNull(),
  },
  (table) => [
    index("idx_messages_session").on(table.sessionId, table.order),
  ]
);

export const artifacts = sqliteTable(
  "artifacts",
  {
    id: text("id")
      .primaryKey()
      .$defaultFn(() => uuidv7()),
    sessionId: text("session_id")
      .notNull()
      .references(() => sessions.id, { onDelete: "cascade" }),
    messageId: text("message_id")
      .notNull()
      .references(() => messages.id, { onDelete: "cascade" }),
    filePath: text("file_path").notNull(),
    operation: text("operation").notNull(),
    createdAt: integer("created_at", { mode: "number" })
      .notNull()
      .$defaultFn(() => Date.now()),
  },
  (table) => [index("idx_artifacts_session").on(table.sessionId)]
);

export const settings = sqliteTable("settings", {
  key: text("key").primaryKey(),
  value: text("value"),
});
