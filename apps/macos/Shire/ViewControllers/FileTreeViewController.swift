import AppKit

// MARK: - FileNode

class FileNode {
    let name: String
    let url: URL
    let isDirectory: Bool
    var children: [FileNode]?
    var isLoaded = false

    init(url: URL) {
        self.name = url.lastPathComponent
        self.url = url
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        self.isDirectory = isDir.boolValue
    }

    func loadChildren() {
        guard isDirectory, !isLoaded else { return }
        isLoaded = true
        let fm = FileManager.default
        guard let urls = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        ) else {
            children = []
            return
        }
        children = urls
            .filter { $0.lastPathComponent != ".DS_Store" }
            .sorted { a, b in
                let aIsDir = (try? a.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                let bIsDir = (try? b.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                if aIsDir != bIsDir { return aIsDir }
                return a.lastPathComponent.localizedCaseInsensitiveCompare(b.lastPathComponent) == .orderedAscending
            }
            .map { FileNode(url: $0) }
    }
}

// MARK: - TreeSectionItem

class TreeSectionItem {
    enum Kind { case agentFiles, allFiles }
    let kind: Kind
    var title: String { kind == .agentFiles ? "Agent Files" : "All Files" }

    init(kind: Kind) {
        self.kind = kind
    }
}

// MARK: - FileTreeViewController

final class FileTreeViewController: NSViewController {

    private var outlineView: NSOutlineView!
    private var treeScrollView: NSScrollView!
    private var topFadeView: ScrollFadeView!
    private var bottomFadeView: ScrollFadeView!
    private var rootNodes: [FileNode] = []
    private var emptyLabel: NSTextField!
    private var currentPath: String?

    // Agent files tracking
    private var agentArtifacts: [Artifact] = []
    private var currentSessionId: String?
    private var agentModifiedPaths: Set<String> = []
    private var sections: [TreeSectionItem] = []

    override func loadView() {
        let container = NSView()
        container.frame = NSRect(x: 0, y: 0, width: 260, height: 600)
        view = container

        // Header
        let header = NSView()
        header.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(header)

        let titleLabel = NSTextField(labelWithString: "Files")
        titleLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(titleLabel)

        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(separator)

        // Outline view
        outlineView = NSOutlineView()
        outlineView.headerView = nil
        outlineView.indentationPerLevel = 14
        outlineView.style = .plain
        outlineView.rowSizeStyle = .small
        outlineView.dataSource = self
        outlineView.delegate = self
        outlineView.doubleAction = #selector(doubleClickedRow)
        outlineView.target = self

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("FileColumn"))
        column.isEditable = false
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column

        treeScrollView = NSScrollView()
        treeScrollView.documentView = outlineView
        treeScrollView.hasVerticalScroller = true
        treeScrollView.scrollerStyle = .overlay
        treeScrollView.autohidesScrollers = true
        treeScrollView.drawsBackground = false
        treeScrollView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(treeScrollView)

        // Scroll fade overlays
        topFadeView = ScrollFadeView(edge: .top)
        topFadeView.isHidden = true
        topFadeView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(topFadeView)

        bottomFadeView = ScrollFadeView(edge: .bottom)
        bottomFadeView.isHidden = true
        bottomFadeView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(bottomFadeView)

