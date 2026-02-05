import { createGlobTool } from "./glob.js";
import { createRipgrepTool } from "./ripgrep.js";
import { createReadFileTool } from "./read-file.js";
import { createWriteFileTool } from "./write-file.js";
import { createListDirTool } from "./list-dir.js";

export function createTools(workspaceRoot: string) {
  return {
    glob: createGlobTool(workspaceRoot),
    ripgrep: createRipgrepTool(workspaceRoot),
    read_file: createReadFileTool(workspaceRoot),
    write_file: createWriteFileTool(workspaceRoot),
    list_dir: createListDirTool(workspaceRoot),
  };
}

export { createGlobTool } from "./glob.js";
export { createRipgrepTool } from "./ripgrep.js";
export { createReadFileTool } from "./read-file.js";
export { createWriteFileTool } from "./write-file.js";
export { createListDirTool } from "./list-dir.js";
export { resolveSandboxed } from "./utils/sandbox.js";
export { isBinary } from "./utils/binary.js";
