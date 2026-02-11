import AppKit

// MARK: - Settings Tab Definition

private enum SettingsTab: Int, CaseIterable {
    case general = 0
    case mcpServers = 1
    case skills = 2
    case connection = 3

    var title: String {
        switch self {
        case .general: return "General"
        case .mcpServers: return "MCP Servers"
        case .skills: return "Skills"
        case .connection: return "Connection"
        }
    }

    var iconName: String {
        switch self {
        case .general: return "gearshape"
        case .mcpServers: return "server.rack"
        case .skills: return "sparkles"
        case .connection: return "bolt.horizontal.circle"
        }
    }
}

// MARK: - SettingsViewController

final class SettingsViewController: NSViewController {

    private var splitView: NSSplitView!
    private var sidebarScrollView: NSScrollView!
    private var sidebarTableView: NSTableView!
    private var contentContainer: NSView!
    private var currentTab: SettingsTab = .general

    // General tab fields
    private var modelPopup: NSPopUpButton?
    private var budgetField: NSTextField?
    private var systemPromptField: NSTextField?
    private var claudePathField: NSTextField?

    override func loadView() {
        view = NSView()
        view.frame = NSRect(x: 0, y: 0, width: 780, height: 520)

        setupSplitView()
        setupSidebar()
        setupContentContainer()

        // Select General tab by default
        DispatchQueue.main.async { [weak self] in
            self?.sidebarTableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            self?.showContent(for: .general)
        }
    }

    // MARK: - Layout Setup

    private func setupSplitView() {
        splitView = NSSplitView()
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(splitView)

        NSLayoutConstraint.activate([
            splitView.topAnchor.constraint(equalTo: view.topAnchor),
            splitView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            splitView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        splitView.delegate = self
    }

    private func setupSidebar() {
        let sidebarContainer = NSVisualEffectView()
        sidebarContainer.material = .sidebar
        sidebarContainer.blendingMode = .behindWindow
        sidebarContainer.state = .followsWindowActiveState

        sidebarTableView = NSTableView()
        sidebarTableView.headerView = nil
        sidebarTableView.style = .sourceList
        sidebarTableView.rowSizeStyle = .default
        sidebarTableView.backgroundColor = .clear
        sidebarTableView.intercellSpacing = NSSize(width: 0, height: 2)
        sidebarTableView.dataSource = self
        sidebarTableView.delegate = self

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("SettingsTabColumn"))
        column.isEditable = false
        sidebarTableView.addTableColumn(column)

        sidebarScrollView = NSScrollView()
        sidebarScrollView.documentView = sidebarTableView
        sidebarScrollView.hasVerticalScroller = false
        sidebarScrollView.drawsBackground = false
        sidebarScrollView.translatesAutoresizingMaskIntoConstraints = false

        sidebarContainer.addSubview(sidebarScrollView)
        sidebarScrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            sidebarScrollView.topAnchor.constraint(equalTo: sidebarContainer.topAnchor, constant: 12),
            sidebarScrollView.leadingAnchor.constraint(equalTo: sidebarContainer.leadingAnchor),
            sidebarScrollView.trailingAnchor.constraint(equalTo: sidebarContainer.trailingAnchor),
            sidebarScrollView.bottomAnchor.constraint(equalTo: sidebarContainer.bottomAnchor),
        ])

