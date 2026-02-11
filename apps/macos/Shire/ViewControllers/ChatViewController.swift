import AppKit

private final class PointingHandButton: NSButton {
    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }
}

final class ChatViewController: NSViewController {

    private let session: Session
    private var messages: [Message] = []
    private var isStreaming = false
    private var streamingThinkingText = ""
    private var streamingItems: [StreamingItem] = []
    private var workspacePath: String?

    private var tableView: NSTableView!
    private var scrollView: NSScrollView!
    private var composerView: ComposerView!
    private var emptyStateView: NSView!
    private var scrollToBottomButton: NSButton!

    // Question overlay (shown above composer)
    private var questionOverlayView: QuestionCardView?
    private var scrollViewBottomConstraint: NSLayoutConstraint!
    private var pendingQuestionItemIndex: Int?

    // Stick-to-bottom
    private var userIsScrolledUp = false

    init(session: Session) {
        self.session = session
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView()
        view.frame = NSRect(x: 0, y: 0, width: 800, height: 600)
        setupTableView()
        setupEmptyState()
        setupComposer()
        setupConstraints()
        setupScrollToBottom()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Resolve workspace path for file reference detection
        if let workspace = WorkspaceRepository.shared.getById(id: session.workspaceId) {
            workspacePath = workspace.path
        }

        loadMessages()

        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(handleStreamDelta(_:)), name: .init("com.shire.streamDelta"), object: nil)
        nc.addObserver(self, selector: #selector(handleStreamThinkingDelta(_:)), name: .init("com.shire.streamThinkingDelta"), object: nil)
        nc.addObserver(self, selector: #selector(handleStreamDone(_:)), name: .init("com.shire.streamDone"), object: nil)
        nc.addObserver(self, selector: #selector(handleStreamError(_:)), name: .init("com.shire.streamError"), object: nil)
        nc.addObserver(self, selector: #selector(handleToolCallBanner(_:)), name: .init("com.shire.toolCallBanner"), object: nil)

        // Listen for scroll changes (stick-to-bottom)
        scrollView.contentView.postsBoundsChangedNotifications = true
        nc.addObserver(self, selector: #selector(scrollViewDidScroll(_:)),
                       name: NSView.boundsDidChangeNotification, object: scrollView.contentView)
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        // Autofocus the composer
        composerView.focus()
    }

    // MARK: - Setup

    private func setupTableView() {
        tableView = NSTableView()
        tableView.headerView = nil
        tableView.selectionHighlightStyle = .none
        tableView.backgroundColor = .clear
        tableView.intercellSpacing = NSSize(width: 0, height: 2)
        tableView.usesAutomaticRowHeights = true
        tableView.dataSource = self
        tableView.delegate = self

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("MessageColumn"))
        column.isEditable = false
        tableView.addTableColumn(column)

        scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.scrollerStyle = .overlay
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.contentInsets = NSEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
    }

    private func setupEmptyState() {
        emptyStateView = NSView()
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyStateView)

        let workspaceName: String = {
            if let ws = WorkspaceRepository.shared.getById(id: session.workspaceId) {
                return ws.name
            }
            return "workspace"
        }()

        let title = NSTextField(labelWithString: "New chat in \(workspaceName)")
        title.font = .systemFont(ofSize: 18, weight: .medium)
        title.textColor = .secondaryLabelColor
        title.alignment = .center
        title.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.addSubview(title)

        let subtitle = NSTextField(labelWithString: "Ask Shire anything about your codebase")
        subtitle.font = .systemFont(ofSize: 13)
        subtitle.textColor = .tertiaryLabelColor
        subtitle.alignment = .center
        subtitle.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.addSubview(subtitle)

        NSLayoutConstraint.activate([
            title.centerXAnchor.constraint(equalTo: emptyStateView.centerXAnchor),
            title.centerYAnchor.constraint(equalTo: emptyStateView.centerYAnchor, constant: -12),
            subtitle.centerXAnchor.constraint(equalTo: emptyStateView.centerXAnchor),
            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 6),
        ])
    }

