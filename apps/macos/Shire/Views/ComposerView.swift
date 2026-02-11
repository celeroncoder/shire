import AppKit

// Custom NSTextView: handles Cmd+Return to send, click-through focus
private final class ChatTextView: NSTextView {
    var onCommandReturn: (() -> Void)?

    // Allow click-through: when the window isn't key, the first click
    // both activates the window AND focuses this text view in one action.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        // Command+Return → send message
        if event.keyCode == 36 && event.modifierFlags.contains(.command) {
            onCommandReturn?()
            return
        }
        super.keyDown(with: event)
    }

    override func mouseDown(with event: NSEvent) {
        // Immediately grab first responder on any click
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()
        menu.addItem(withTitle: "Copy", action: #selector(copy(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "Paste", action: #selector(paste(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "Cut", action: #selector(cut(_:)), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Select All", action: #selector(selectAll(_:)), keyEquivalent: "")
        return menu
    }
}

/// Represents a file entry in the @ completion list
private struct FileEntry {
    let path: String
    let size: Int64 // bytes, -1 for directories
    var isDirectory: Bool { path.hasSuffix("/") }

    var formattedSize: String {
        if isDirectory { return "—" }
        if size < 1024 { return "\(size) B" }
        if size < 1024 * 1024 { return "\(size / 1024) KB" }
        return String(format: "%.1f MB", Double(size) / (1024 * 1024))
    }

    /// Rough token estimate (~4 bytes per token)
    var estimatedTokens: Int {
        if isDirectory { return 0 }
        return Int(size / 4)
    }

    var isLargeFile: Bool { size > 100_000 } // >100KB
    var isHugeFile: Bool { size > 500_000 }  // >500KB
}

final class ComposerView: NSView, NSTextViewDelegate {

    var onSend: ((String) -> Void)?
    var onStop: (() -> Void)?
    var workspacePath: String?

    private var textView: ChatTextView!
    private var scrollView: NSScrollView!
    private var sendButton: NSButton!
    private var stopButton: NSButton!
    private var modelButton: NSButton!
    private var permissionModeButton: NSButton!
    private var container: NSView!
    private var placeholderLabel: NSTextField!
    private var heightConstraint: NSLayoutConstraint!
    private let minHeight: CGFloat = 56
    private let maxHeight: CGFloat = 200

    // @ file completion state
    private var completionStartIndex: Int?
    private var completionPanel: NSPanel?
    private var completionTableView: NSTableView?
    private var completionResults: [FileEntry] = []
    private var fileIndex: [FileEntry]?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        wantsLayer = true

        // Rounded container
        container = NSView()
        container.wantsLayer = true
        container.layer?.cornerRadius = 12
        container.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        container.translatesAutoresizingMaskIntoConstraints = false
        addSubview(container)

        // Text view
        textView = ChatTextView()
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.font = .systemFont(ofSize: 13)
        textView.textColor = .labelColor
        textView.insertionPointColor = .labelColor
        textView.textContainerInset = NSSize(width: 4, height: 6)
        textView.delegate = self
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.drawsBackground = false
        textView.onCommandReturn = { [weak self] in self?.sendClicked() }

        scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = false
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(scrollView)

        // Placeholder
        placeholderLabel = NSTextField(labelWithString: "Send a message... (@ to reference files)")
        placeholderLabel.font = .systemFont(ofSize: 13)
        placeholderLabel.textColor = .placeholderTextColor
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(placeholderLabel)

        // Bottom bar
        let bottomBar = NSView()
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(bottomBar)

