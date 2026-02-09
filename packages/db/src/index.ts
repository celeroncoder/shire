import Database from "better-sqlite3";
import { drizzle, type BetterSQLite3Database } from "drizzle-orm/better-sqlite3";
import { migrate } from "drizzle-orm/better-sqlite3/migrator";
import * as schema from "./schema.js";

export type ShireDatabase = BetterSQLite3Database<typeof schema>;

export function createDatabase(
  dbPath: string,
  migrationsFolder: string
): ShireDatabase {
  const sqlite = new Database(dbPath);

  sqlite.pragma("journal_mode = WAL");
  sqlite.pragma("foreign_keys = ON");

  const db = drizzle(sqlite, { schema });

  migrate(db, { migrationsFolder });

  return db;
}

export * from "./schema.js";
export { schema };
export { createService } from "./service.js";
export type { ShireService } from "./service.js";
export * from "./types.js";