    private func setupComposer() {
        composerView = ComposerView()
        composerView.translatesAutoresizingMaskIntoConstraints = false
        composerView.onSend = { [weak self] text in
            self?.sendMessage(text)
        }
        composerView.onStop = { [weak self] in
            self?.stopGeneration()
        }

        // Set workspace path for @ file references
        if let workspace = WorkspaceRepository.shared.getById(id: session.workspaceId) {
            composerView.workspacePath = workspace.path
        }

        view.addSubview(composerView)
    }

    private func setupConstraints() {
        scrollViewBottomConstraint = scrollView.bottomAnchor.constraint(equalTo: composerView.topAnchor)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollViewBottomConstraint,

            emptyStateView.topAnchor.constraint(equalTo: view.topAnchor),
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            emptyStateView.bottomAnchor.constraint(equalTo: composerView.topAnchor),

            composerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            composerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            composerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func setupScrollToBottom() {
        scrollToBottomButton = PointingHandButton(
            image: NSImage(systemSymbolName: "chevron.down", accessibilityDescription: "Scroll to bottom")!,
            target: self,
            action: #selector(scrollToBottomClicked)
        )
        scrollToBottomButton.bezelStyle = .inline
        scrollToBottomButton.isBordered = false
        scrollToBottomButton.wantsLayer = true
        scrollToBottomButton.layer?.cornerRadius = 14
        scrollToBottomButton.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.95).cgColor
        scrollToBottomButton.layer?.borderWidth = 0.5
        scrollToBottomButton.layer?.borderColor = NSColor.separatorColor.cgColor
        scrollToBottomButton.layer?.shadowColor = NSColor.black.cgColor
        scrollToBottomButton.layer?.shadowOpacity = 0.12
        scrollToBottomButton.layer?.shadowRadius = 4
        scrollToBottomButton.layer?.shadowOffset = CGSize(width: 0, height: -1)
        scrollToBottomButton.contentTintColor = .secondaryLabelColor
        scrollToBottomButton.isHidden = true
        scrollToBottomButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollToBottomButton)

