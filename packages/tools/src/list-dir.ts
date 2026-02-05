import { tool } from "ai";
import { z } from "zod";
import fs from "node:fs/promises";
import path from "node:path";
import { resolveSandboxed } from "./utils/sandbox.js";

const IGNORED = new Set([".git", "node_modules"]);

export function createListDirTool(workspaceRoot: string) {
  return tool({
    description:
      "List the contents of a directory. Returns names, types, and sizes.",
    parameters: z.object({
      path: z
        .string()
        .optional()
        .default(".")
        .describe("Relative path to directory from workspace root"),
    }),
    execute: async ({ path: dirPath }) => {
      const resolved = resolveSandboxed(workspaceRoot, dirPath);

      const dirents = await fs.readdir(resolved, { withFileTypes: true });

      const entries = await Promise.all(
        dirents
          .filter((d) => !IGNORED.has(d.name))
          .map(async (d) => {
            const fullPath = path.join(resolved, d.name);
            let size = 0;
            if (d.isFile()) {
              const stat = await fs.stat(fullPath);
              size = stat.size;
            }
            return {
              name: d.name,
              type: d.isDirectory() ? "directory" : "file",
              size,
            };
          })
      );

      return {
        entries: entries.sort((a, b) => {
          // Directories first, then alphabetical
          if (a.type !== b.type) return a.type === "directory" ? -1 : 1;
          return a.name.localeCompare(b.name);
        }),
      };
    },
  });
}
