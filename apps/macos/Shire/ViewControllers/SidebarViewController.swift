import AppKit

// MARK: - Sidebar Data Types

enum SidebarItem: Hashable {
    case workspace(Workspace)
    case session(Session)
    case showMore(workspaceId: String)

    func hash(into hasher: inout Hasher) {
        switch self {
        case .workspace(let w): hasher.combine("workspace"); hasher.combine(w.id)
        case .session(let s): hasher.combine("session"); hasher.combine(s.id)
        case .showMore(let wid): hasher.combine("showMore"); hasher.combine(wid)
        }
    }

    static func == (lhs: SidebarItem, rhs: SidebarItem) -> Bool {
        switch (lhs, rhs) {
        case (.workspace(let a), .workspace(let b)): return a.id == b.id
        case (.session(let a), .session(let b)): return a.id == b.id
        case (.showMore(let a), .showMore(let b)): return a == b
        default: return false
        }
    }
}

// MARK: - SidebarViewController

final class SidebarViewController: NSViewController {

    private var outlineView: NSOutlineView!
    private var scrollView: NSScrollView!
    private var effectView: NSVisualEffectView!

    private var workspaces: [Workspace] = []
    private var sessionsByWorkspace: [String: [Session]] = [:]
    private var expandedWorkspaces: Set<String> = []
    private var showAllSessions: Set<String> = []
    private var streamingSessionIds: Set<String> = []

    private let maxVisibleSessions = 5

    override func loadView() {
        let container = NSView()
        container.frame = NSRect(x: 0, y: 0, width: 260, height: 600)

        // Vibrancy effect
        effectView = NSVisualEffectView()
        effectView.material = .sidebar
        effectView.blendingMode = .behindWindow
        effectView.state = .followsWindowActiveState
        effectView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(effectView)

        // Outline view
        outlineView = NSOutlineView()
        outlineView.headerView = nil
        outlineView.indentationPerLevel = 16
        outlineView.style = .sourceList
        outlineView.rowSizeStyle = .default
        outlineView.floatsGroupRows = false
        outlineView.dataSource = self
        outlineView.delegate = self

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("SidebarColumn"))
        column.isEditable = false
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column

        scrollView = NSScrollView()
        scrollView.documentView = outlineView
        scrollView.hasVerticalScroller = true
        scrollView.scrollerStyle = .overlay
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(scrollView)

        // Footer bar
        let footerBar = createFooterBar()
        footerBar.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(footerBar)

        NSLayoutConstraint.activate([
            effectView.topAnchor.constraint(equalTo: container.topAnchor),
            effectView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            effectView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            effectView.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            scrollView.topAnchor.constraint(equalTo: container.safeAreaLayoutGuide.topAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: footerBar.topAnchor),

            footerBar.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            footerBar.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            footerBar.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            footerBar.heightAnchor.constraint(equalToConstant: 44),
        ])