        // Empty state
        emptyLabel = NSTextField(labelWithString: "No workspace selected")
        emptyLabel.font = .systemFont(ofSize: 12)
        emptyLabel.textColor = .tertiaryLabelColor
        emptyLabel.alignment = .center
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: container.topAnchor),
            header.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: 32),

            titleLabel.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 12),
            titleLabel.centerYAnchor.constraint(equalTo: header.centerYAnchor),

            separator.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: header.trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: header.bottomAnchor),

            treeScrollView.topAnchor.constraint(equalTo: header.bottomAnchor),
            treeScrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            treeScrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            treeScrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            topFadeView.topAnchor.constraint(equalTo: treeScrollView.topAnchor),
            topFadeView.leadingAnchor.constraint(equalTo: treeScrollView.leadingAnchor),
            topFadeView.trailingAnchor.constraint(equalTo: treeScrollView.trailingAnchor),
            topFadeView.heightAnchor.constraint(equalToConstant: 16),

            bottomFadeView.bottomAnchor.constraint(equalTo: treeScrollView.bottomAnchor),
            bottomFadeView.leadingAnchor.constraint(equalTo: treeScrollView.leadingAnchor),
            bottomFadeView.trailingAnchor.constraint(equalTo: treeScrollView.trailingAnchor),
            bottomFadeView.heightAnchor.constraint(equalToConstant: 16),

            emptyLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let nc = NotificationCenter.default
        nc.addObserver(
            self,
            selector: #selector(handleWorkspaceChanged(_:)),
            name: .activeWorkspaceChanged,
            object: nil
        )
        nc.addObserver(
            self,
            selector: #selector(handleOpenFilePreview(_:)),
            name: .openFilePreview,
            object: nil
        )
        nc.addObserver(
            self,
            selector: #selector(handleToolCallBanner(_:)),
            name: .init("com.shire.toolCallBanner"),
            object: nil
        )
        nc.addObserver(
            self,
            selector: #selector(handleStreamDone(_:)),
            name: .init("com.shire.streamDone"),
            object: nil
        )
        nc.addObserver(
            self,
            selector: #selector(handleNavigateToSession(_:)),
            name: .navigateToSession,
            object: nil
        )
        nc.addObserver(
            self,
            selector: #selector(handleArtifactCreated(_:)),
            name: .artifactCreated,
            object: nil
        )

        // Observe scrolling for fade indicators
        treeScrollView.contentView.postsBoundsChangedNotifications = true
        nc.addObserver(
            self,
            selector: #selector(treeScrollDidChange(_:)),
            name: NSView.boundsDidChangeNotification,
            object: treeScrollView.contentView
        )
    }

    // MARK: - Scroll Fades

    @objc private func treeScrollDidChange(_ notification: Notification) {
        updateScrollFades()
    }

    private func updateScrollFades() {
        let contentHeight = outlineView.frame.height
        let visibleHeight = treeScrollView.contentView.bounds.height
        let scrollY = treeScrollView.contentView.bounds.origin.y
        let scrollable = contentHeight > visibleHeight

        topFadeView.isHidden = !scrollable || scrollY <= 1
        bottomFadeView.isHidden = !scrollable || (scrollY + visibleHeight >= contentHeight - 10)
    }

    // MARK: - Actions

    @objc private func doubleClickedRow() {
        let row = outlineView.clickedRow
        guard row >= 0 else { return }
        let item = outlineView.item(atRow: row)

        if let node = item as? FileNode {
            if node.isDirectory {
                if outlineView.isItemExpanded(node) {
                    outlineView.collapseItem(node)
                } else {
                    outlineView.expandItem(node)
                }
            } else {
                NSWorkspace.shared.open(node.url)
            }
        } else if let artifact = item as? Artifact {
            NSWorkspace.shared.open(URL(fileURLWithPath: artifact.filePath))
        } else if item is TreeSectionItem {
            if outlineView.isItemExpanded(item) {
                outlineView.collapseItem(item)
            } else {
                outlineView.expandItem(item)
            }
        }
    }

    @objc private func handleOpenFilePreview(_ notification: Notification) {
        guard let filePath = notification.userInfo?["filePath"] as? String else { return }
        let fileURL = URL(fileURLWithPath: filePath)

        // Try to reveal the file in the outline view
        revealNode(for: fileURL)

        // Open the file with the default application (Quick Look / Xcode / etc.)
        NSWorkspace.shared.open(fileURL)
    }

    /// Walk the tree to reveal and select a file node by URL
    private func revealNode(for url: URL) {
        guard let currentPath = currentPath else { return }
        let workspaceURL = URL(fileURLWithPath: currentPath)

        // Build the path components relative to the workspace
        let relativePath = url.path.replacingOccurrences(of: workspaceURL.path + "/", with: "")
        let pathParts = relativePath.split(separator: "/").map(String.init)

        var parentItem: FileNode? = nil

        for part in pathParts {
            // Find the matching child at this level
            let children: [FileNode]
            if let parent = parentItem {
                parent.loadChildren()
                children = parent.children ?? []
            } else {
                children = rootNodes
            }

            guard let match = children.first(where: { $0.name == part }) else { return }

            if match.isDirectory {
                outlineView.expandItem(match)
            }

            parentItem = match
        }

        // Select the final node
        if let target = parentItem {
            let row = outlineView.row(forItem: target)
            if row >= 0 {
                outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
                outlineView.scrollRowToVisible(row)
            }
        }
    }

    // MARK: - Notification Handlers

    @objc private func handleWorkspaceChanged(_ notification: Notification) {
        currentSessionId = notification.userInfo?["sessionId"] as? String
        if let path = notification.userInfo?["workspacePath"] as? String {
            loadFileTree(at: path)
        } else {
            rootNodes = []
            currentPath = nil
            currentSessionId = nil
            outlineView.reloadData()
            emptyLabel.isHidden = false
        }
        reloadAgentFiles()
    }

    @objc private func handleToolCallBanner(_ notification: Notification) {
        reloadAgentFiles()
    }

    @objc private func handleStreamDone(_ notification: Notification) {
        reloadAgentFiles()
    }

    @objc private func handleNavigateToSession(_ notification: Notification) {
        if let session = notification.userInfo?["session"] as? Session {
            currentSessionId = session.id
            reloadAgentFiles()
        }
    }

    @objc private func handleArtifactCreated(_ notification: Notification) {
        guard let info = notification.userInfo,
              let sessionId = info["sessionId"] as? String,
              sessionId == currentSessionId else { return }
        reloadAgentFiles()
    }

    // MARK: - Agent Files

    private func reloadAgentFiles() {
        guard let sessionId = currentSessionId else {
            agentArtifacts = []
            agentModifiedPaths = []
            rebuildSections()
            outlineView.reloadData()
            return
        }

        agentArtifacts = ArtifactRepository.shared.listBySession(sessionId: sessionId)
        agentModifiedPaths = Set(agentArtifacts.map { $0.filePath })
        rebuildSections()
        outlineView.reloadData()

        // Auto-expand sections
        for section in sections {
            outlineView.expandItem(section)
        }
    }

    private func rebuildSections() {
        if agentArtifacts.isEmpty {
            sections = []
        } else {
            sections = [TreeSectionItem(kind: .agentFiles), TreeSectionItem(kind: .allFiles)]
        }
    }

    // MARK: - File Tree Loading

    private func loadFileTree(at path: String) {
        guard path != currentPath else { return }
        currentPath = path

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let url = URL(fileURLWithPath: path)
            let root = FileNode(url: url)
            root.loadChildren()
            let nodes = root.children ?? []

            DispatchQueue.main.async {
                self?.rootNodes = nodes
                self?.rebuildSections()
                self?.outlineView.reloadData()
                self?.emptyLabel.isHidden = !nodes.isEmpty
                // Auto-expand sections
                if let sections = self?.sections {
                    for section in sections {
                        self?.outlineView.expandItem(section)
                    }
                }
                DispatchQueue.main.async { self?.updateScrollFades() }
            }
        }
    }
}

