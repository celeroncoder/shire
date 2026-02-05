import { createDatabase } from "./index.js";

const dbPath = process.argv[2] ?? ":memory:";

console.log(`Running migrations on: ${dbPath}`);
createDatabase(dbPath);
console.log("Migrations complete.");
