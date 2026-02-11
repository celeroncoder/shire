import Foundation

/// Orchestrates chat interactions between the UI and Claude Code subprocess
final class ChatService {
    static let shared = ChatService()

    private var activeSession: ClaudeCodeSession?
    private var activeSessionId: String?

    /// Placeholder assistant message ID for incremental persistence
    private(set) var currentPlaceholderMessageId: String?
    private var lastPersistTime: TimeInterval = 0
    private let persistInterval: TimeInterval = 2.0

    /// Closure to force-persist accumulated content on cancel (captures local vars from send())
    private var flushAccumulated: (() -> Void)?

    private init() {}

    /// Send a message in a session
    func send(sessionId: String, content: String, completion: @escaping () -> Void) {
        // Cancel any in-progress send
        cancelCurrent()

        // Load session and workspace
        guard let session = SessionRepository.shared.getById(id: sessionId) else {
            postError(sessionId: sessionId, error: "Session not found")
            return
        }
        guard let workspace = WorkspaceRepository.shared.getById(id: session.workspaceId) else {
            postError(sessionId: sessionId, error: "Workspace not found")
            return
        }

        // Persist user message
        let order = MessageRepository.shared.getNextOrder(sessionId: sessionId)
        MessageRepository.shared.create(Message(
            sessionId: sessionId,
            role: "user",
            content: content,
            order: order
        ))

        // Create placeholder assistant message for incremental persistence
        let placeholderOrder = order + 1
        let placeholderId = UUIDv7.generate()
        let placeholder = Message(
            id: placeholderId,
            sessionId: sessionId,
            role: "assistant",
            order: placeholderOrder
        )
        MessageRepository.shared.create(placeholder)
        currentPlaceholderMessageId = placeholderId
        lastPersistTime = 0

        // Get settings
        let model = SettingsService.shared.model
        let maxBudget = SettingsService.shared.getSetting(key: "max_budget_usd")
        let systemPrompt = SettingsService.shared.getSetting(key: "system_prompt")

        // Create subprocess session
        let ccSession = ClaudeCodeSession()
        activeSession = ccSession
        activeSessionId = sessionId

        var accumulatedText = ""
        var accumulatedThinking = ""
        var accumulatedToolCalls: [[String: Any]] = []
        var didComplete = false

        // Set up flush closure so cancelCurrent() can force-persist accumulated content
        self.flushAccumulated = {
            let content = accumulatedText.isEmpty ? nil : accumulatedText
            let thinking = accumulatedThinking.isEmpty ? nil : accumulatedThinking
            let toolCallsJSON: String? = {
                guard !accumulatedToolCalls.isEmpty else { return nil }
                guard let data = try? JSONSerialization.data(withJSONObject: accumulatedToolCalls) else { return nil }
                return String(data: data, encoding: .utf8)
            }()

            if content != nil || toolCallsJSON != nil {
                MessageRepository.shared.finalizeMessage(
                    id: placeholderId,
                    content: content,
                    thinkingContent: thinking,
                    toolCalls: toolCallsJSON,
                    tokenCount: nil,
                    costUsd: nil
                )
            } else {
                // Empty response — clean up the placeholder
                MessageRepository.shared.delete(id: placeholderId)
            }
        }

        // Handle text deltas
        ccSession.onTextDelta = { [weak self] delta in
            accumulatedText += delta
            guard let self else { return }
            self.postDelta(sessionId: sessionId, delta: delta)
            self.schedulePersist(
                placeholderId: placeholderId,
                text: accumulatedText,
                thinking: accumulatedThinking,
                toolCalls: accumulatedToolCalls
            )
        }

        // Handle thinking deltas
        ccSession.onThinkingDelta = { [weak self] delta in
            accumulatedThinking += delta
            guard let self else { return }
            self.postThinkingDelta(sessionId: sessionId, delta: delta)
            self.schedulePersist(
                placeholderId: placeholderId,
                text: accumulatedText,
                thinking: accumulatedThinking,
                toolCalls: accumulatedToolCalls
            )
        }

        // Handle tool calls
        ccSession.onToolCall = { [weak self] toolInfo in
            accumulatedToolCalls.append(toolInfo)
            guard let self else { return }
            self.postToolCall(sessionId: sessionId, toolInfo: toolInfo)

            // Force immediate persist on tool calls (discrete important events)
            self.lastPersistTime = 0
            self.schedulePersist(
                placeholderId: placeholderId,
                text: accumulatedText,
                thinking: accumulatedThinking,
                toolCalls: accumulatedToolCalls
            )

            // Post tool call banner for ALL tool types
            let name = toolInfo["name"] as? String ?? ""
            let input = toolInfo["input"] as? [String: Any]
            let classified = self.classifyToolCall(name: name, input: input)

            self.postToolCallBanner(
                sessionId: sessionId,
                toolId: toolInfo["id"] as? String,
                toolName: name,
                filePath: classified.displayPath,
                operation: classified.operation,
                inputDetails: input
            )

            // Real-time artifact creation for Write/Edit
            if name == "Write" || name == "Edit" || name == "write_file" {
                if let path = classified.displayPath {
                    let artOp = (name == "Edit") ? "edit" : "write"
                    if ArtifactRepository.shared.createIfNotExists(
                        sessionId: sessionId,
                        messageId: placeholderId,
                        filePath: path,
                        operation: artOp
                    ) != nil {
                        self.postArtifactCreated(sessionId: sessionId)
                    }
                }
            }

            // Suspend for questions always, and for Write/Edit in ask mode
            if classified.requiresSuspend {
                if classified.operation == "question" || SettingsService.shared.permissionMode.requiresApproval {
                    self.activeSession?.suspend()
                }
            }
        }

        // Handle result (final event)
        ccSession.onResult = { [weak self] result in
            guard let self = self else { return }
            didComplete = true
            self.flushAccumulated = nil  // Normal completion handles its own finalization

            // Store claude session ID for --resume
            if let claudeSessionId = result.sessionId {
                SessionRepository.shared.updateClaudeSessionId(id: sessionId, claudeSessionId: claudeSessionId)
            }

            // Finalize the placeholder assistant message
            let tokenCount: Int? = {
                guard let usage = result.usage else { return nil }
                return (usage.inputTokens ?? 0) + (usage.outputTokens ?? 0)
            }()

            let toolCallsJSON: String? = {
                guard !accumulatedToolCalls.isEmpty else { return nil }
                guard let data = try? JSONSerialization.data(withJSONObject: accumulatedToolCalls) else { return nil }
                return String(data: data, encoding: .utf8)
            }()

            let finalContent = accumulatedText.isEmpty ? nil : accumulatedText
            let finalThinking = accumulatedThinking.isEmpty ? nil : accumulatedThinking

            if finalContent == nil && toolCallsJSON == nil {
                // Empty response — clean up the placeholder
                MessageRepository.shared.delete(id: placeholderId)
            } else {
                MessageRepository.shared.finalizeMessage(
                    id: placeholderId,
                    content: finalContent,
                    thinkingContent: finalThinking,
                    toolCalls: toolCallsJSON,
                    tokenCount: tokenCount,
                    costUsd: result.costUsd
                )
            }

            // Extract write/edit tool calls → create artifact records (upsert to avoid duplicates)
            self.extractArtifacts(sessionId: sessionId, toolCalls: accumulatedToolCalls, messageId: placeholderId)

            // Touch session
            SessionRepository.shared.touch(id: sessionId)

            // Auto-generate title if this is the first exchange
            if session.title == nil {
                self.autoGenerateTitle(sessionId: sessionId, workspacePath: workspace.path, firstMessage: content)
            }

            // Post done notification
            self.postDone(sessionId: sessionId)

            self.activeSession = nil
            self.activeSessionId = nil
            self.currentPlaceholderMessageId = nil

            completion()
        }

        // Handle errors
        ccSession.onError = { [weak self] error in
            didComplete = true
            self?.flushAccumulated = nil
            self?.postError(sessionId: sessionId, error: error)
            self?.activeSession = nil
            self?.activeSessionId = nil
            self?.currentPlaceholderMessageId = nil
            completion()
        }

        // Handle process exit without result (e.g., resume of finished session)
        ccSession.onProcessExit = { [weak self] in
            guard !didComplete else { return }
            self?.flushAccumulated = nil
            self?.activeSession = nil
            self?.activeSessionId = nil
            self?.currentPlaceholderMessageId = nil
            self?.postDone(sessionId: sessionId)
            completion()
        }

        // Get permission mode
        let permissionMode = SettingsService.shared.permissionMode

        // Start subprocess
        ccSession.send(
            message: content,
            workspacePath: workspace.path,
            claudeSessionId: session.claudeSessionId,
            model: model,
            maxBudget: maxBudget,
            systemPrompt: systemPrompt ?? "You are Shire, a local coding assistant.",
            permissionMode: permissionMode
        )
    }

