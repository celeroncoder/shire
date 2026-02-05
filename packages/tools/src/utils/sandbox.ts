import path from "node:path";

export function resolveSandboxed(
  workspaceRoot: string,
  relativePath: string
): string {
  const root = path.resolve(workspaceRoot);
  const resolved = path.resolve(root, relativePath);

  if (resolved !== root && !resolved.startsWith(root + path.sep)) {
    throw new Error(
      `Path traversal detected: "${relativePath}" resolves outside workspace`
    );
  }

  return resolved;
}