        // Model pill button
        let sparkleConfig = NSImage.SymbolConfiguration(pointSize: 9, weight: .semibold)
        modelButton = NSButton()
        modelButton.bezelStyle = .inline
        modelButton.isBordered = false
        modelButton.wantsLayer = true
        modelButton.layer?.cornerRadius = 10
        modelButton.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.06).cgColor
        modelButton.font = .systemFont(ofSize: 11, weight: .medium)
        modelButton.contentTintColor = .secondaryLabelColor
        modelButton.image = NSImage(systemSymbolName: "sparkle", accessibilityDescription: nil)?.withSymbolConfiguration(sparkleConfig)
        modelButton.imagePosition = .imageLeading
        modelButton.target = self
        modelButton.action = #selector(showModelMenu(_:))
        modelButton.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.addSubview(modelButton)
        selectCurrentModel()

        // Permission mode pill button
        permissionModeButton = NSButton()
        permissionModeButton.bezelStyle = .inline
        permissionModeButton.isBordered = false
        permissionModeButton.wantsLayer = true
        permissionModeButton.layer?.cornerRadius = 10
        permissionModeButton.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.06).cgColor
        permissionModeButton.font = .systemFont(ofSize: 11, weight: .medium)
        permissionModeButton.contentTintColor = .secondaryLabelColor
        permissionModeButton.imagePosition = .imageLeading
        permissionModeButton.target = self
        permissionModeButton.action = #selector(showPermissionMenu(_:))
        permissionModeButton.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.addSubview(permissionModeButton)
        selectCurrentPermissionMode()

        // Keyboard shortcut hint
        let hintLabel = NSTextField(labelWithString: "⌘⏎")
        hintLabel.font = .systemFont(ofSize: 10, weight: .medium)
        hintLabel.textColor = .tertiaryLabelColor
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.addSubview(hintLabel)

        // Send button (muted rounded rect with arrow up)
        let sendConfig = NSImage.SymbolConfiguration(pointSize: 11, weight: .bold)
        sendButton = NSButton(
            image: NSImage(systemSymbolName: "arrow.up", accessibilityDescription: "Send")!.withSymbolConfiguration(sendConfig)!,
            target: self,
            action: #selector(sendClicked)
        )
        sendButton.bezelStyle = .inline
        sendButton.isBordered = false
        sendButton.wantsLayer = true
        sendButton.layer?.cornerRadius = 6
        sendButton.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.15).cgColor
        sendButton.contentTintColor = .labelColor
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.addSubview(sendButton)

        // Stop button (shown during streaming)
        let stopConfig = NSImage.SymbolConfiguration(pointSize: 9, weight: .bold)
        stopButton = NSButton(
            image: NSImage(systemSymbolName: "stop.fill", accessibilityDescription: "Stop generation")!.withSymbolConfiguration(stopConfig)!,
            target: self,
            action: #selector(stopClicked)
        )
        stopButton.bezelStyle = .inline
        stopButton.isBordered = false
        stopButton.wantsLayer = true
        stopButton.layer?.cornerRadius = 6
        stopButton.layer?.backgroundColor = NSColor.systemRed.withAlphaComponent(0.12).cgColor
        stopButton.contentTintColor = .systemRed
        stopButton.isHidden = true
        stopButton.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.addSubview(stopButton)

        heightConstraint = heightAnchor.constraint(equalToConstant: minHeight + 60)
        heightConstraint.isActive = true

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            container.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            container.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            container.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),

            scrollView.topAnchor.constraint(equalTo: container.topAnchor, constant: 6),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            scrollView.bottomAnchor.constraint(equalTo: bottomBar.topAnchor, constant: -2),

            placeholderLabel.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 8),
            placeholderLabel.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 7),

            bottomBar.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 6),
            bottomBar.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -6),
            bottomBar.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -6),
            bottomBar.heightAnchor.constraint(equalToConstant: 28),

            modelButton.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor),
            modelButton.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),
            modelButton.heightAnchor.constraint(equalToConstant: 22),

            permissionModeButton.leadingAnchor.constraint(equalTo: modelButton.trailingAnchor, constant: 6),
            permissionModeButton.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),
            permissionModeButton.heightAnchor.constraint(equalToConstant: 22),

            hintLabel.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -8),
            hintLabel.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),

            sendButton.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor),
            sendButton.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: 26),
            sendButton.heightAnchor.constraint(equalToConstant: 26),

            stopButton.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor),
            stopButton.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),
            stopButton.widthAnchor.constraint(equalToConstant: 26),
            stopButton.heightAnchor.constraint(equalToConstant: 26),
        ])
    }

    // MARK: - Focus

    // Allow click-through at the container level too: clicking anywhere on
    // the composer area (padding, background) activates the window AND
    // focuses the text view in a single click.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(textView)
        super.mouseDown(with: event)
    }

    func focus() {
        window?.makeFirstResponder(textView)
    }

    // MARK: - Model

    private func selectCurrentModel() {
        let current = SettingsService.shared.model.lowercased()
        switch current {
        case "opus": modelButton.title = " Opus 4.6 "
        case "haiku": modelButton.title = " Haiku 4.5 "
        default: modelButton.title = " Sonnet 4.5 "
        }
    }

    @objc private func showModelMenu(_ sender: NSButton) {
        let menu = NSMenu()
        let models = [("Sonnet 4.5", 0), ("Opus 4.6", 1), ("Haiku 4.5", 2)]
        for (name, tag) in models {
            let item = NSMenuItem(title: name, action: #selector(modelItemSelected(_:)), keyEquivalent: "")
            item.target = self
            item.tag = tag
            let config = NSImage.SymbolConfiguration(pointSize: 10, weight: .medium)
            item.image = NSImage(systemSymbolName: "sparkle", accessibilityDescription: nil)?.withSymbolConfiguration(config)
            menu.addItem(item)
        }
        let point = NSPoint(x: 0, y: sender.bounds.height + 4)
        menu.popUp(positioning: nil, at: point, in: sender)
    }

    @objc private func modelItemSelected(_ sender: NSMenuItem) {
        let value: String
        switch sender.tag {
        case 1: value = "opus"
        case 2: value = "haiku"
        default: value = "sonnet"
        }
        SettingsService.shared.setSetting(key: "model", value: value)
        selectCurrentModel()
    }

    func setEnabled(_ enabled: Bool) {
        textView.isEditable = enabled
        sendButton.isEnabled = enabled
        sendButton.alphaValue = enabled ? 1.0 : 0.4
        sendButton.isHidden = !enabled
        stopButton.isHidden = enabled
    }

    // MARK: - Permission Mode

    private func selectCurrentPermissionMode() {
        let current = SettingsService.shared.permissionMode
        permissionModeButton.title = " \(current.displayName) "
        let config = NSImage.SymbolConfiguration(pointSize: 9, weight: .semibold)
        permissionModeButton.image = NSImage(systemSymbolName: current.iconName, accessibilityDescription: current.displayName)?.withSymbolConfiguration(config)
    }

    @objc private func showPermissionMenu(_ sender: NSButton) {
        let menu = NSMenu()
        for (index, mode) in PermissionMode.allCases.enumerated() {
            let item = NSMenuItem(title: mode.displayName, action: #selector(permissionItemSelected(_:)), keyEquivalent: "")
            item.target = self
            item.tag = index
            let config = NSImage.SymbolConfiguration(pointSize: 10, weight: .medium)
            item.image = NSImage(systemSymbolName: mode.iconName, accessibilityDescription: mode.displayName)?.withSymbolConfiguration(config)
            menu.addItem(item)
        }
        let point = NSPoint(x: 0, y: sender.bounds.height + 4)
        menu.popUp(positioning: nil, at: point, in: sender)
    }

    @objc private func permissionItemSelected(_ sender: NSMenuItem) {
        let modes = PermissionMode.allCases
        guard sender.tag >= 0 && sender.tag < modes.count else { return }
        SettingsService.shared.setPermissionMode(modes[sender.tag])
        selectCurrentPermissionMode()
    }

    @objc private func stopClicked() {
        onStop?()
    }

    @objc private func sendClicked() {
        dismissCompletion()
        let text = textView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        onSend?(text)
        textView.string = ""
        updateHeight()
        updatePlaceholder()
    }

    // MARK: - NSTextViewDelegate

    func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        // Handle completion navigation
        if completionPanel?.isVisible == true {
            if commandSelector == #selector(moveDown(_:)) {
                moveCompletionSelection(by: 1)
                return true
            }
            if commandSelector == #selector(moveUp(_:)) {
                moveCompletionSelection(by: -1)
                return true
            }
            if commandSelector == #selector(insertTab(_:)) || commandSelector == #selector(insertNewline(_:)) {
                if !NSEvent.modifierFlags.contains(.shift) {
                    insertSelectedCompletion()
                    return true
                }
            }
            if commandSelector == #selector(cancelOperation(_:)) {
                dismissCompletion()
                return true
            }
        }

        if commandSelector == #selector(insertNewline(_:)) {
            if NSEvent.modifierFlags.contains(.shift) {
                textView.insertNewlineIgnoringFieldEditor(nil)
                return true
            }
            sendClicked()
            return true
        }
        if commandSelector == #selector(cancelOperation(_:)) {
            dismissCompletion()
            return true
        }
        return false
    }

    func textDidChange(_ notification: Notification) {
        updateHeight()
        updatePlaceholder()
        checkForAtTrigger()
    }

    private func updateHeight() {
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        layoutManager.ensureLayout(for: textContainer)
        let textHeight = layoutManager.usedRect(for: textContainer).height + textView.textContainerInset.height * 2
        let newHeight = min(max(textHeight, minHeight), maxHeight) + 60
        heightConstraint.constant = newHeight
    }

    private func updatePlaceholder() {
        placeholderLabel.isHidden = !textView.string.isEmpty
    }

    // MARK: - @ File Completion

    private func checkForAtTrigger() {
        let text = textView.string
        let cursorPos = textView.selectedRange().location
        guard cursorPos <= text.count else {
            dismissCompletion()
            return
        }

        // Find @ before cursor
        let textPrefix = String(text.prefix(cursorPos))
        guard let atIndex = textPrefix.lastIndex(of: "@") else {
            dismissCompletion()
            return
        }

        let atIntPos = textPrefix.distance(from: textPrefix.startIndex, to: atIndex)

        // Check that @ is at start or preceded by whitespace
        if atIntPos > 0 {
            let before = textPrefix[textPrefix.index(before: atIndex)]
            if !before.isWhitespace && before != "\n" {
                dismissCompletion()
                return
            }
        }

        // Extract query after @
        let queryStart = textPrefix.index(after: atIndex)
        let query = String(textPrefix[queryStart...])

        // Don't show if query has spaces (indicates not a file reference)
        if query.contains(" ") && !query.contains("/") {
            dismissCompletion()
            return
        }

        completionStartIndex = atIntPos
        showCompletion(query: query)
    }

    private func buildFileIndex() -> [FileEntry] {
        if let cached = fileIndex { return cached }
        guard let path = workspacePath else { return [] }

        var files: [FileEntry] = []
        let rootURL = URL(fileURLWithPath: path)
        let skipDirs: Set<String> = [".git", "node_modules", "DerivedData", ".build", ".turbo", "dist", "build"]

        func walk(_ url: URL, prefix: String) {
            guard let items = try? FileManager.default.contentsOfDirectory(
                at: url, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey], options: []
            ) else { return }

            for item in items {
                let name = item.lastPathComponent
                if name == ".DS_Store" { continue }
                let rel = prefix.isEmpty ? name : prefix + "/" + name
                let resourceValues = try? item.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
                let isDir = resourceValues?.isDirectory ?? false

                if isDir {
                    files.append(FileEntry(path: rel + "/", size: -1))
                    if !skipDirs.contains(name) {
                        walk(item, prefix: rel)
                    }
                } else {
                    let size = Int64(resourceValues?.fileSize ?? 0)
                    files.append(FileEntry(path: rel, size: size))
                }
            }
        }

        walk(rootURL, prefix: "")
        files.sort { $0.path < $1.path }
        fileIndex = files
        return files
    }

    private func showCompletion(query: String) {
        let allFiles = buildFileIndex()
        let q = query.lowercased()
        completionResults = q.isEmpty ? Array(allFiles.prefix(100)) : allFiles.filter {
            $0.path.lowercased().contains(q)
        }.prefix(50).map { $0 }

        guard !completionResults.isEmpty else {
            dismissCompletion()
            return
        }

        if completionPanel == nil {
            createCompletionPanel()
        }

        completionTableView?.reloadData()
        if completionResults.count > 0 {
            completionTableView?.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }

        positionCompletionPanel()
        completionPanel?.orderFront(nil)
    }

    private func createCompletionPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 320),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = true
        panel.hasShadow = true
        panel.backgroundColor = .clear
        panel.level = .popUpMenu // Above everything
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false

        let contentView = NSVisualEffectView(frame: panel.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]
        contentView.material = .popover
        contentView.state = .active
        contentView.wantsLayer = true
        contentView.layer?.cornerRadius = 10
        contentView.layer?.masksToBounds = true
        contentView.layer?.borderWidth = 0.5
        contentView.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.5).cgColor
        panel.contentView = contentView

        let tableView = NSTableView()
        tableView.headerView = nil
        tableView.backgroundColor = .clear
        tableView.rowHeight = 28
        tableView.intercellSpacing = NSSize(width: 0, height: 1)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.doubleAction = #selector(completionDoubleClicked)
        tableView.target = self

        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("File"))
        col.isEditable = false
        tableView.addTableColumn(col)

        let scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.scrollerStyle = .overlay
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.autoresizingMask = [.width, .height]
        scrollView.frame = contentView.bounds.insetBy(dx: 4, dy: 4)
        contentView.addSubview(scrollView)

        completionTableView = tableView
        completionPanel = panel
    }

    private func positionCompletionPanel() {
        guard let panel = completionPanel, let window = self.window else { return }

        // Convert composer container to screen coordinates
        let containerFrame = container.convert(container.bounds, to: nil)
        let screenFrame = window.convertToScreen(containerFrame)

        let rowHeight: CGFloat = 29 // 28 row + 1 spacing
        let panelHeight: CGFloat = min(CGFloat(completionResults.count) * rowHeight + 8, 320)
        let panelWidth: CGFloat = max(screenFrame.width, 480)
        let gap: CGFloat = 6 // gap between composer and panel

        // Position above the composer container
        let panelY = screenFrame.maxY + gap
        let panelX = screenFrame.origin.x + (screenFrame.width - panelWidth) / 2

        // Ensure panel doesn't go off the top of the screen
        if let screen = window.screen ?? NSScreen.main {
            let maxY = screen.visibleFrame.maxY
            let clampedY = min(panelY, maxY - panelHeight)
            panel.setFrame(NSRect(
                x: panelX,
                y: clampedY,
                width: panelWidth,
                height: panelHeight
            ), display: true)
        } else {
            panel.setFrame(NSRect(
                x: panelX,
                y: panelY,
                width: panelWidth,
                height: panelHeight
            ), display: true)
        }
    }

    private func moveCompletionSelection(by delta: Int) {
        guard let tv = completionTableView else { return }
        let current = tv.selectedRow
        let next = max(0, min(completionResults.count - 1, current + delta))
        tv.selectRowIndexes(IndexSet(integer: next), byExtendingSelection: false)
        tv.scrollRowToVisible(next)
    }

    private func insertSelectedCompletion() {
        guard let tv = completionTableView, tv.selectedRow >= 0,
              tv.selectedRow < completionResults.count,
              let startIndex = completionStartIndex else { return }

        let entry = completionResults[tv.selectedRow]
        let cursorPos = textView.selectedRange().location

        // Replace @query with the file path
        let range = NSRange(location: startIndex, length: cursorPos - startIndex)
        textView.replaceCharacters(in: range, with: "@\(entry.path) ")
        dismissCompletion()
    }

    @objc private func completionDoubleClicked() {
        insertSelectedCompletion()
    }

    private func dismissCompletion() {
        completionPanel?.orderOut(nil)
        completionStartIndex = nil
    }
}