        sidebarContainer.frame = NSRect(x: 0, y: 0, width: 190, height: 520)
        splitView.addSubview(sidebarContainer)
    }

    private func setupContentContainer() {
        contentContainer = NSView()
        contentContainer.frame = NSRect(x: 190, y: 0, width: 590, height: 520)
        splitView.addSubview(contentContainer)
    }

    // MARK: - Tab Content

    private func showContent(for tab: SettingsTab) {
        currentTab = tab

        // Clear existing content
        for child in children {
            child.view.removeFromSuperview()
            child.removeFromParent()
        }
        contentContainer.subviews.forEach { $0.removeFromSuperview() }

        switch tab {
        case .general:
            showGeneralTab()
        case .mcpServers:
            showMCPTab()
        case .skills:
            showSkillsTab()
        case .connection:
            showConnectionTab()
        }
    }

    // MARK: - General Tab

    private func showGeneralTab() {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let container = NSStackView()
        container.orientation = .vertical
        container.alignment = .leading
        container.spacing = 24
        container.translatesAutoresizingMaskIntoConstraints = false
        container.edgeInsets = NSEdgeInsets(top: 32, left: 32, bottom: 32, right: 32)

        // Title
        let titleLabel = NSTextField(labelWithString: "General")
        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        container.addArrangedSubview(titleLabel)

        // Model selection
        container.addArrangedSubview(createSection(title: "Model", description: "The Claude model used for conversations.") {
            let popup = NSPopUpButton()
            popup.addItems(withTitles: ["sonnet", "opus", "haiku"])
            let current = SettingsService.shared.model
            popup.selectItem(withTitle: current)
            popup.target = self
            popup.action = #selector(self.modelChanged)
            self.modelPopup = popup
            return popup
        })

        // Max budget
        container.addArrangedSubview(createSection(title: "Max Budget (USD per message)", description: "Limit spending per message. Leave empty for no limit.") {
            let field = NSTextField()
            field.placeholderString = "e.g. 1.00"
            field.stringValue = SettingsService.shared.getSetting(key: "max_budget_usd") ?? ""
            field.delegate = self
            field.translatesAutoresizingMaskIntoConstraints = false
            field.widthAnchor.constraint(equalToConstant: 150).isActive = true
            self.budgetField = field
            return field
        })

        // System prompt
        container.addArrangedSubview(createSection(title: "Custom System Prompt", description: "Appended to Claude Code's default system prompt for all sessions.") {
            let field = NSTextField()
            field.placeholderString = "Extra instructions for Claude Code…"
            field.stringValue = SettingsService.shared.getSetting(key: "system_prompt") ?? ""
            field.delegate = self
            self.systemPromptField = field
            return field
        })

        // Claude Code path
        container.addArrangedSubview(createSection(title: "Claude Code Binary Path", description: "Override auto-detection of the Claude Code CLI binary.") {
            let stack = NSStackView()
            stack.orientation = .horizontal
            stack.spacing = 8

            let field = NSTextField()
            field.placeholderString = "Auto-detected"
            field.stringValue = SettingsService.shared.getSetting(key: "claude_path") ?? ""
            field.delegate = self
            self.claudePathField = field
            stack.addArrangedSubview(field)

            let detectButton = NSButton(title: "Detect", target: self, action: #selector(self.detectClaudePath))
            detectButton.bezelStyle = .rounded
            stack.addArrangedSubview(detectButton)

            return stack
        })

        // Claude Code status
        let statusView = createStatusBadge()
        container.addArrangedSubview(statusView)

        // Add container to a flipped clip view for scroll
        let clipView = FlippedClipView()
        clipView.drawsBackground = false
        scrollView.contentView = clipView
        scrollView.documentView = container

        contentContainer.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),

            container.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])
    }

    // MARK: - MCP Servers Tab

    private func showMCPTab() {
        let container = NSStackView()
        container.orientation = .vertical
        container.alignment = .leading
        container.spacing = 16
        container.translatesAutoresizingMaskIntoConstraints = false
        container.edgeInsets = NSEdgeInsets(top: 32, left: 32, bottom: 32, right: 32)
        contentContainer.addSubview(container)

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            container.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            container.bottomAnchor.constraint(lessThanOrEqualTo: contentContainer.bottomAnchor),
        ])

        // Title
        let titleLabel = NSTextField(labelWithString: "MCP Servers")
        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        container.addArrangedSubview(titleLabel)

        let subtitleLabel = NSTextField(wrappingLabelWithString: "Model Context Protocol servers extend Claude Code with additional tools and capabilities. Configured in ~/.claude.json or project .mcp.json files.")
        subtitleLabel.font = .systemFont(ofSize: 12)
        subtitleLabel.textColor = .secondaryLabelColor
        container.addArrangedSubview(subtitleLabel)

        // Load servers
        let globalServers = MCPConfigService.shared.loadServers()

        // Also load project servers from all workspaces
        let workspaces = WorkspaceRepository.shared.list()
        var projectServers: [MCPServerConfig] = []
        for workspace in workspaces {
            projectServers.append(contentsOf: MCPConfigService.shared.loadProjectServers(workspacePath: workspace.path))
        }

        let allServers = globalServers + projectServers

        if allServers.isEmpty {
            let emptyView = createEmptyState(
                icon: "server.rack",
                title: "No MCP Servers Configured",
                message: "Add MCP servers to ~/.claude.json to extend Claude Code's capabilities.\n\nExample:\n{\n  \"mcpServers\": {\n    \"my-server\": {\n      \"command\": \"npx\",\n      \"args\": [\"-y\", \"@example/mcp-server\"]\n    }\n  }\n}"
            )
            container.addArrangedSubview(emptyView)
        } else {
            for server in allServers {
                let card = createMCPServerCard(server)
                card.translatesAutoresizingMaskIntoConstraints = false
                container.addArrangedSubview(card)

                NSLayoutConstraint.activate([
                    card.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 32),
                    card.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -32),
                ])
            }
        }
    }

    private func createMCPServerCard(_ server: MCPServerConfig) -> NSView {
        let card = NSView()
        card.wantsLayer = true
        card.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        card.layer?.cornerRadius = 8
        card.layer?.borderWidth = 1
        card.layer?.borderColor = NSColor.separatorColor.cgColor

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
        ])

        // Header row: name + status badge
        let headerStack = NSStackView()
        headerStack.orientation = .horizontal
        headerStack.spacing = 8

        let nameLabel = NSTextField(labelWithString: server.name)
        nameLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        headerStack.addArrangedSubview(nameLabel)

        let sourceBadge = createBadge(
            text: server.source == "global" ? "Global" : "Project",
            color: server.source == "global" ? .systemBlue : .systemPurple
        )
        headerStack.addArrangedSubview(sourceBadge)

        let statusBadge = createBadge(text: "Configured", color: .systemGreen)
        headerStack.addArrangedSubview(statusBadge)

        stack.addArrangedSubview(headerStack)

        // Command info
        let commandText = ([server.command] + server.args).joined(separator: " ")
        let commandLabel = NSTextField(labelWithString: commandText)
        commandLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        commandLabel.textColor = .secondaryLabelColor
        commandLabel.lineBreakMode = .byTruncatingMiddle
        stack.addArrangedSubview(commandLabel)

        // Environment variables (if any)
        if !server.env.isEmpty {
            let envKeys = server.env.keys.sorted().joined(separator: ", ")
            let envLabel = NSTextField(labelWithString: "Env: \(envKeys)")
            envLabel.font = .systemFont(ofSize: 10)
            envLabel.textColor = .tertiaryLabelColor
            stack.addArrangedSubview(envLabel)
        }

        return card
    }

    // MARK: - Skills Tab

    private func showSkillsTab() {
        let container = NSStackView()
        container.orientation = .vertical
        container.alignment = .leading
        container.spacing = 16
        container.translatesAutoresizingMaskIntoConstraints = false
        container.edgeInsets = NSEdgeInsets(top: 32, left: 32, bottom: 32, right: 32)
        contentContainer.addSubview(container)

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            container.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            container.bottomAnchor.constraint(lessThanOrEqualTo: contentContainer.bottomAnchor),
        ])

        // Title
        let titleLabel = NSTextField(labelWithString: "Skills")
        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        container.addArrangedSubview(titleLabel)

        let subtitleLabel = NSTextField(wrappingLabelWithString: "Custom slash commands that extend Claude Code. Stored as .md files in ~/.claude/commands/ or your project's .claude/commands/ directory.")
        subtitleLabel.font = .systemFont(ofSize: 12)
        subtitleLabel.textColor = .secondaryLabelColor
        container.addArrangedSubview(subtitleLabel)

        // Load skills
        let userSkills = SkillsService.shared.loadUserSkills()

        let workspaces = WorkspaceRepository.shared.list()
        var projectSkills: [SkillInfo] = []
        for workspace in workspaces {
            projectSkills.append(contentsOf: SkillsService.shared.loadProjectSkills(workspacePath: workspace.path))
        }

        let allSkills = userSkills + projectSkills

        if allSkills.isEmpty {
            let emptyView = createEmptyState(
                icon: "sparkles",
                title: "No Skills Found",
                message: "Create custom slash commands by adding .md files to ~/.claude/commands/\n\nExample: Create ~/.claude/commands/review.md with instructions for code review, then use /review in chat."
            )
            container.addArrangedSubview(emptyView)
        } else {
            // Section: User Skills
            if !userSkills.isEmpty {
                let sectionLabel = NSTextField(labelWithString: "User Skills")
                sectionLabel.font = .systemFont(ofSize: 13, weight: .semibold)
                sectionLabel.textColor = .secondaryLabelColor
                container.addArrangedSubview(sectionLabel)

                for skill in userSkills {
                    let card = createSkillCard(skill)
                    card.translatesAutoresizingMaskIntoConstraints = false
                    container.addArrangedSubview(card)

                    NSLayoutConstraint.activate([
                        card.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 32),
                        card.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -32),
                    ])
                }
            }

            // Section: Project Skills
            if !projectSkills.isEmpty {
                let sectionLabel = NSTextField(labelWithString: "Project Skills")
                sectionLabel.font = .systemFont(ofSize: 13, weight: .semibold)
                sectionLabel.textColor = .secondaryLabelColor
                container.addArrangedSubview(sectionLabel)

                for skill in projectSkills {
                    let card = createSkillCard(skill)
                    card.translatesAutoresizingMaskIntoConstraints = false
                    container.addArrangedSubview(card)

                    NSLayoutConstraint.activate([
                        card.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 32),
                        card.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -32),
                    ])
                }
            }
        }
    }

    private func createSkillCard(_ skill: SkillInfo) -> NSView {
        let card = NSView()
        card.wantsLayer = true
        card.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        card.layer?.cornerRadius = 8
        card.layer?.borderWidth = 1
        card.layer?.borderColor = NSColor.separatorColor.cgColor

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 10),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -10),
        ])

        // Header row
        let headerStack = NSStackView()
        headerStack.orientation = .horizontal
        headerStack.spacing = 8

        let nameLabel = NSTextField(labelWithString: "/\(skill.name)")
        nameLabel.font = .monospacedSystemFont(ofSize: 13, weight: .semibold)
        headerStack.addArrangedSubview(nameLabel)

        let sourceBadge = createBadge(
            text: skill.source == "user" ? "User" : "Project",
            color: skill.source == "user" ? .systemBlue : .systemPurple
        )
        headerStack.addArrangedSubview(sourceBadge)

        stack.addArrangedSubview(headerStack)

        // Description
        let descLabel = NSTextField(labelWithString: skill.description)
        descLabel.font = .systemFont(ofSize: 12)
        descLabel.textColor = .secondaryLabelColor
        descLabel.lineBreakMode = .byTruncatingTail
        stack.addArrangedSubview(descLabel)

        return card
    }

    // MARK: - Connection Tab

    private func showConnectionTab() {
        let container = NSStackView()
        container.orientation = .vertical
        container.alignment = .leading
        container.spacing = 20
        container.translatesAutoresizingMaskIntoConstraints = false
        container.edgeInsets = NSEdgeInsets(top: 32, left: 32, bottom: 32, right: 32)
        contentContainer.addSubview(container)

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            container.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            container.bottomAnchor.constraint(lessThanOrEqualTo: contentContainer.bottomAnchor),
        ])

        // Title
        let titleLabel = NSTextField(labelWithString: "Connection")
        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        container.addArrangedSubview(titleLabel)

        let subtitleLabel = NSTextField(wrappingLabelWithString: "Status of the Claude Code CLI and Anthropic API connection.")
        subtitleLabel.font = .systemFont(ofSize: 12)
        subtitleLabel.textColor = .secondaryLabelColor
        container.addArrangedSubview(subtitleLabel)

        // Claude Code Binary
        let binaryCard = createConnectionCard()
        binaryCard.translatesAutoresizingMaskIntoConstraints = false
        container.addArrangedSubview(binaryCard)

        NSLayoutConstraint.activate([
            binaryCard.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 32),
            binaryCard.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -32),
        ])

        // Model info
        let modelCard = createInfoCard(
            title: "Active Model",
            rows: [
                ("Model", SettingsService.shared.model),
                ("Permission Mode", SettingsService.shared.permissionMode.displayName),
            ]
        )
        modelCard.translatesAutoresizingMaskIntoConstraints = false
        container.addArrangedSubview(modelCard)

        NSLayoutConstraint.activate([
            modelCard.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 32),
            modelCard.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -32),
        ])

        // API Info
        let apiCard = createInfoCard(
            title: "Anthropic API",
            rows: [
                ("Authentication", "Managed by Claude Code"),
                ("Endpoint", "api.anthropic.com"),
                ("Protocol", "Subprocess (--output-format stream-json)"),
            ]
        )
        apiCard.translatesAutoresizingMaskIntoConstraints = false
        container.addArrangedSubview(apiCard)

        NSLayoutConstraint.activate([
            apiCard.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 32),
            apiCard.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -32),
        ])
    }

    private func createConnectionCard() -> NSView {
        let card = NSView()
        card.wantsLayer = true
        card.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        card.layer?.cornerRadius = 8
        card.layer?.borderWidth = 1
        card.layer?.borderColor = NSColor.separatorColor.cgColor

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
        ])

        // Title row
        let headerStack = NSStackView()
        headerStack.orientation = .horizontal
        headerStack.spacing = 8

        let titleLabel = NSTextField(labelWithString: "Claude Code CLI")
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        headerStack.addArrangedSubview(titleLabel)

        if let binaryPath = ClaudeCodeRunner.shared.findBinary() {
            let badge = createBadge(text: "Connected", color: .systemGreen)
            headerStack.addArrangedSubview(badge)
            stack.addArrangedSubview(headerStack)

            let pathLabel = NSTextField(labelWithString: binaryPath)
            pathLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
            pathLabel.textColor = .secondaryLabelColor
            stack.addArrangedSubview(pathLabel)

            // Try to get version
            fetchClaudeVersion { version in
                DispatchQueue.main.async {
                    if let version = version {
                        let versionLabel = NSTextField(labelWithString: "Version: \(version)")
                        versionLabel.font = .systemFont(ofSize: 11)
                        versionLabel.textColor = .tertiaryLabelColor
                        stack.addArrangedSubview(versionLabel)
                    }
                }
            }
        } else {
            let badge = createBadge(text: "Not Found", color: .systemOrange)
            headerStack.addArrangedSubview(badge)
            stack.addArrangedSubview(headerStack)

            let helpLabel = NSTextField(wrappingLabelWithString: "Claude Code not found. Install via: brew install claude-code")
            helpLabel.font = .systemFont(ofSize: 12)
            helpLabel.textColor = .systemOrange
            stack.addArrangedSubview(helpLabel)
        }

        return card
    }

    private func createInfoCard(title: String, rows: [(String, String)]) -> NSView {
        let card = NSView()
        card.wantsLayer = true
        card.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        card.layer?.cornerRadius = 8
        card.layer?.borderWidth = 1
        card.layer?.borderColor = NSColor.separatorColor.cgColor

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
        ])

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        stack.addArrangedSubview(titleLabel)

        for (key, value) in rows {
            let rowStack = NSStackView()
            rowStack.orientation = .horizontal
            rowStack.spacing = 8

            let keyLabel = NSTextField(labelWithString: key)
            keyLabel.font = .systemFont(ofSize: 12, weight: .medium)
            keyLabel.textColor = .secondaryLabelColor
            keyLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
            rowStack.addArrangedSubview(keyLabel)

            let valueLabel = NSTextField(labelWithString: value)
            valueLabel.font = .systemFont(ofSize: 12)
            valueLabel.textColor = .labelColor
            rowStack.addArrangedSubview(valueLabel)

            stack.addArrangedSubview(rowStack)
        }

        return card
    }

    // MARK: - Shared Helpers

    private func createSection(title: String, description: String? = nil, content: () -> NSView) -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4

        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 13, weight: .medium)
        stack.addArrangedSubview(label)

        if let description = description {
            let descLabel = NSTextField(wrappingLabelWithString: description)
            descLabel.font = .systemFont(ofSize: 11)
            descLabel.textColor = .tertiaryLabelColor
            stack.addArrangedSubview(descLabel)
        }

        let contentView = content()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(contentView)

        contentView.widthAnchor.constraint(greaterThanOrEqualToConstant: 300).isActive = true

        return stack
    }

    private func createStatusBadge() -> NSView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 6

        let dot = NSView()
        dot.wantsLayer = true
        dot.layer?.cornerRadius = 4
        dot.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            dot.widthAnchor.constraint(equalToConstant: 8),
            dot.heightAnchor.constraint(equalToConstant: 8),
        ])

        let statusLabel = NSTextField(labelWithString: "")
        statusLabel.font = .systemFont(ofSize: 12)

        if let path = ClaudeCodeRunner.shared.findBinary() {
            dot.layer?.backgroundColor = NSColor.systemGreen.cgColor
            statusLabel.stringValue = "Claude Code found: \(path)"
            statusLabel.textColor = .systemGreen
        } else {
            dot.layer?.backgroundColor = NSColor.systemOrange.cgColor
            statusLabel.stringValue = "Claude Code not found. Install via: brew install claude-code"
            statusLabel.textColor = .systemOrange
        }

        stack.addArrangedSubview(dot)
        stack.addArrangedSubview(statusLabel)

        return stack
    }

    private func createBadge(text: String, color: NSColor) -> NSView {
        let badge = NSTextField(labelWithString: text)
        badge.font = .systemFont(ofSize: 10, weight: .medium)
        badge.textColor = color
        badge.wantsLayer = true
        badge.layer?.backgroundColor = color.withAlphaComponent(0.12).cgColor
        badge.layer?.cornerRadius = 4
        badge.alignment = .center

        // Add padding via a container
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = color.withAlphaComponent(0.12).cgColor
        container.layer?.cornerRadius = 4

        badge.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(badge)

        NSLayoutConstraint.activate([
            badge.topAnchor.constraint(equalTo: container.topAnchor, constant: 2),
            badge.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -2),
            badge.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 6),
            badge.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -6),
        ])

        badge.layer?.backgroundColor = .clear

        return container
    }

    private func createEmptyState(icon: String, title: String, message: String) -> NSView {
        let container = NSView()

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 40),
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -20),
            container.widthAnchor.constraint(greaterThanOrEqualToConstant: 400),
        ])

        // Icon
        if let image = NSImage(systemSymbolName: icon, accessibilityDescription: title) {
            let imageView = NSImageView(image: image)
            imageView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 32, weight: .light)
            imageView.contentTintColor = .tertiaryLabelColor
            stack.addArrangedSubview(imageView)
        }

        // Title
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.alignment = .center
        stack.addArrangedSubview(titleLabel)

        // Message
        let messageLabel = NSTextField(wrappingLabelWithString: message)
        messageLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        messageLabel.textColor = .tertiaryLabelColor
        messageLabel.alignment = .center
        messageLabel.maximumNumberOfLines = 0
        stack.addArrangedSubview(messageLabel)

        return container
    }

    // MARK: - Actions

    @objc private func modelChanged() {
        guard let title = modelPopup?.selectedItem?.title else { return }
        SettingsService.shared.setSetting(key: "model", value: title)
    }

    @objc private func detectClaudePath() {
        if let path = ClaudeCodeRunner.shared.findBinary() {
            claudePathField?.stringValue = path
            SettingsService.shared.setSetting(key: "claude_path", value: path)
        }
    }

    private func fetchClaudeVersion(completion: @escaping (String?) -> Void) {
        guard let binaryPath = ClaudeCodeRunner.shared.findBinary() else {
            completion(nil)
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: binaryPath)
            process.arguments = ["--version"]

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()

            do {
                try process.run()
                process.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                completion(output)
            } catch {
                completion(nil)
            }
        }
    }
}

