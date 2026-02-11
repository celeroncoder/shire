import AppKit

// MARK: - StreamingItem

enum StreamingItem {
    case text(String)
    case toolCall(ToolCallBannerInfo)
}

// MARK: - CollapsibleToolCardView

final class CollapsibleToolCardView: NSView {

    private let mainStack = NSStackView()
    private let headerStack = NSStackView()
    private let iconView = NSImageView()
    private let pathLabel = NSTextField(labelWithString: "")
    private let badgeContainer = NSView()
    private let badgeLabel = NSTextField(labelWithString: "")
    private let acceptButton = NSButton()
    private let declineButton = NSButton()
    private let statusLabel = NSTextField(labelWithString: "")
    private let chevronView = NSImageView()

    private let detailScrollView = NSScrollView()
    private var detailTextView = NSTextView()
    private var detailHeightConstraint: NSLayoutConstraint!

    private let separatorBox = NSBox()
    private var isExpanded = false
    private var currentBadgeColor: NSColor = .secondaryLabelColor

    var onToggle: (() -> Void)?
    var onAccept: (() -> Void)?
    var onDecline: (() -> Void)?

    override init(frame: NSRect) {
        super.init(frame: frame)
        setupViews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupViews() {
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.3).cgColor
        layer?.borderWidth = 0.5
        layer?.borderColor = NSColor.separatorColor.cgColor
        translatesAutoresizingMaskIntoConstraints = false

        setupHeader()
        setupSeparator()
        setupDetail()

        mainStack.orientation = .vertical
        mainStack.spacing = 0
        mainStack.detachesHiddenViews = true
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        mainStack.setViews([headerStack, separatorBox, detailScrollView], in: .leading)
        separatorBox.isHidden = true
        detailScrollView.isHidden = true
        addSubview(mainStack)

        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: topAnchor),
            mainStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            mainStack.bottomAnchor.constraint(equalTo: bottomAnchor),

            headerStack.leadingAnchor.constraint(equalTo: mainStack.leadingAnchor),
            headerStack.trailingAnchor.constraint(equalTo: mainStack.trailingAnchor),

            separatorBox.leadingAnchor.constraint(equalTo: mainStack.leadingAnchor, constant: 10),
            separatorBox.trailingAnchor.constraint(equalTo: mainStack.trailingAnchor, constant: -10),

