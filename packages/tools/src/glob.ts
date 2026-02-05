import { tool } from "ai";
import { z } from "zod";
import fg from "fast-glob";

export function createGlobTool(workspaceRoot: string) {
  return tool({
    description:
      "Find files matching a glob pattern within the workspace. Returns relative paths.",
    parameters: z.object({
      pattern: z
        .string()
        .describe("Glob pattern to match (e.g. '**/*.ts', 'src/**/*.tsx')"),
    }),
    execute: async ({ pattern }) => {
      const files = await fg(pattern, {
        cwd: workspaceRoot,
        ignore: ["**/node_modules/**", "**/.git/**"],
        dot: false,
        onlyFiles: true,
      });

      return { files: files.sort() };
    },
  });
}