        NSLayoutConstraint.activate([
            scrollToBottomButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            scrollToBottomButton.bottomAnchor.constraint(equalTo: composerView.topAnchor, constant: -8),
            scrollToBottomButton.widthAnchor.constraint(equalToConstant: 28),
            scrollToBottomButton.heightAnchor.constraint(equalToConstant: 28),
        ])
    }

    @objc private func scrollToBottomClicked() {
        scrollToBottomForced()
    }


    // MARK: - Data

    private func loadMessages() {
        var allMessages = MessageRepository.shared.listBySession(sessionId: session.id)

        // During streaming, filter out the placeholder message to avoid double-display
        // (it's shown as the streaming row instead)
        if isStreaming, let placeholderId = ChatService.shared.currentPlaceholderMessageId {
            allMessages.removeAll { $0.id == placeholderId }
        }

        messages = allMessages

        // Show the scroll view before reloading so usesAutomaticRowHeights
        // can compute row heights with a non-zero visible area.
        updateEmptyState()
        tableView.reloadData()
        scrollToBottomForced()
    }

    private func updateEmptyState() {
        let hasMessages = !messages.isEmpty || isStreaming
        emptyStateView.isHidden = hasMessages
        scrollView.isHidden = !hasMessages
    }

    // MARK: - Stick-to-Bottom Scrolling

    private var isAtBottom: Bool {
        let clipView = scrollView.contentView
        let contentHeight = tableView.frame.height
        let visibleHeight = clipView.bounds.height
        let scrollY = clipView.bounds.origin.y
        return scrollY + visibleHeight >= contentHeight - 30
    }

    @objc private func scrollViewDidScroll(_ notification: Notification) {
        userIsScrolledUp = !isAtBottom
        scrollToBottomButton.isHidden = isAtBottom
    }

    private func scrollToBottomIfNeeded() {
        guard !userIsScrolledUp else { return }
        scrollToBottomForced()
    }

    private func scrollToBottomForced() {
        let lastRow = tableView.numberOfRows - 1
        guard lastRow >= 0 else { return }
        tableView.scrollRowToVisible(lastRow)
        userIsScrolledUp = false
    }

    // MARK: - Send Message

    private func sendMessage(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard !isStreaming else { return }

        composerView.setEnabled(false)
        isStreaming = true
        streamingThinkingText = ""
        streamingItems = []
        userIsScrolledUp = false  // Reset to bottom on send

        NotificationCenter.default.post(name: .chatStreamingStarted, object: nil)

        ChatService.shared.send(sessionId: session.id, content: text) { [weak self] in
            DispatchQueue.main.async {
                self?.loadMessages()
            }
        }

        loadMessages()
    }

    private func stopGeneration() {
        ChatService.shared.cancelCurrent()
    }

    // MARK: - Question Overlay

    private func showQuestionOverlay(questions: [QuestionItem], itemIndex: Int) {
        hideQuestionOverlay()

        let card = QuestionCardView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.configure(with: questions)
        card.onSubmit = { [weak self] answers in
            self?.handleQuestionSubmit(answers: answers)
        }
        card.onDismiss = { [weak self] in
            self?.handleQuestionDismiss()
        }
        card.onToggle = { [weak self] in
            self?.view.layoutSubtreeIfNeeded()
        }
        view.addSubview(card)

        questionOverlayView = card
        pendingQuestionItemIndex = itemIndex

        // Swap constraints: scrollView → card → composer
        scrollViewBottomConstraint.isActive = false
        NSLayoutConstraint.activate([
            scrollView.bottomAnchor.constraint(equalTo: card.topAnchor),
            card.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            card.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            card.bottomAnchor.constraint(equalTo: composerView.topAnchor, constant: -4),
        ])

        // Focus the card for keyboard shortcuts
        view.window?.makeFirstResponder(card)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            ctx.allowsImplicitAnimation = true
            self.view.layoutSubtreeIfNeeded()
        }
    }

    private func hideQuestionOverlay() {
        guard questionOverlayView != nil else { return }
        questionOverlayView?.removeFromSuperview()
        questionOverlayView = nil
        pendingQuestionItemIndex = nil

        scrollViewBottomConstraint.isActive = true

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            ctx.allowsImplicitAnimation = true
            self.view.layoutSubtreeIfNeeded()
        }

        composerView.focus()
    }

    private func handleQuestionSubmit(answers: [[String]]) {
        if let itemIndex = pendingQuestionItemIndex,
           itemIndex < streamingItems.count,
           case .toolCall(var info) = streamingItems[itemIndex] {
            info.status = .accepted
            streamingItems[itemIndex] = .toolCall(info)
            ChatService.shared.resumeCurrent()
            reloadStreamingRow()
        }
        hideQuestionOverlay()
    }

    private func handleQuestionDismiss() {
        if let itemIndex = pendingQuestionItemIndex,
           itemIndex < streamingItems.count,
           case .toolCall(var info) = streamingItems[itemIndex] {
            info.status = .declined
            streamingItems[itemIndex] = .toolCall(info)
            ChatService.shared.resumeCurrent()
            reloadStreamingRow()
        }
        hideQuestionOverlay()
    }

    /// Revert a file operation via git or rm
    private func revertFile(at path: String?, operation: String) {
        guard let filePath = path else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        if operation == "create" {
            // Remove newly created file
            process.arguments = ["rm", "-f", filePath]
        } else {
            // Revert edit via git checkout
            process.arguments = ["git", "checkout", "--", filePath]
        }
        if let wp = workspacePath {
            process.currentDirectoryURL = URL(fileURLWithPath: wp)
        }
        try? process.run()
    }

    // MARK: - Stream Handlers

    @objc private func handleStreamDelta(_ notification: Notification) {
        guard let info = notification.userInfo,
              info["sessionId"] as? String == session.id,
              let delta = info["delta"] as? String else { return }

        // Append to current text item, or create a new one
        if let lastIndex = streamingItems.indices.last,
           case .text(let existing) = streamingItems[lastIndex] {
            streamingItems[lastIndex] = .text(existing + delta)
        } else {
            streamingItems.append(.text(delta))
        }

        reloadStreamingRow()
        scrollToBottomIfNeeded()
        updateEmptyState()
    }

    @objc private func handleStreamThinkingDelta(_ notification: Notification) {
        guard let info = notification.userInfo,
              info["sessionId"] as? String == session.id,
              let delta = info["delta"] as? String else { return }

        streamingThinkingText += delta
        reloadStreamingRow()
        scrollToBottomIfNeeded()
        updateEmptyState()
    }

    @objc private func handleToolCallBanner(_ notification: Notification) {
        guard let info = notification.userInfo,
              info["sessionId"] as? String == session.id else { return }

        let toolName = info["toolName"] as? String ?? "Write"
        let filePath = info["filePath"] as? String
        let operation = info["operation"] as? String ?? "write"
        let toolId = info["toolId"] as? String
        let inputDetails = info["inputDetails"] as? [String: Any]

        // Write/Edit require approval in ask mode; question tools always require interaction
        let isQuestion = operation == "question"
        let requiresPermission = operation == "create" || operation == "write" || operation == "edit"
        let status: ToolCallBannerInfo.ToolCallStatus = (isQuestion || (requiresPermission && SettingsService.shared.permissionMode.requiresApproval)) ? .pending : .autoAccepted

        let banner = ToolCallBannerInfo(
            id: toolId,
            toolName: toolName,
            filePath: filePath,
            operation: operation,
            status: status,
            inputDetails: inputDetails
        )

        // Add as a streaming item (interleaved with text)
        streamingItems.append(.toolCall(banner))

        // Show question overlay above composer for interactive questions
        if isQuestion, let questions = QuestionCardView.parseQuestions(from: inputDetails) {
            showQuestionOverlay(questions: questions, itemIndex: streamingItems.count - 1)
        }

        reloadStreamingRow()
        scrollToBottomIfNeeded()
    }

    /// Reload only the streaming row, preserving persisted message cells and their expanded card states.
    private func reloadStreamingRow() {
        guard isStreaming else { return }
        let streamingRow = messages.count
        guard streamingRow < tableView.numberOfRows else {
            // Row count mismatch — fall back to full reload
            tableView.reloadData()
            return
        }
        tableView.reloadData(forRowIndexes: IndexSet(integer: streamingRow), columnIndexes: IndexSet(integer: 0))
    }

    @objc private func handleStreamDone(_ notification: Notification) {
        guard let info = notification.userInfo,
              info["sessionId"] as? String == session.id else { return }

        // Clear streaming state BEFORE loading messages so the finalized placeholder
        // is included (not filtered out by the streaming exclusion logic)
        isStreaming = false
        streamingThinkingText = ""
        streamingItems = []
        hideQuestionOverlay()

        loadMessages()

        composerView.setEnabled(true)
        NotificationCenter.default.post(name: .chatStreamingEnded, object: nil)
        composerView.focus()
    }

    @objc private func handleStreamError(_ notification: Notification) {
        guard let info = notification.userInfo,
              info["sessionId"] as? String == session.id else { return }

        // Clear streaming state BEFORE loading messages so the placeholder is included
        isStreaming = false
        streamingItems = []
        hideQuestionOverlay()

        loadMessages()

        composerView.setEnabled(true)
        NotificationCenter.default.post(name: .chatStreamingEnded, object: nil)

        let errorMsg = info["error"] as? String ?? "Unknown error"
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = errorMsg
        alert.alertStyle = .warning
        if let window = view.window {
            alert.beginSheetModal(for: window)
        }
    }
}