        self.view = container
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Register for notifications
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(handleNewWorkspace), name: .newWorkspace, object: nil)
        nc.addObserver(self, selector: #selector(handleNewSession), name: .newSession, object: nil)
        nc.addObserver(self, selector: #selector(reloadData), name: .workspacesChanged, object: nil)
        nc.addObserver(self, selector: #selector(reloadData), name: .sessionsChanged, object: nil)
        nc.addObserver(self, selector: #selector(handleSessionTitleUpdate(_:)), name: .sessionTitleUpdated, object: nil)
        nc.addObserver(self, selector: #selector(handleStreamingStarted(_:)), name: .init("com.shire.streamDelta"), object: nil)
        nc.addObserver(self, selector: #selector(handleStreamingEnded(_:)), name: .init("com.shire.streamDone"), object: nil)
        nc.addObserver(self, selector: #selector(handleStreamingEnded(_:)), name: .init("com.shire.streamError"), object: nil)

        // Context menu
        outlineView.menu = createContextMenu()

        reloadData()
    }

    // MARK: - Data Loading

    @objc func reloadData() {
        workspaces = WorkspaceRepository.shared.list()
        sessionsByWorkspace = [:]
        for workspace in workspaces {
            sessionsByWorkspace[workspace.id] = SessionRepository.shared.listByWorkspace(workspaceId: workspace.id)
            if expandedWorkspaces.isEmpty {
                expandedWorkspaces.insert(workspace.id)
            }
        }
        outlineView.reloadData()

        // Expand stored workspaces
        for workspace in workspaces where expandedWorkspaces.contains(workspace.id) {
            let item = SidebarItem.workspace(workspace)
            outlineView.expandItem(item)
        }
    }

    // MARK: - Actions

    @objc private func handleNewWorkspace() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Choose a folder to create a workspace"

        guard let window = view.window else { return }
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            let name = url.lastPathComponent
            let path = url.path
            WorkspaceService.shared.createWorkspace(name: name, path: path)
            self?.reloadData()
        }
    }

    @objc private func handleNewSession() {
        // Create session for the first workspace if one exists
        guard let workspace = workspaces.first else { return }
        createSession(for: workspace)
    }

    private func createSession(for workspace: Workspace) {
        let session = WorkspaceService.shared.createSession(workspaceId: workspace.id)
        reloadData()
        NotificationCenter.default.post(name: .navigateToSession, object: nil, userInfo: ["session": session])
    }

    @objc private func handleSessionTitleUpdate(_ notification: Notification) {
        reloadData()
    }

    @objc private func handleStreamingStarted(_ notification: Notification) {
        guard let sessionId = notification.userInfo?["sessionId"] as? String else { return }
        guard !streamingSessionIds.contains(sessionId) else { return }
        streamingSessionIds.insert(sessionId)
        updateStreamingIndicator(sessionId: sessionId, isStreaming: true)
    }

    @objc private func handleStreamingEnded(_ notification: Notification) {
        guard let sessionId = notification.userInfo?["sessionId"] as? String else { return }
        guard streamingSessionIds.contains(sessionId) else { return }
        streamingSessionIds.remove(sessionId)
        updateStreamingIndicator(sessionId: sessionId, isStreaming: false)
    }

    private func updateStreamingIndicator(sessionId: String, isStreaming: Bool) {
        for row in 0..<outlineView.numberOfRows {
            if let item = outlineView.item(atRow: row) as? SidebarItem,
               case .session(let s) = item, s.id == sessionId {
                if let cell = outlineView.view(atColumn: 0, row: row, makeIfNecessary: false) as? SidebarRowView {
                    cell.setStreaming(isStreaming)
                }
                break
            }
        }
    }

    // MARK: - Footer

    private func createFooterBar() -> NSView {
        let bar = NSView()

        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(separator)

        let newButton = NSButton(title: "+ New Workspace", target: self, action: #selector(handleNewWorkspace))
        newButton.bezelStyle = .inline
        newButton.isBordered = false
        newButton.font = .systemFont(ofSize: 12)
        newButton.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(newButton)

        let settingsButton = NSButton(image: NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Settings")!, target: self, action: #selector(openSettingsFromSidebar))
        settingsButton.bezelStyle = .inline
        settingsButton.isBordered = false
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(settingsButton)

        NSLayoutConstraint.activate([
            separator.topAnchor.constraint(equalTo: bar.topAnchor),
            separator.leadingAnchor.constraint(equalTo: bar.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: bar.trailingAnchor),

            newButton.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 12),
            newButton.centerYAnchor.constraint(equalTo: bar.centerYAnchor, constant: 2),

            settingsButton.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -12),
            settingsButton.centerYAnchor.constraint(equalTo: bar.centerYAnchor, constant: 2),
        ])

        return bar
    }

    @objc private func openSettingsFromSidebar() {
        NotificationCenter.default.post(name: .openSettings, object: nil)
    }

    // MARK: - Context Menu

    private func createContextMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self
        return menu
    }
}

// MARK: - NSOutlineViewDataSource

extension SidebarViewController: NSOutlineViewDataSource {

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil {
            return workspaces.count
        }
        if let sidebarItem = item as? SidebarItem, case .workspace(let workspace) = sidebarItem {
            let sessions = sessionsByWorkspace[workspace.id] ?? []
            if showAllSessions.contains(workspace.id) || sessions.count <= maxVisibleSessions {
                return sessions.count
            }
            return min(sessions.count, maxVisibleSessions) + 1 // +1 for "Show more..."
        }
        return 0
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil {
            return SidebarItem.workspace(workspaces[index])
        }
        if let sidebarItem = item as? SidebarItem, case .workspace(let workspace) = sidebarItem {
            let sessions = sessionsByWorkspace[workspace.id] ?? []
            let showAll = showAllSessions.contains(workspace.id) || sessions.count <= maxVisibleSessions
            if !showAll && index == maxVisibleSessions {
                return SidebarItem.showMore(workspaceId: workspace.id)
            }
            return SidebarItem.session(sessions[index])
        }
        return SidebarItem.showMore(workspaceId: "")
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        if let sidebarItem = item as? SidebarItem, case .workspace = sidebarItem {
            return true
        }
        return false
    }
}

// MARK: - NSOutlineViewDelegate

extension SidebarViewController: NSOutlineViewDelegate {

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let sidebarItem = item as? SidebarItem else { return nil }

        switch sidebarItem {
        case .workspace(let workspace):
            let cellId = NSUserInterfaceItemIdentifier("WorkspaceCell")
            let cell = outlineView.makeView(withIdentifier: cellId, owner: self) as? SidebarRowView
                ?? SidebarRowView(identifier: cellId)
            cell.configure(workspace: workspace)
            cell.onAddSession = { [weak self] in
                self?.createSession(for: workspace)
            }
            return cell

        case .session(let session):
            let cellId = NSUserInterfaceItemIdentifier("SessionCell")
            let cell = outlineView.makeView(withIdentifier: cellId, owner: self) as? SidebarRowView
                ?? SidebarRowView(identifier: cellId)
            cell.configure(session: session)
            cell.setStreaming(streamingSessionIds.contains(session.id))
            return cell

        case .showMore:
            let cellId = NSUserInterfaceItemIdentifier("ShowMoreCell")
            let cell = outlineView.makeView(withIdentifier: cellId, owner: self) as? NSTableCellView
                ?? NSTableCellView()
            cell.identifier = cellId
            let label = NSTextField(labelWithString: "Show more…")
            label.font = .systemFont(ofSize: 11)
            label.textColor = .tertiaryLabelColor
            label.translatesAutoresizingMaskIntoConstraints = false
            cell.subviews.forEach { $0.removeFromSuperview() }
            cell.addSubview(label)
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                label.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            ])
            cell.textField = label
            return cell
        }
    }

    func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat {
        if let sidebarItem = item as? SidebarItem, case .workspace = sidebarItem {
            return 28
        }
        return 24
    }

    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        return true
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        let selectedRow = outlineView.selectedRow
        guard selectedRow >= 0, let item = outlineView.item(atRow: selectedRow) as? SidebarItem else { return }

        switch item {
        case .workspace(let workspace):
            expandedWorkspaces.insert(workspace.id)
            outlineView.expandItem(item)
            NotificationCenter.default.post(name: .navigateToWorkspace, object: nil, userInfo: ["workspace": workspace])

        case .session(let session):
            NotificationCenter.default.post(name: .navigateToSession, object: nil, userInfo: ["session": session])

        case .showMore(let workspaceId):
            showAllSessions.insert(workspaceId)
            reloadData()
        }
    }

    func outlineView(_ outlineView: NSOutlineView, isGroupItem item: Any) -> Bool {
        if let sidebarItem = item as? SidebarItem, case .workspace = sidebarItem {
            return false
        }
        return false
    }
}