            detailScrollView.leadingAnchor.constraint(equalTo: mainStack.leadingAnchor),
            detailScrollView.trailingAnchor.constraint(equalTo: mainStack.trailingAnchor),
        ])
    }

    private func setupHeader() {
        // Icon
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.setContentHuggingPriority(.required, for: .horizontal)

        // Path label (truncates when needed)
        pathLabel.font = .monospacedSystemFont(ofSize: 11, weight: .medium)
        pathLabel.textColor = .labelColor
        pathLabel.lineBreakMode = .byTruncatingMiddle
        pathLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        pathLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        // Badge pill
        badgeContainer.wantsLayer = true
        badgeContainer.layer?.cornerRadius = 4
        badgeContainer.translatesAutoresizingMaskIntoConstraints = false
        badgeLabel.font = .systemFont(ofSize: 9, weight: .semibold)
        badgeLabel.alignment = .center
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        badgeContainer.addSubview(badgeLabel)
        badgeContainer.setContentHuggingPriority(.required, for: .horizontal)
        NSLayoutConstraint.activate([
            badgeLabel.topAnchor.constraint(equalTo: badgeContainer.topAnchor, constant: 2),
            badgeLabel.bottomAnchor.constraint(equalTo: badgeContainer.bottomAnchor, constant: -2),
            badgeLabel.leadingAnchor.constraint(equalTo: badgeContainer.leadingAnchor, constant: 6),
            badgeLabel.trailingAnchor.constraint(equalTo: badgeContainer.trailingAnchor, constant: -6),
        ])

        // Accept button
        acceptButton.bezelStyle = .inline
        acceptButton.isBordered = false
        acceptButton.wantsLayer = true
        acceptButton.layer?.cornerRadius = 4
        acceptButton.layer?.backgroundColor = NSColor.systemGreen.withAlphaComponent(0.12).cgColor
        acceptButton.contentTintColor = .systemGreen
        acceptButton.font = .systemFont(ofSize: 10, weight: .semibold)
        acceptButton.title = " Accept"
        acceptButton.image = NSImage(systemSymbolName: "checkmark", accessibilityDescription: "Accept")
        acceptButton.imagePosition = .imageLeading
        acceptButton.target = self
        acceptButton.action = #selector(acceptClicked)
        acceptButton.isHidden = true
        acceptButton.setContentHuggingPriority(.required, for: .horizontal)

        // Decline button
        declineButton.bezelStyle = .inline
        declineButton.isBordered = false
        declineButton.wantsLayer = true
        declineButton.layer?.cornerRadius = 4
        declineButton.layer?.backgroundColor = NSColor.systemRed.withAlphaComponent(0.1).cgColor
        declineButton.contentTintColor = .systemRed
        declineButton.font = .systemFont(ofSize: 10, weight: .semibold)
        declineButton.title = " Decline"
        declineButton.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Decline")
        declineButton.imagePosition = .imageLeading
        declineButton.target = self
        declineButton.action = #selector(declineClicked)
        declineButton.isHidden = true
        declineButton.setContentHuggingPriority(.required, for: .horizontal)

        // Status label (shown after accept/decline)
        statusLabel.font = .systemFont(ofSize: 10, weight: .medium)
        statusLabel.isHidden = true
        statusLabel.setContentHuggingPriority(.required, for: .horizontal)

        // Chevron
        chevronView.image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: "Expand")
        chevronView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 9, weight: .medium)
        chevronView.contentTintColor = .tertiaryLabelColor
        chevronView.translatesAutoresizingMaskIntoConstraints = false
        chevronView.setContentHuggingPriority(.required, for: .horizontal)

        // Header stack
        headerStack.orientation = .horizontal
        headerStack.alignment = .centerY
        headerStack.spacing = 8
        headerStack.edgeInsets = NSEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
        headerStack.setViews([iconView, pathLabel, badgeContainer, acceptButton, declineButton, statusLabel, chevronView], in: .leading)
        headerStack.translatesAutoresizingMaskIntoConstraints = false

        // Click gesture on header (delegate prevents stealing button clicks)
        let click = NSClickGestureRecognizer(target: self, action: #selector(toggleExpand))
        click.delegate = self
        headerStack.addGestureRecognizer(click)

        NSLayoutConstraint.activate([
            headerStack.heightAnchor.constraint(equalToConstant: 32),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),
            acceptButton.heightAnchor.constraint(equalToConstant: 22),
            declineButton.heightAnchor.constraint(equalToConstant: 22),
            chevronView.widthAnchor.constraint(equalToConstant: 10),
        ])
    }

    private func setupSeparator() {
        separatorBox.boxType = .separator
        separatorBox.translatesAutoresizingMaskIntoConstraints = false
    }

    private func setupDetail() {
        detailScrollView.hasVerticalScroller = true
        detailScrollView.autohidesScrollers = true
        detailScrollView.drawsBackground = false
        detailScrollView.translatesAutoresizingMaskIntoConstraints = false

        // Explicit TextKit 1 stack with a usable initial size so text layout
        // produces correct metrics even before the view is laid out.
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        let textContainer = NSTextContainer(size: NSSize(width: 400, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        textContainer.heightTracksTextView = false
        layoutManager.addTextContainer(textContainer)

        detailTextView = NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 0), textContainer: textContainer)
        detailTextView.isEditable = false
        detailTextView.isSelectable = true
        detailTextView.drawsBackground = false
        detailTextView.textContainerInset = NSSize(width: 8, height: 6)
        detailTextView.isVerticallyResizable = true
        detailTextView.isHorizontallyResizable = false
        detailTextView.autoresizingMask = [.width]
        detailScrollView.documentView = detailTextView

        // Subtle detail background
        detailScrollView.wantsLayer = true
        detailScrollView.layer?.backgroundColor = NSColor.secondaryLabelColor.withAlphaComponent(0.04).cgColor

        detailHeightConstraint = detailScrollView.heightAnchor.constraint(equalToConstant: 0)
        detailHeightConstraint.isActive = true
    }

    // MARK: - Configure

    func configure(
        name: String,
        input: [String: Any]?,
        operation: String,
        displayPath: String?,
        badgeColor: NSColor,
        iconName: String,
        status: ToolCallBannerInfo.ToolCallStatus? = nil,
        isAskMode: Bool = false,
        requiresPermission: Bool = false
    ) {
        // Icon
        iconView.image = NSImage(systemSymbolName: iconName, accessibilityDescription: name)
        iconView.contentTintColor = badgeColor

        // Path / command
        pathLabel.stringValue = displayPath ?? name

        // Badge
        badgeLabel.stringValue = operation.uppercased()
        badgeLabel.textColor = badgeColor
        badgeContainer.layer?.backgroundColor = badgeColor.withAlphaComponent(0.12).cgColor

        // Per-operation tint and border
        currentBadgeColor = badgeColor
        layer?.backgroundColor = badgeColor.withAlphaComponent(0.04).cgColor
        layer?.borderColor = badgeColor.withAlphaComponent(0.15).cgColor

        // Detail text — use attributed string with explicit styling so font/color
        // are guaranteed regardless of typing attributes or TextKit version.
        let detailFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        let detailColor = NSColor.secondaryLabelColor
        let detailAttrs: [NSAttributedString.Key: Any] = [.font: detailFont, .foregroundColor: detailColor]

        let text: String
        if let input = input, !input.isEmpty {
            text = Self.formatInput(input)
        } else {
            text = "No details available"
        }

        detailTextView.textStorage?.setAttributedString(NSAttributedString(string: text, attributes: detailAttrs))

        if let lm = detailTextView.layoutManager, let tc = detailTextView.textContainer {
            lm.ensureLayout(for: tc)
            let size = lm.usedRect(for: tc).size
            detailHeightConstraint.constant = min(max(size.height + 16, 30), 150)
        } else {
            // Fallback: estimate from line count
            let lineCount = max(text.components(separatedBy: "\n").count, 1)
            let estimated = CGFloat(lineCount) * 16 + 16
            detailHeightConstraint.constant = min(max(estimated, 30), 150)
        }

        // Permission buttons (streaming mode)
        if let status = status {
            switch status {
            case .pending where isAskMode && requiresPermission:
                acceptButton.isHidden = false
                declineButton.isHidden = false
                statusLabel.isHidden = true
            case .accepted:
                acceptButton.isHidden = true
                declineButton.isHidden = true
                statusLabel.isHidden = false
                statusLabel.stringValue = "Accepted"
                statusLabel.textColor = .systemGreen
            case .declined:
                acceptButton.isHidden = true
                declineButton.isHidden = true
                statusLabel.isHidden = false
                statusLabel.stringValue = "Declined"
                statusLabel.textColor = .systemRed
            case .autoAccepted:
                acceptButton.isHidden = true
                declineButton.isHidden = true
                statusLabel.isHidden = false
                statusLabel.stringValue = "Auto"
                statusLabel.textColor = .tertiaryLabelColor
            default:
                acceptButton.isHidden = true
                declineButton.isHidden = true
                statusLabel.isHidden = true
            }
        } else {
            acceptButton.isHidden = true
            declineButton.isHidden = true
            statusLabel.isHidden = true
        }
    }

    // MARK: - Actions

    @objc private func toggleExpand() {
        isExpanded.toggle()

        let chevron = isExpanded ? "chevron.down" : "chevron.right"
        chevronView.image = NSImage(systemSymbolName: chevron, accessibilityDescription: isExpanded ? "Collapse" : "Expand")

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            ctx.allowsImplicitAnimation = true
            self.separatorBox.isHidden = !self.isExpanded
            self.detailScrollView.isHidden = !self.isExpanded
            self.mainStack.layoutSubtreeIfNeeded()
        }, completionHandler: { [weak self] in
            // Second height notification after animation settles to catch edge cases
            self?.onToggle?()
        })

        onToggle?()
    }

    @objc private func acceptClicked() { onAccept?() }
    @objc private func declineClicked() { onDecline?() }

    // MARK: - Helpers

    static func formatInput(_ input: [String: Any]) -> String {
        var lines: [String] = []
        for (key, value) in input.sorted(by: { $0.key < $1.key }) {
            let valueStr = "\(value)"
            if valueStr.count > 500 {
                lines.append("\(key): \(valueStr.prefix(500))...")
            } else {
                lines.append("\(key): \(valueStr)")
            }
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - NSGestureRecognizerDelegate (prevent click stealing from buttons)

extension CollapsibleToolCardView: NSGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: NSGestureRecognizer) -> Bool {
        let location = gestureRecognizer.location(in: headerStack)
        let acceptFrame = acceptButton.convert(acceptButton.bounds, to: headerStack)
        let declineFrame = declineButton.convert(declineButton.bounds, to: headerStack)
        if !acceptButton.isHidden && acceptFrame.contains(location) { return false }
        if !declineButton.isHidden && declineFrame.contains(location) { return false }
        return true
    }
}

