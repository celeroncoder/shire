import Database from "better-sqlite3";
import { drizzle, type BetterSQLite3Database } from "drizzle-orm/better-sqlite3";
import { migrate } from "drizzle-orm/better-sqlite3/migrator";
import path from "node:path";
import { fileURLToPath } from "node:url";
import * as schema from "./schema.js";

export type ShireDatabase = BetterSQLite3Database<typeof schema>;

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const migrationsFolder = path.join(__dirname, "migrations");

export function createDatabase(dbPath: string): ShireDatabase {
  const sqlite = new Database(dbPath);

  sqlite.pragma("journal_mode = WAL");
  sqlite.pragma("foreign_keys = ON");

  const db = drizzle(sqlite, { schema });

  migrate(db, { migrationsFolder });

  return db;
}

export * from "./schema.js";
export { schema };