// MARK: - NSMenuDelegate

extension SidebarViewController: NSMenuDelegate {

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let clickedRow = outlineView.clickedRow
        guard clickedRow >= 0, let item = outlineView.item(atRow: clickedRow) as? SidebarItem else { return }

        switch item {
        case .workspace(let workspace):
            menu.addItem(withTitle: "New Session", action: #selector(contextNewSession(_:)), keyEquivalent: "")
                .representedObject = workspace
            menu.addItem(.separator())
            menu.addItem(withTitle: "Rename…", action: #selector(contextRenameWorkspace(_:)), keyEquivalent: "")
                .representedObject = workspace
            menu.addItem(withTitle: "Reveal in Finder", action: #selector(contextRevealInFinder(_:)), keyEquivalent: "")
                .representedObject = workspace
            menu.addItem(.separator())
            menu.addItem(withTitle: "Delete", action: #selector(contextDeleteWorkspace(_:)), keyEquivalent: "")
                .representedObject = workspace

        case .session(let session):
            menu.addItem(withTitle: "Rename…", action: #selector(contextRenameSession(_:)), keyEquivalent: "")
                .representedObject = session
            menu.addItem(.separator())
            menu.addItem(withTitle: "Delete", action: #selector(contextDeleteSession(_:)), keyEquivalent: "")
                .representedObject = session

        case .showMore:
            break
        }
    }

    @objc private func contextNewSession(_ sender: NSMenuItem) {
        guard let workspace = sender.representedObject as? Workspace else { return }
        createSession(for: workspace)
    }

    @objc private func contextRenameWorkspace(_ sender: NSMenuItem) {
        guard let workspace = sender.representedObject as? Workspace else { return }
        let alert = NSAlert()
        alert.messageText = "Rename Workspace"
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 250, height: 24))
        input.stringValue = workspace.name
        alert.accessoryView = input
        guard let window = view.window else { return }
        alert.beginSheetModal(for: window) { [weak self] response in
            if response == .alertFirstButtonReturn {
                WorkspaceService.shared.renameWorkspace(id: workspace.id, name: input.stringValue)
                self?.reloadData()
            }
        }
    }

    @objc private func contextRevealInFinder(_ sender: NSMenuItem) {
        guard let workspace = sender.representedObject as? Workspace else { return }
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: workspace.path)
    }

    @objc private func contextDeleteWorkspace(_ sender: NSMenuItem) {
        guard let workspace = sender.representedObject as? Workspace else { return }
        let alert = NSAlert()
        alert.messageText = "Delete Workspace?"
        alert.informativeText = "This will remove \"\(workspace.name)\" from Shire. Files on disk will not be deleted."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        guard let window = view.window else { return }
        alert.beginSheetModal(for: window) { [weak self] response in
            if response == .alertFirstButtonReturn {
                WorkspaceService.shared.deleteWorkspace(id: workspace.id)
                self?.reloadData()
            }
        }
    }

    @objc private func contextRenameSession(_ sender: NSMenuItem) {
        guard let session = sender.representedObject as? Session else { return }
        let alert = NSAlert()
        alert.messageText = "Rename Session"
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 250, height: 24))
        input.stringValue = session.title ?? "New Chat"
        alert.accessoryView = input
        guard let window = view.window else { return }
        alert.beginSheetModal(for: window) { [weak self] response in
            if response == .alertFirstButtonReturn {
                WorkspaceService.shared.renameSession(id: session.id, title: input.stringValue)
                self?.reloadData()
            }
        }
    }

    @objc private func contextDeleteSession(_ sender: NSMenuItem) {
        guard let session = sender.representedObject as? Session else { return }
        let alert = NSAlert()
        alert.messageText = "Delete Session?"
        alert.informativeText = "This will permanently delete this chat session and all its messages."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        guard let window = view.window else { return }
        alert.beginSheetModal(for: window) { [weak self] response in
            if response == .alertFirstButtonReturn {
                // Capture workspace before deleting the session
                let workspace = WorkspaceRepository.shared.getById(id: session.workspaceId)

                WorkspaceService.shared.deleteSession(id: session.id)
                self?.reloadData()

                // Navigate back to the parent workspace view
                if let workspace = workspace {
                    NotificationCenter.default.post(
                        name: .navigateToWorkspace,
                        object: nil,
                        userInfo: ["workspace": workspace]
                    )
                }
            }
        }
    }
}
