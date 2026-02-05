import { tool } from "ai";
import { z } from "zod";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import path from "node:path";
import { rgPath } from "@vscode/ripgrep";

const execFileAsync = promisify(execFile);

export interface RgMatch {
  file: string;
  line: number;
  content: string;
}

function getRgPath(): string {
  // In packaged Electron app, resolve from extraResources
  const resourcesPath = (process as unknown as Record<string, unknown>).resourcesPath;
  if (typeof resourcesPath === "string") {
    return path.join(resourcesPath, "ripgrep-bin", "rg");
  }
  return rgPath;
}

export function createRipgrepTool(workspaceRoot: string) {
  return tool({
    description:
      "Search file contents using ripgrep. Returns matching lines with file paths and line numbers.",
    parameters: z.object({
      pattern: z.string().describe("Search pattern (regex supported)"),
      glob: z
        .string()
        .optional()
        .describe("Optional file glob filter (e.g. '*.ts')"),
      maxResults: z
        .number()
        .optional()
        .default(100)
        .describe("Maximum number of matches to return"),
    }),
    execute: async ({ pattern, glob, maxResults }) => {
      const args = ["--json", "--max-count", String(maxResults)];

      if (glob) {
        args.push("--glob", glob);
      }

      args.push("--", pattern, ".");

      try {
        const { stdout } = await execFileAsync(getRgPath(), args, {
          cwd: workspaceRoot,
          maxBuffer: 10 * 1024 * 1024,
        });

        const matches: RgMatch[] = [];

        for (const line of stdout.split("\n")) {
          if (!line.trim()) continue;

          try {
            const parsed = JSON.parse(line);
            if (parsed.type === "match") {
              matches.push({
                file: parsed.data.path.text,
                line: parsed.data.line_number,
                content: parsed.data.lines.text.trimEnd(),
              });
            }
          } catch {
            // skip malformed JSON lines
          }
        }

        return { matches };
      } catch (error: unknown) {
        const err = error as { code?: number; stderr?: string };
        // Exit code 1 means no matches found — not an error
        if (err.code === 1) {
          return { matches: [] };
        }
        throw new Error(`ripgrep failed: ${err.stderr ?? "unknown error"}`);
      }
    },
  });
}
