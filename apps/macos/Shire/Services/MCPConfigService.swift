import Foundation

/// Represents a configured MCP server
struct MCPServerConfig {
    let name: String
    let command: String
    let args: [String]
    let env: [String: String]
    let source: String // "global" or "project"
}

/// Reads MCP server configurations from Claude Code config files
final class MCPConfigService {
    static let shared = MCPConfigService()

    private init() {}

    /// Read all configured MCP servers from known config locations
    func loadServers() -> [MCPServerConfig] {
        var servers: [MCPServerConfig] = []

        // 1. Global config: ~/.claude.json
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let globalConfigPath = "\(home)/.claude.json"
        servers.append(contentsOf: parseConfigFile(at: globalConfigPath, source: "global"))

        // 2. Alternative: ~/.claude/settings.json
        let settingsPath = "\(home)/.claude/settings.json"
        let settingsServers = parseConfigFile(at: settingsPath, source: "global")
        // Only add if not already found from .claude.json
        for server in settingsServers {
            if !servers.contains(where: { $0.name == server.name }) {
                servers.append(server)
            }
        }

        return servers
    }

    /// Read MCP servers from a specific project path
    func loadProjectServers(workspacePath: String) -> [MCPServerConfig] {
        let mcpJsonPath = "\(workspacePath)/.mcp.json"
        return parseConfigFile(at: mcpJsonPath, source: "project")
    }

    private func parseConfigFile(at path: String, source: String) -> [MCPServerConfig] {
        guard FileManager.default.fileExists(atPath: path),
              let data = FileManager.default.contents(atPath: path) else {
            return []
        }

        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let mcpServers = json["mcpServers"] as? [String: Any] else {
                return []
            }

            var servers: [MCPServerConfig] = []
            for (name, value) in mcpServers {
                guard let config = value as? [String: Any] else { continue }
                let command = config["command"] as? String ?? ""
                let args = config["args"] as? [String] ?? []
                let env = config["env"] as? [String: String] ?? [:]
                servers.append(MCPServerConfig(
                    name: name,
                    command: command,
                    args: args,
                    env: env,
                    source: source
                ))
            }
            return servers.sorted { $0.name < $1.name }
        } catch {
            return []
        }
    }
}
