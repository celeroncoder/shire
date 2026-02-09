import type { BetterSQLite3Database } from "drizzle-orm/better-sqlite3";
import { asc, desc, eq, sql } from "drizzle-orm";
import * as schema from "./schema.js";
import {
  artifacts,
  messages,
  sessions,
  settings,
  workspaces,
} from "./schema.js";
import type {
  Artifact,
  CreateArtifactInput,
  CreateMessageInput,
  CreateSessionInput,
  CreateWorkspaceInput,
  Message,
  RenameSessionInput,
  Session,
  SettingsMap,
  UpdateWorkspaceInput,
  Workspace,
} from "./types.js";

type ShireDatabase = BetterSQLite3Database<typeof schema>;

function requireRow<T>(row: T | undefined, message: string): T {
  if (row === undefined) {
    throw new Error(message);
  }

  return row;
}

function mapMessageInput(input: CreateMessageInput) {
  return {
    sessionId: input.sessionId,
    role: input.role,
    order: input.order,
    content: input.content ?? null,
    toolCalls: input.toolCalls ?? null,
    toolCallId: input.toolCallId ?? null,
    tokenCount: input.tokenCount ?? null,
  };
}

export function createService(db: ShireDatabase) {
  return {
    workspace: {
      list(): Workspace[] {
        return db
          .select()
          .from(workspaces)
          .orderBy(desc(workspaces.updatedAt))
          .all();
      },

      getById(id: string): Workspace | undefined {
        return db
          .select()
          .from(workspaces)
          .where(eq(workspaces.id, id))
          .get();
      },

      create(input: CreateWorkspaceInput): Workspace {
        const row = db.insert(workspaces).values(input).returning().get();

        return requireRow(row, `Workspace not created for path ${input.path}`);
      },

      update(input: UpdateWorkspaceInput): Workspace {
        const row = db
          .update(workspaces)
          .set({ name: input.name, updatedAt: Date.now() })
          .where(eq(workspaces.id, input.id))
          .returning()
          .get();

        return requireRow(row, `Workspace ${input.id} not found`);
      },

      delete(id: string): void {
        db.delete(workspaces).where(eq(workspaces.id, id)).run();
      },
    },

    session: {
      listByWorkspace(workspaceId: string): Session[] {
        return db
          .select()
          .from(sessions)
          .where(eq(sessions.workspaceId, workspaceId))
          .orderBy(desc(sessions.updatedAt))
          .all();
      },

      getById(id: string): Session | undefined {
        return db.select().from(sessions).where(eq(sessions.id, id)).get();
      },

      create(input: CreateSessionInput): Session {
        const row = db
          .insert(sessions)
          .values({
            workspaceId: input.workspaceId,
            title: input.title ?? null,
          })
          .returning()
          .get();

        return requireRow(row, `Session not created for workspace ${input.workspaceId}`);
      },

      rename(input: RenameSessionInput): Session {
        const row = db
          .update(sessions)
          .set({ title: input.title, updatedAt: Date.now() })
          .where(eq(sessions.id, input.id))
          .returning()
          .get();

        return requireRow(row, `Session ${input.id} not found`);
      },

      touch(id: string): void {
        db.update(sessions).set({ updatedAt: Date.now() }).where(eq(sessions.id, id)).run();
      },

      delete(id: string): void {
        db.delete(sessions).where(eq(sessions.id, id)).run();
      },
    },

    message: {
      listBySession(sessionId: string): Message[] {
        return db
          .select()
          .from(messages)
          .where(eq(messages.sessionId, sessionId))
          .orderBy(asc(messages.order))
          .all();
      },

      create(input: CreateMessageInput): Message {
        const row = db
          .insert(messages)
          .values(mapMessageInput(input))
          .returning()
          .get();

        return requireRow(row, `Message not created for session ${input.sessionId}`);
      },

      createMany(inputs: CreateMessageInput[]): Message[] {
        if (inputs.length === 0) {
          return [];
        }

        return db.transaction((tx) => {
          return tx
            .insert(messages)
            .values(inputs.map(mapMessageInput))
            .returning()
            .all();
        });
      },

      getNextOrder(sessionId: string): number {
        const row = db
          .select({ maxOrder: sql<number>`max(${messages.order})` })
          .from(messages)
          .where(eq(messages.sessionId, sessionId))
          .get();

        const maxOrder = row?.maxOrder;

        return typeof maxOrder === "number" ? maxOrder + 1 : 0;
      },

      getTokenTotal(sessionId: string): number {
        const row = db
          .select({ total: sql<number>`coalesce(sum(${messages.tokenCount}), 0)` })
          .from(messages)
          .where(eq(messages.sessionId, sessionId))
          .get();

        return Number(row?.total ?? 0);
      },
    },

    artifact: {
      listBySession(sessionId: string): Artifact[] {
        return db
          .select()
          .from(artifacts)
          .where(eq(artifacts.sessionId, sessionId))
          .orderBy(asc(artifacts.createdAt))
          .all();
      },

      create(input: CreateArtifactInput): Artifact {
        const row = db.insert(artifacts).values(input).returning().get();

        return requireRow(row, `Artifact not created for session ${input.sessionId}`);
      },
    },

    settings: {
      getAll(): SettingsMap {
        const rows = db.select().from(settings).all();

        const result: SettingsMap = {};
        for (const row of rows) {
          result[row.key] = row.value;
        }

        return result;
      },

      get(key: string): string | null {
        const row = db
          .select({ value: settings.value })
          .from(settings)
          .where(eq(settings.key, key))
          .get();

        return row?.value ?? null;
      },

      set(key: string, value: string | null): void {
        db.insert(settings)
          .values({ key, value })
          .onConflictDoUpdate({
            target: settings.key,
            set: { value },
          })
          .run();
      },

      setMany(map: SettingsMap): void {
        const entries = Object.entries(map);
        if (entries.length === 0) {
          return;
        }

        db.transaction((tx) => {
          for (const [key, value] of entries) {
            tx.insert(settings)
              .values({ key, value })
              .onConflictDoUpdate({
                target: settings.key,
                set: { value },
              })
              .run();
          }
        });
      },
    },
  };
}

export type ShireService = ReturnType<typeof createService>;