// MARK: - NSTableViewDataSource

extension ChatViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        // persisted messages + 1 streaming row (if streaming)
        return messages.count + (isStreaming ? 1 : 0)
    }
}

// MARK: - NSTableViewDelegate

extension ChatViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        // Streaming row (single unified row at the end)
        if isStreaming && row == messages.count {
            let cellId = NSUserInterfaceItemIdentifier("StreamingCell")
            let cell = tableView.makeView(withIdentifier: cellId, owner: self) as? StreamingTextView
                ?? StreamingTextView(identifier: cellId)

            let isAskMode = SettingsService.shared.permissionMode.requiresApproval
            cell.configure(
                thinkingText: streamingThinkingText,
                items: streamingItems,
                isAskMode: isAskMode,
                workspacePath: workspacePath
            )

            cell.onThinkingToggle = { [weak self] in
                DispatchQueue.main.async {
                    self?.tableView.noteHeightOfRows(withIndexesChanged: IndexSet(integer: row))
                }
            }
            cell.onCardToggle = { [weak self] in
                DispatchQueue.main.async {
                    self?.tableView.noteHeightOfRows(withIndexesChanged: IndexSet(integer: row))
                }
            }
            cell.onAcceptToolCall = { [weak self] itemIndex in
                guard let self else { return }
                if case .toolCall(var info) = self.streamingItems[itemIndex] {
                    info.status = .accepted
                    self.streamingItems[itemIndex] = .toolCall(info)
                    ChatService.shared.resumeCurrent()
                    self.reloadStreamingRow()
                }
            }
            cell.onDeclineToolCall = { [weak self] itemIndex in
                guard let self else { return }
                if case .toolCall(var info) = self.streamingItems[itemIndex] {
                    info.status = .declined
                    self.streamingItems[itemIndex] = .toolCall(info)
                    self.revertFile(at: info.filePath, operation: info.operation)
                    ChatService.shared.resumeCurrent()
                    self.reloadStreamingRow()
                }
            }
            cell.onSubmitQuestion = { [weak self] itemIndex, answers in
                guard let self else { return }
                if case .toolCall(var info) = self.streamingItems[itemIndex] {
                    info.status = .accepted
                    self.streamingItems[itemIndex] = .toolCall(info)
                    ChatService.shared.resumeCurrent()
                    self.reloadStreamingRow()
                }
            }
            cell.onStop = { [weak self] in
                self?.stopGeneration()
            }

            return cell
        }

        guard row < messages.count else { return nil }
        let message = messages[row]

        // Tool call display (assistant messages with only tool calls, no content)
        if message.role == "tool" || (message.role == "assistant" && message.toolCalls != nil && message.content == nil) {
            let cellId = NSUserInterfaceItemIdentifier("ToolCallCell")
            let cell = tableView.makeView(withIdentifier: cellId, owner: self) as? ToolCallCellView
                ?? ToolCallCellView(identifier: cellId)
            cell.configure(with: message)
            cell.onCardToggle = { [weak self] in
                DispatchQueue.main.async {
                    self?.tableView.noteHeightOfRows(withIndexesChanged: IndexSet(integer: row))
                }
            }
            return cell
        }

        // Regular message
        let cellId = NSUserInterfaceItemIdentifier("MessageCell")
        let cell = tableView.makeView(withIdentifier: cellId, owner: self) as? MessageCellView
            ?? MessageCellView(identifier: cellId)
        cell.configure(with: message, workspacePath: workspacePath)
        cell.onThinkingToggle = { [weak self] in
            DispatchQueue.main.async {
                self?.tableView.noteHeightOfRows(withIndexesChanged: IndexSet(integer: row))
            }
        }
        cell.onCardToggle = { [weak self] in
            DispatchQueue.main.async {
                self?.tableView.noteHeightOfRows(withIndexesChanged: IndexSet(integer: row))
            }
        }
        return cell
    }
}