// MARK: - NSSplitViewDelegate

extension SettingsViewController: NSSplitViewDelegate {

    func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        return 160
    }

    func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        return 220
    }

    func splitView(_ splitView: NSSplitView, shouldAdjustSizeOfSubview view: NSView) -> Bool {
        // Keep sidebar fixed width; only resize the content area
        return view != splitView.subviews.first
    }
}

// MARK: - NSTableViewDataSource

extension SettingsViewController: NSTableViewDataSource {

    func numberOfRows(in tableView: NSTableView) -> Int {
        return SettingsTab.allCases.count
    }
}

// MARK: - NSTableViewDelegate

extension SettingsViewController: NSTableViewDelegate {

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let tab = SettingsTab(rawValue: row) else { return nil }

        let cellId = NSUserInterfaceItemIdentifier("SettingsTabCell")
        let cell: NSTableCellView

        if let reused = tableView.makeView(withIdentifier: cellId, owner: self) as? NSTableCellView {
            cell = reused
        } else {
            cell = NSTableCellView()
            cell.identifier = cellId

            let imageView = NSImageView()
            imageView.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(imageView)
            cell.imageView = imageView

            let textField = NSTextField(labelWithString: "")
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.lineBreakMode = .byTruncatingTail
            cell.addSubview(textField)
            cell.textField = textField

            NSLayoutConstraint.activate([
                imageView.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 6),
                imageView.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                imageView.widthAnchor.constraint(equalToConstant: 18),
                imageView.heightAnchor.constraint(equalToConstant: 18),

                textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 6),
                textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            ])
        }

        cell.textField?.stringValue = tab.title
        cell.textField?.font = .systemFont(ofSize: 13)

        if let image = NSImage(systemSymbolName: tab.iconName, accessibilityDescription: tab.title) {
            cell.imageView?.image = image
            cell.imageView?.contentTintColor = .secondaryLabelColor
        }

        return cell
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 28
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = sidebarTableView.selectedRow
        guard row >= 0, let tab = SettingsTab(rawValue: row) else { return }
        showContent(for: tab)
    }
}

// MARK: - NSTextFieldDelegate

extension SettingsViewController: NSTextFieldDelegate {

    func controlTextDidEndEditing(_ obj: Notification) {
        guard let field = obj.object as? NSTextField else { return }
        if field == budgetField {
            SettingsService.shared.setSetting(key: "max_budget_usd", value: field.stringValue)
        } else if field == systemPromptField {
            SettingsService.shared.setSetting(key: "system_prompt", value: field.stringValue)
        } else if field == claudePathField {
            SettingsService.shared.setSetting(key: "claude_path", value: field.stringValue)
        }
    }
}

// MARK: - FlippedClipView (for top-aligned scroll)

private class FlippedClipView: NSClipView {
    override var isFlipped: Bool { true }
}