// MARK: - NSOutlineViewDataSource

extension FileTreeViewController: NSOutlineViewDataSource {

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil {
            return sections.isEmpty ? rootNodes.count : sections.count
        }
        if let section = item as? TreeSectionItem {
            switch section.kind {
            case .agentFiles: return agentArtifacts.count
            case .allFiles: return rootNodes.count
            }
        }
        if let node = item as? FileNode {
            node.loadChildren()
            return node.children?.count ?? 0
        }
        return 0
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil {
            return sections.isEmpty ? rootNodes[index] : sections[index]
        }
        if let section = item as? TreeSectionItem {
            switch section.kind {
            case .agentFiles: return agentArtifacts[index]
            case .allFiles: return rootNodes[index]
            }
        }
        if let node = item as? FileNode {
            node.loadChildren()
            return node.children![index]
        }
        return rootNodes[0]
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        if item is TreeSectionItem { return true }
        if let node = item as? FileNode { return node.isDirectory }
        return false
    }
}

// MARK: - NSOutlineViewDelegate

extension FileTreeViewController: NSOutlineViewDelegate {

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        // Section headers
        if let section = item as? TreeSectionItem {
            return makeSectionHeader(title: section.title)
        }

        // Artifact cells (agent files)
        if let artifact = item as? Artifact {
            return makeArtifactCell(artifact: artifact)
        }

        // Regular file nodes
        if let node = item as? FileNode {
            return makeFileCell(node: node)
        }

