import AppKit

final class WorkspaceViewController: NSViewController {

    private let workspace: Workspace

    init(workspace: Workspace) {
        self.workspace = workspace
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView()
        view.frame = NSRect(x: 0, y: 0, width: 800, height: 600)

        let sessions = SessionRepository.shared.listByWorkspace(workspaceId: workspace.id)

        // Center container
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(container)

        // Workspace icon (native folder icon for the actual path)
        let iconView = NSImageView()
        let icon = NSWorkspace.shared.icon(forFile: workspace.path)
        icon.size = NSSize(width: 64, height: 64)
        iconView.image = icon
        iconView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(iconView)

        // Workspace name
        let nameLabel = NSTextField(labelWithString: workspace.name)
        nameLabel.font = .systemFont(ofSize: 26, weight: .bold)
        nameLabel.textColor = .labelColor
        nameLabel.alignment = .center
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(nameLabel)

        // Path
        let pathLabel = NSTextField(labelWithString: workspace.path)
        pathLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        pathLabel.textColor = .tertiaryLabelColor
        pathLabel.alignment = .center
        pathLabel.lineBreakMode = .byTruncatingMiddle
        pathLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(pathLabel)

        // Session count
        let countText = sessions.isEmpty ? "No chat sessions yet" : "\(sessions.count) chat session\(sessions.count == 1 ? "" : "s")"
        let countLabel = NSTextField(labelWithString: countText)
        countLabel.font = .systemFont(ofSize: 12)
        countLabel.textColor = .secondaryLabelColor
        countLabel.alignment = .center
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(countLabel)

        // Button row
        let buttonRow = NSStackView()
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 12
        buttonRow.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(buttonRow)

        // New Chat button (primary — keyEquivalent gives it accent color)
        let newChatButton = NSButton(title: "New Chat", target: self, action: #selector(createNewSession))
        newChatButton.bezelStyle = .rounded
        newChatButton.controlSize = .large
        newChatButton.keyEquivalent = "\r"
        buttonRow.addArrangedSubview(newChatButton)

        // Open in Finder button
        let revealButton = NSButton(title: "Open in Finder", target: self, action: #selector(revealInFinder))
        revealButton.bezelStyle = .rounded
        revealButton.controlSize = .large
        buttonRow.addArrangedSubview(revealButton)

        NSLayoutConstraint.activate([
            container.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            container.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            container.widthAnchor.constraint(lessThanOrEqualToConstant: 500),
            container.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 40),
            container.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -40),

            iconView.topAnchor.constraint(equalTo: container.topAnchor),
            iconView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 64),
            iconView.heightAnchor.constraint(equalToConstant: 64),

            nameLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 16),
            nameLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            nameLabel.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor),

            pathLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 6),
            pathLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            pathLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 400),

            countLabel.topAnchor.constraint(equalTo: pathLabel.bottomAnchor, constant: 4),
            countLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),

            buttonRow.topAnchor.constraint(equalTo: countLabel.bottomAnchor, constant: 24),
            buttonRow.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            buttonRow.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        // Recent sessions section
        if !sessions.isEmpty {
            let recentSection = createRecentSessions(sessions: Array(sessions.prefix(5)))
            recentSection.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(recentSection)

            NSLayoutConstraint.activate([
                recentSection.topAnchor.constraint(equalTo: container.bottomAnchor, constant: 40),
                recentSection.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                recentSection.widthAnchor.constraint(equalToConstant: 360),
            ])
        }
    }

    // MARK: - Recent Sessions

    private func createRecentSessions(sessions: [Session]) -> NSView {
        let container = NSView()

        let titleLabel = NSTextField(labelWithString: "Recent Chats")
        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)

        let sep = NSBox()
        sep.boxType = .separator
        sep.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(sep)

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 2
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        for session in sessions {
            let button = NSButton(title: session.title ?? "New Chat", target: self, action: #selector(openSession(_:)))
            button.bezelStyle = .inline
            button.isBordered = false
            button.font = .systemFont(ofSize: 13)
            button.contentTintColor = .labelColor
            button.identifier = NSUserInterfaceItemIdentifier(session.id)
            button.image = NSImage(systemSymbolName: "bubble.left", accessibilityDescription: "Chat")
            button.imagePosition = .imageLeading
            stack.addArrangedSubview(button)
        }

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),

            sep.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            sep.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            sep.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            stack.topAnchor.constraint(equalTo: sep.bottomAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        return container
    }

    // MARK: - Actions

    @objc private func createNewSession() {
        let session = WorkspaceService.shared.createSession(workspaceId: workspace.id)
        NotificationCenter.default.post(name: .navigateToSession, object: nil, userInfo: ["session": session])
        NotificationCenter.default.post(name: .sessionsChanged, object: nil)
    }

    @objc private func revealInFinder() {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: workspace.path)
    }

    @objc private func openSession(_ sender: NSButton) {
        guard let sessionId = sender.identifier?.rawValue else { return }
        guard let session = SessionRepository.shared.getById(id: sessionId) else { return }
        NotificationCenter.default.post(name: .navigateToSession, object: nil, userInfo: ["session": session])
    }
}
