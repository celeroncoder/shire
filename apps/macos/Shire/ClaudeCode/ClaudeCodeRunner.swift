import Foundation

final class ClaudeCodeRunner {
    static let shared = ClaudeCodeRunner()

    private init() {}

    /// Search order for the claude binary:
    /// 1. UserDefaults override (Settings > Advanced > Claude Code path)
    /// 2. /opt/homebrew/bin/claude (Apple Silicon Homebrew)
    /// 3. /usr/local/bin/claude (Intel Homebrew)
    /// 4. `which claude` via Process (general PATH lookup)
    /// 5. Not found → nil
    func findBinary() -> String? {
        // 1. User override
        if let override = SettingsRepository.shared.get(key: "claude_path"),
           !override.isEmpty,
           FileManager.default.isExecutableFile(atPath: override) {
            return override
        }

        // 2. Apple Silicon Homebrew
        let homebrewSilicon = "/opt/homebrew/bin/claude"
        if FileManager.default.isExecutableFile(atPath: homebrewSilicon) {
            return homebrewSilicon
        }

        // 3. Intel Homebrew
        let homebrewIntel = "/usr/local/bin/claude"
        if FileManager.default.isExecutableFile(atPath: homebrewIntel) {
            return homebrewIntel
        }

        // 4. PATH lookup via `which`
        if let pathResult = runWhich() {
            return pathResult
        }

        return nil
    }

    private func runWhich() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["claude"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                if let path = path, !path.isEmpty, FileManager.default.isExecutableFile(atPath: path) {
                    return path
                }
            }
        } catch {
            // Silently fail
        }

        return nil
    }
}