        return nil
    }

    // MARK: - Cell Factories

    private func makeSectionHeader(title: String) -> NSView {
        let cellId = NSUserInterfaceItemIdentifier("SectionHeader")
        let cell = outlineView.makeView(withIdentifier: cellId, owner: self) as? NSTableCellView ?? {
            let c = NSTableCellView()
            c.identifier = cellId
            let txt = NSTextField(labelWithString: "")
            txt.font = .systemFont(ofSize: 10, weight: .semibold)
            txt.textColor = .tertiaryLabelColor
            txt.translatesAutoresizingMaskIntoConstraints = false
            c.addSubview(txt)
            c.textField = txt
            NSLayoutConstraint.activate([
                txt.leadingAnchor.constraint(equalTo: c.leadingAnchor, constant: 4),
                txt.centerYAnchor.constraint(equalTo: c.centerYAnchor),
            ])
            return c
        }()
        cell.textField?.stringValue = title.uppercased()
        return cell
    }

    private func makeArtifactCell(artifact: Artifact) -> NSView {
        let cellId = NSUserInterfaceItemIdentifier("ArtifactCell")
        let cell = NSTableCellView()
        cell.identifier = cellId

        let icon = NSImageView()
        let iconName = (artifact.operation == "edit") ? "pencil" : "doc.badge.plus"
        icon.image = NSImage(systemSymbolName: iconName, accessibilityDescription: artifact.operation)
        icon.contentTintColor = (artifact.operation == "edit") ? .systemOrange : .systemGreen
        icon.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(icon)

        // Show just the filename
        let fileName = (artifact.filePath as NSString).lastPathComponent
        let txt = NSTextField(labelWithString: fileName)
        txt.font = .systemFont(ofSize: 12)
        txt.textColor = .labelColor
        txt.lineBreakMode = .byTruncatingTail
        txt.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(txt)
        cell.textField = txt

        // Badge
        let badge = NSView()
        badge.wantsLayer = true
        badge.layer?.cornerRadius = 3
        let badgeColor: NSColor = (artifact.operation == "edit") ? .systemOrange : .systemGreen
        badge.layer?.backgroundColor = badgeColor.withAlphaComponent(0.15).cgColor
        badge.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(badge)

        let badgeLabel = NSTextField(labelWithString: (artifact.operation == "edit") ? "EDIT" : "NEW")
        badgeLabel.font = .systemFont(ofSize: 8, weight: .bold)
        badgeLabel.textColor = badgeColor
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        badge.addSubview(badgeLabel)

        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
            icon.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 14),
            icon.heightAnchor.constraint(equalToConstant: 14),

            txt.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 4),
            txt.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            txt.trailingAnchor.constraint(lessThanOrEqualTo: badge.leadingAnchor, constant: -4),

            badge.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -6),
            badge.centerYAnchor.constraint(equalTo: cell.centerYAnchor),

            badgeLabel.topAnchor.constraint(equalTo: badge.topAnchor, constant: 1),
            badgeLabel.bottomAnchor.constraint(equalTo: badge.bottomAnchor, constant: -1),
            badgeLabel.leadingAnchor.constraint(equalTo: badge.leadingAnchor, constant: 4),
            badgeLabel.trailingAnchor.constraint(equalTo: badge.trailingAnchor, constant: -4),
        ])

        return cell
    }

    private func makeFileCell(node: FileNode) -> NSView {
        let cellId = NSUserInterfaceItemIdentifier("FileCell")
        let cell = outlineView.makeView(withIdentifier: cellId, owner: self) as? NSTableCellView ?? {
            let c = NSTableCellView()
            c.identifier = cellId

            let img = NSImageView()
            img.translatesAutoresizingMaskIntoConstraints = false
            c.addSubview(img)
            c.imageView = img

            let txt = NSTextField(labelWithString: "")
            txt.font = .systemFont(ofSize: 12)
            txt.lineBreakMode = .byTruncatingTail
            txt.translatesAutoresizingMaskIntoConstraints = false
            c.addSubview(txt)
            c.textField = txt

            NSLayoutConstraint.activate([
                img.leadingAnchor.constraint(equalTo: c.leadingAnchor, constant: 2),
                img.centerYAnchor.constraint(equalTo: c.centerYAnchor),
                img.widthAnchor.constraint(equalToConstant: 16),
                img.heightAnchor.constraint(equalToConstant: 16),

                txt.leadingAnchor.constraint(equalTo: img.trailingAnchor, constant: 4),
                txt.trailingAnchor.constraint(equalTo: c.trailingAnchor, constant: -4),
                txt.centerYAnchor.constraint(equalTo: c.centerYAnchor),
            ])

            return c
        }()

        cell.textField?.stringValue = node.name

        // Highlight agent-modified files with purple tint
        if agentModifiedPaths.contains(node.url.path) {
            cell.textField?.textColor = .systemPurple
        } else {
            cell.textField?.textColor = .labelColor
        }

        // Use native macOS file icon for correct type matching
        let icon = NSWorkspace.shared.icon(forFile: node.url.path)
        icon.size = NSSize(width: 16, height: 16)
        cell.imageView?.image = icon

        return cell
    }
}
