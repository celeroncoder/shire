import Foundation

/// Manages a single Claude Code subprocess session
final class ClaudeCodeSession {

    private var process: Process?
    private let parser = StreamParser()
    private var buffer = ""
    private var resultReceived = false
    private(set) var isSuspended = false

    var onTextDelta: ((String) -> Void)?
    var onThinkingDelta: ((String) -> Void)?
    var onToolCall: (([String: Any]) -> Void)?
    var onToolResult: (([String: Any]) -> Void)?
    var onAssistantMessage: ((String, String?) -> Void)? // (text, toolCallsJSON)
    var onResult: ((StreamEvent.ResultEvent) -> Void)?
    var onError: ((String) -> Void)?
    var onProcessExit: (() -> Void)?

    /// Send a message to Claude Code via subprocess
    func send(
        message: String,
        workspacePath: String,
        claudeSessionId: String?,
        model: String,
        maxBudget: String?,
        systemPrompt: String?,
        permissionMode: PermissionMode = .acceptEdits
    ) {
        // Find binary
        guard let binaryPath = ClaudeCodeRunner.shared.findBinary() else {
            onError?("Claude Code not found. Install via: brew install claude-code")
            return
        }

        // Build arguments
        var arguments = [
            "--print",
            "--output-format", "stream-json",
            "--verbose",
            "--model", model,
        ]

        // Permission mode
        arguments.append(contentsOf: ["--permission-mode", permissionMode.rawValue])

        // Resume existing session
        if let sessionId = claudeSessionId {
            arguments.append(contentsOf: ["--resume", sessionId])
        }

        // Max budget
        if let budget = maxBudget, !budget.isEmpty {
            arguments.append(contentsOf: ["--max-budget-usd", budget])
        }

        // System prompt
        if let prompt = systemPrompt, !prompt.isEmpty {
            arguments.append(contentsOf: ["--append-system-prompt", prompt])
        }

        // The message itself
        arguments.append(message)

        // Create process
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = arguments
        process.currentDirectoryURL = URL(fileURLWithPath: workspacePath)

        // Inherit environment (picks up API keys, PATH, etc.)
        process.environment = ProcessInfo.processInfo.environment

        // Stdout pipe for streaming JSON
        let stdoutPipe = Pipe()
        process.standardOutput = stdoutPipe

        // Stderr pipe for errors
        let stderrPipe = Pipe()
        process.standardError = stderrPipe

        self.process = process

        // Read stdout asynchronously
        let stdoutHandle = stdoutPipe.fileHandleForReading
        stdoutHandle.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                handle.readabilityHandler = nil
                return
            }

            if let chunk = String(data: data, encoding: .utf8) {
                self?.handleChunk(chunk)
            }
        }

        // Read stderr
        let stderrHandle = stderrPipe.fileHandleForReading
        stderrHandle.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                handle.readabilityHandler = nil
                return
            }

            if let errorText = String(data: data, encoding: .utf8), !errorText.isEmpty {
                DispatchQueue.main.async {
                    // Only report actual errors, not debug output
                    if errorText.lowercased().contains("error") || errorText.lowercased().contains("fatal") {
                        self?.onError?(errorText)
                    }
                }
            }
        }

        // Handle process termination
        process.terminationHandler = { [weak self] proc in
            DispatchQueue.main.async {
                if proc.terminationStatus != 0 && proc.terminationStatus != 15 {
                    self?.onError?("Claude Code exited with code \(proc.terminationStatus)")
                }
                // Notify callers that the process has exited so they can clean up
                if self?.resultReceived != true {
                    self?.onProcessExit?()
                }
            }
        }

        do {
            try process.run()
        } catch {
            onError?("Failed to start Claude Code: \(error.localizedDescription)")
        }
    }

    /// Suspend the process (SIGSTOP)
    func suspend() {
        guard let process = process, process.isRunning, !isSuspended else { return }
        kill(process.processIdentifier, SIGSTOP)
        isSuspended = true
    }

    /// Resume a suspended process (SIGCONT)
    func resume() {
        guard let process = process, isSuspended else { return }
        kill(process.processIdentifier, SIGCONT)
        isSuspended = false
    }

    /// Cancel the current subprocess
    func cancel() {
        guard let process = process, process.isRunning else { return }

        // Resume first if suspended (SIGTERM is deferred on stopped process)
        if isSuspended { resume() }

        // Send SIGTERM first
        process.terminate()

        // If still running after 2 seconds, SIGKILL
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) { [weak self] in
            if let p = self?.process, p.isRunning {
                kill(p.processIdentifier, SIGKILL)
            }
        }
    }

    var isRunning: Bool {
        return process?.isRunning ?? false
    }

    // MARK: - Private

    private func handleChunk(_ chunk: String) {
        buffer += chunk

        // Process complete lines
        while let newlineRange = buffer.range(of: "\n") {
            let line = String(buffer[buffer.startIndex..<newlineRange.lowerBound])
            buffer = String(buffer[newlineRange.upperBound...])

            if let event = parser.parseLine(line) {
                DispatchQueue.main.async { [weak self] in
                    self?.handleEvent(event)
                }
            }
        }
    }

    private func handleEvent(_ event: StreamEvent) {
        switch event {
        case .system(let systemEvent):
            // System event — could store session info
            _ = systemEvent

        case .assistant(let assistantEvent):
            // Extract text and thinking from content blocks
            for block in assistantEvent.message.content {
                if block.type == "text", let text = block.text {
                    onTextDelta?(text)
                }
                if block.type == "thinking", let thinking = block.thinking {
                    onThinkingDelta?(thinking)
                }
                if block.type == "tool_use" {
                    var toolInfo: [String: Any] = [:]
                    toolInfo["name"] = block.name ?? "unknown"
                    if let id = block.id { toolInfo["id"] = id }
                    // Extract input arguments (contains file_path, etc.)
                    if let input = block.input?.value as? [String: Any] {
                        toolInfo["input"] = input
                    }
                    onToolCall?(toolInfo)
                }
            }

        case .result(let resultEvent):
            resultReceived = true
            onResult?(resultEvent)
        }
    }
}