    /// Cancel the current send
    func cancelCurrent() {
        activeSession?.cancel()
        activeSession = nil

        // Force-persist whatever content has accumulated so far
        flushAccumulated?()
        flushAccumulated = nil

        if let sid = activeSessionId {
            postDone(sessionId: sid)
        }
        activeSessionId = nil
        currentPlaceholderMessageId = nil
    }

    /// Suspend the current subprocess
    func suspendCurrent() {
        activeSession?.suspend()
    }

    /// Resume the current subprocess
    func resumeCurrent() {
        activeSession?.resume()
    }

    /// Whether the current subprocess is suspended
    var isCurrentSuspended: Bool {
        return activeSession?.isSuspended ?? false
    }

    // MARK: - Debounced Streaming Persistence

    private func schedulePersist(placeholderId: String, text: String, thinking: String, toolCalls: [[String: Any]]) {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastPersistTime >= persistInterval else { return }
        lastPersistTime = now

        let content = text.isEmpty ? nil : text
        let thinkingContent = thinking.isEmpty ? nil : thinking
        let toolCallsJSON: String? = {
            guard !toolCalls.isEmpty else { return nil }
            guard let data = try? JSONSerialization.data(withJSONObject: toolCalls) else { return nil }
            return String(data: data, encoding: .utf8)
        }()

        DispatchQueue.global(qos: .utility).async {
            MessageRepository.shared.updateStreamingContent(
                id: placeholderId,
                content: content,
                thinkingContent: thinkingContent,
                toolCalls: toolCallsJSON
            )
        }
    }