// MARK: - Completion Table DataSource & Delegate

extension ComposerView: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int {
        return completionResults.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < completionResults.count else { return nil }
        let entry = completionResults[row]

        let cellId = NSUserInterfaceItemIdentifier("CompletionCell")

        // Always create a fresh cell to avoid stale size labels
        let c = NSTableCellView()
        c.identifier = cellId

        let img = NSImageView()
        img.translatesAutoresizingMaskIntoConstraints = false
        c.addSubview(img)
        c.imageView = img

        let txt = NSTextField(labelWithString: "")
        txt.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        txt.lineBreakMode = .byTruncatingMiddle
        txt.translatesAutoresizingMaskIntoConstraints = false
        c.addSubview(txt)
        c.textField = txt

        let sizeLabel = NSTextField(labelWithString: "")
        sizeLabel.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        sizeLabel.alignment = .right
        sizeLabel.translatesAutoresizingMaskIntoConstraints = false
        sizeLabel.setContentHuggingPriority(.required, for: .horizontal)
        sizeLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        c.addSubview(sizeLabel)

        NSLayoutConstraint.activate([
            img.leadingAnchor.constraint(equalTo: c.leadingAnchor, constant: 8),
            img.centerYAnchor.constraint(equalTo: c.centerYAnchor),
            img.widthAnchor.constraint(equalToConstant: 16),
            img.heightAnchor.constraint(equalToConstant: 16),
            txt.leadingAnchor.constraint(equalTo: img.trailingAnchor, constant: 6),
            txt.trailingAnchor.constraint(lessThanOrEqualTo: sizeLabel.leadingAnchor, constant: -8),
            txt.centerYAnchor.constraint(equalTo: c.centerYAnchor),
            sizeLabel.trailingAnchor.constraint(equalTo: c.trailingAnchor, constant: -10),
            sizeLabel.centerYAnchor.constraint(equalTo: c.centerYAnchor),
            sizeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 50),
        ])

        // File path
        txt.stringValue = entry.path

        // Size label with color coding
        if entry.isDirectory {
            sizeLabel.stringValue = ""
        } else {
            sizeLabel.stringValue = entry.formattedSize
            if entry.isHugeFile {
                sizeLabel.textColor = .systemRed
                txt.textColor = .systemRed.withAlphaComponent(0.8)
            } else if entry.isLargeFile {
                sizeLabel.textColor = .systemOrange
                txt.textColor = .labelColor
            } else {
                sizeLabel.textColor = .tertiaryLabelColor
                txt.textColor = .labelColor
            }
        }

        // Icon
        if entry.isDirectory {
            img.image = NSImage(systemSymbolName: "folder.fill", accessibilityDescription: "Folder")
            img.contentTintColor = .systemBlue
            txt.textColor = .labelColor
        } else {
            if let wsPath = workspacePath {
                let fullPath = (wsPath as NSString).appendingPathComponent(entry.path)
                let icon = NSWorkspace.shared.icon(forFile: fullPath)
                icon.size = NSSize(width: 16, height: 16)
                img.image = icon
            } else {
                img.image = NSImage(systemSymbolName: "doc", accessibilityDescription: "File")
                img.contentTintColor = .secondaryLabelColor
            }
        }

        return c
    }
}