// MARK: - Tool Classification (shared utility)

enum ToolClassification {
    static func classify(name: String, input: [String: Any]?) -> (operation: String, displayPath: String?, iconName: String, badgeColor: NSColor) {
        switch name {
        case "Write", "write_file":
            let path = input?["file_path"] as? String ?? input?["path"] as? String
            return ("create", path, "doc.badge.plus", .systemGreen)
        case "Edit":
            let path = input?["file_path"] as? String ?? input?["path"] as? String
            return ("edit", path, "pencil", .systemOrange)
        case "Read", "read_file":
            let path = input?["file_path"] as? String ?? input?["path"] as? String
            return ("read", path, "eye", .systemBlue)
        case "Bash":
            let command = input?["command"] as? String
            return ("bash", command, "terminal", .systemPurple)
        case "Glob", "Grep":
            let pattern = input?["pattern"] as? String ?? input?["glob"] as? String
            return ("search", pattern, "magnifyingglass", .systemCyan)
        case "Task":
            let prompt = input?["prompt"] as? String
            let short = prompt.map { String($0.prefix(60)) }
            return ("task", short, "arrow.triangle.branch", .systemIndigo)
        case "WebFetch":
            let url = input?["url"] as? String
            return ("fetch", url, "globe", .systemTeal)
        case let n where n.lowercased().contains("askuser") || n.lowercased().contains("question"):
            return ("question", nil, "questionmark.circle", .systemYellow)
        default:
            // Check if input contains a questions array (generic question tool)
            if let questions = input?["questions"] as? [[String: Any]], !questions.isEmpty {
                return ("question", nil, "questionmark.circle", .systemYellow)
            }
            return (name.lowercased(), nil, "gearshape", .secondaryLabelColor)
        }
    }
}

