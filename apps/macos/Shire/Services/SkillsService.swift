import Foundation

/// Represents a Claude Code custom command/skill
struct SkillInfo {
    let name: String
    let description: String
    let filePath: String
    let source: String // "user" or "project"
}

/// Reads skills/custom commands from Claude Code configuration
final class SkillsService {
    static let shared = SkillsService()

    private init() {}

    /// Load all skills from user-level commands directory
    func loadUserSkills() -> [SkillInfo] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let commandsDir = "\(home)/.claude/commands"
        return loadSkills(from: commandsDir, source: "user")
    }

    /// Load project-level skills from a workspace
    func loadProjectSkills(workspacePath: String) -> [SkillInfo] {
        let commandsDir = "\(workspacePath)/.claude/commands"
        return loadSkills(from: commandsDir, source: "project")
    }

    private func loadSkills(from directory: String, source: String) -> [SkillInfo] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: directory) else { return [] }

        do {
            let files = try fm.contentsOfDirectory(atPath: directory)
            var skills: [SkillInfo] = []

            for file in files where file.hasSuffix(".md") {
                let filePath = "\(directory)/\(file)"
                let name = String(file.dropLast(3)) // Remove .md
                let description = readFirstLine(at: filePath)

                skills.append(SkillInfo(
                    name: name,
                    description: description,
                    filePath: filePath,
                    source: source
                ))
            }

            return skills.sorted { $0.name < $1.name }
        } catch {
            return []
        }
    }

    private func readFirstLine(at path: String) -> String {
        guard let data = FileManager.default.contents(atPath: path),
              let content = String(data: data, encoding: .utf8) else {
            return "No description"
        }

        // Get the first non-empty, non-heading line as description
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            // Strip markdown heading prefix
            if trimmed.hasPrefix("#") {
                let stripped = trimmed.drop(while: { $0 == "#" || $0 == " " })
                if !stripped.isEmpty { return String(stripped) }
                continue
            }
            return String(trimmed.prefix(120))
        }
        return "No description"
    }
}