    // MARK: - Auto Title Generation

    private func autoGenerateTitle(sessionId: String, workspacePath: String, firstMessage: String) {
        let titleSession = ClaudeCodeSession()
        let prompt = "Generate a concise 4-6 word title for a chat that started with this message. Reply with ONLY the title, no quotes or punctuation: \(firstMessage)"

        var accumulatedTitle = ""

        titleSession.onTextDelta = { delta in
            accumulatedTitle += delta
        }

        titleSession.onResult = { _ in
            let title = accumulatedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            if !title.isEmpty {
                SessionRepository.shared.rename(id: sessionId, title: title)
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .sessionTitleUpdated, object: nil, userInfo: ["sessionId": sessionId])
                }
            }
        }

        let model = SettingsService.shared.model
        titleSession.send(
            message: prompt,
            workspacePath: workspacePath,
            claudeSessionId: nil,
            model: model,
            maxBudget: "0.05",
            systemPrompt: "You are a title generator. Reply with ONLY a concise title."
        )
    }

    // MARK: - Artifact Extraction

    private func extractArtifacts(sessionId: String, toolCalls: [[String: Any]], messageId: String) {
        for call in toolCalls {
            guard let name = call["name"] as? String else { continue }
            if name == "Write" || name == "Edit" || name == "write_file" {
                if let args = call["input"] as? [String: Any],
                   let path = args["file_path"] as? String ?? args["path"] as? String {
                    let operation = (name == "Edit" || name == "edit") ? "edit" : "write"
                    ArtifactRepository.shared.createIfNotExists(
                        sessionId: sessionId,
                        messageId: messageId,
                        filePath: path,
                        operation: operation
                    )
                }
            }
        }
    }

    // MARK: - Tool Classification

    private func classifyToolCall(name: String, input: [String: Any]?) -> (operation: String, displayPath: String?, requiresSuspend: Bool) {
        switch name {
        case "Write", "write_file":
            let path = input?["file_path"] as? String ?? input?["path"] as? String
            return ("create", path, true)
        case "Edit":
            let path = input?["file_path"] as? String ?? input?["path"] as? String
            return ("edit", path, true)
        case "Read", "read_file":
            let path = input?["file_path"] as? String ?? input?["path"] as? String
            return ("read", path, false)
        case "Bash":
            let command = input?["command"] as? String
            return ("bash", command, false)
        case "Glob", "Grep":
            let pattern = input?["pattern"] as? String ?? input?["glob"] as? String
            return ("search", pattern, false)
        case let n where n.lowercased().contains("askuser") || n.lowercased().contains("question"):
            return ("question", nil, true)
        default:
            // Check if input contains a questions array (generic question tool)
            if let questions = input?["questions"] as? [[String: Any]], !questions.isEmpty {
                return ("question", nil, true)
            }
            return (name.lowercased(), nil, false)
        }
    }

    // MARK: - Notifications

    private func postDelta(sessionId: String, delta: String) {
        NotificationCenter.default.post(
            name: .init("com.shire.streamDelta"),
            object: nil,
            userInfo: ["sessionId": sessionId, "delta": delta]
        )
    }

    private func postThinkingDelta(sessionId: String, delta: String) {
        NotificationCenter.default.post(
            name: .init("com.shire.streamThinkingDelta"),
            object: nil,
            userInfo: ["sessionId": sessionId, "delta": delta]
        )
    }

    private func postToolCall(sessionId: String, toolInfo: [String: Any]) {
        NotificationCenter.default.post(
            name: .init("com.shire.streamToolCall"),
            object: nil,
            userInfo: ["sessionId": sessionId, "toolInfo": toolInfo]
        )
    }

    private func postDone(sessionId: String) {
        NotificationCenter.default.post(
            name: .init("com.shire.streamDone"),
            object: nil,
            userInfo: ["sessionId": sessionId]
        )
    }

    private func postError(sessionId: String, error: String) {
        NotificationCenter.default.post(
            name: .init("com.shire.streamError"),
            object: nil,
            userInfo: ["sessionId": sessionId, "error": error]
        )
    }

    private func postToolCallBanner(sessionId: String, toolId: String?, toolName: String, filePath: String?, operation: String, inputDetails: [String: Any]?) {
        NotificationCenter.default.post(
            name: .init("com.shire.toolCallBanner"),
            object: nil,
            userInfo: [
                "sessionId": sessionId,
                "toolId": toolId as Any,
                "toolName": toolName,
                "filePath": filePath as Any,
                "operation": operation,
                "inputDetails": inputDetails as Any,
            ]
        )
    }

    private func postArtifactCreated(sessionId: String) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .artifactCreated,
                object: nil,
                userInfo: ["sessionId": sessionId]
            )
        }
    }
}