// MARK: - ToolCallCellView (persisted messages)

final class ToolCallCellView: NSTableCellView {

    private let cardStack = NSStackView()
    private var configuredMessageId: String?

    var onCardToggle: (() -> Void)?

    init(identifier: NSUserInterfaceItemIdentifier) {
        super.init(frame: .zero)
        self.identifier = identifier
        setupViews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        cardStack.orientation = .vertical
        cardStack.alignment = .leading
        cardStack.spacing = 4
        cardStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(cardStack)

        NSLayoutConstraint.activate([
            cardStack.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            cardStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            cardStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            cardStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
        ])
    }

    func configure(with message: Message) {
        // Skip recreation if we're already showing this message's cards
        // (preserves expanded/collapsed state across reloadData calls)
        if configuredMessageId == message.id { return }
        configuredMessageId = message.id

        // Clear previous cards
        for view in cardStack.arrangedSubviews {
            cardStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        // Parse tool calls from assistant message
        if let toolCallsJSON = message.toolCalls,
           let data = toolCallsJSON.data(using: .utf8),
           let calls = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            for call in calls {
                // Check if this is a question tool call — show read-only summary
                if let summary = QuestionCardView.makePersistedSummary(from: call) {
                    cardStack.addArrangedSubview(summary)
                    summary.leadingAnchor.constraint(equalTo: cardStack.leadingAnchor).isActive = true
                    summary.trailingAnchor.constraint(equalTo: cardStack.trailingAnchor).isActive = true
                } else {
                    let card = Self.makeCollapsibleCard(from: call)
                    card.onToggle = { [weak self] in self?.onCardToggle?() }
                    cardStack.addArrangedSubview(card)
                    card.leadingAnchor.constraint(equalTo: cardStack.leadingAnchor).isActive = true
                    card.trailingAnchor.constraint(equalTo: cardStack.trailingAnchor).isActive = true
                }
            }
        } else if message.role == "tool" {
            // Tool result — show as a compact result card
            let card = makeResultCard(content: message.content)
            cardStack.addArrangedSubview(card)
            card.leadingAnchor.constraint(equalTo: cardStack.leadingAnchor).isActive = true
            card.trailingAnchor.constraint(equalTo: cardStack.trailingAnchor).isActive = true
        }
    }

    /// Build a collapsible tool card from a tool call dictionary
    static func makeCollapsibleCard(from call: [String: Any]) -> CollapsibleToolCardView {
        let name = call["name"] as? String ?? "unknown"
        let input = call["input"] as? [String: Any]
        let classified = ToolClassification.classify(name: name, input: input)

        let card = CollapsibleToolCardView()
        card.configure(
            name: name,
            input: input,
            operation: classified.operation,
            displayPath: classified.displayPath,
            badgeColor: classified.badgeColor,
            iconName: classified.iconName
        )
        return card
    }

    private func makeResultCard(content: String?) -> NSView {
        let card = NSView()
        card.wantsLayer = true
        card.layer?.cornerRadius = 8
        card.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.3).cgColor
        card.translatesAutoresizingMaskIntoConstraints = false

        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: "checkmark.circle", accessibilityDescription: "Result")
        icon.contentTintColor = .tertiaryLabelColor
        icon.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(icon)

        let label = NSTextField(labelWithString: "Tool result")
        label.font = .monospacedSystemFont(ofSize: 11, weight: .medium)
        label.textColor = .tertiaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(label)

        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(equalToConstant: 32),

            icon.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 10),
            icon.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 16),
            icon.heightAnchor.constraint(equalToConstant: 16),

            label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 8),
            label.centerYAnchor.constraint(equalTo: card.centerYAnchor),
        ])

        return card
    }
}
