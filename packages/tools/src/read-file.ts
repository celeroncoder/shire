import { tool } from "ai";
import { z } from "zod";
import fs from "node:fs/promises";
import { resolveSandboxed } from "./utils/sandbox.js";
import { isBinary } from "./utils/binary.js";

const MAX_SIZE = 512 * 1024; // 512 KB

export function createReadFileTool(workspaceRoot: string) {
  return tool({
    description:
      "Read the contents of a file. Supports optional line range. Refuses binary files.",
    parameters: z.object({
      path: z.string().describe("Relative path to the file from workspace root"),
      startLine: z
        .number()
        .optional()
        .describe("1-based start line (inclusive)"),
      endLine: z
        .number()
        .optional()
        .describe("1-based end line (inclusive)"),
    }),
    execute: async ({ path: filePath, startLine, endLine }) => {
      const resolved = resolveSandboxed(workspaceRoot, filePath);

      const stat = await fs.stat(resolved);
      if (stat.size > MAX_SIZE) {
        throw new Error(
          `File too large: ${stat.size} bytes (max ${MAX_SIZE} bytes). Use line range to read a portion.`
        );
      }

      if (await isBinary(resolved)) {
        throw new Error("Cannot read binary file.");
      }

      const raw = await fs.readFile(resolved, "utf-8");
      let lines = raw.split("\n");

      if (startLine !== undefined || endLine !== undefined) {
        const start = (startLine ?? 1) - 1;
        const end = endLine ?? lines.length;
        lines = lines.slice(start, end);
      }

      return {
        content: lines.join("\n"),
        lines: lines.length,
      };
    },
  });
}
