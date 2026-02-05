import { tool } from "ai";
import { z } from "zod";
import fs from "node:fs/promises";
import path from "node:path";
import { resolveSandboxed } from "./utils/sandbox.js";

const MAX_CONTENT_SIZE = 256 * 1024; // 256 KB

export function createWriteFileTool(workspaceRoot: string) {
  return tool({
    description:
      "Write content to a file. Creates parent directories if needed. Overwrites existing files.",
    parameters: z.object({
      path: z
        .string()
        .describe("Relative path to the file from workspace root"),
      content: z.string().describe("Content to write to the file"),
    }),
    execute: async ({ path: filePath, content }) => {
      if (Buffer.byteLength(content, "utf-8") > MAX_CONTENT_SIZE) {
        throw new Error(
          `Content too large (max ${MAX_CONTENT_SIZE} bytes).`
        );
      }

      const resolved = resolveSandboxed(workspaceRoot, filePath);

      await fs.mkdir(path.dirname(resolved), { recursive: true });
      await fs.writeFile(resolved, content, "utf-8");

      return { written: true, path: filePath };
    },
  });
}
