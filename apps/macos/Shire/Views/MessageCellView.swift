import AppKit

// MARK: - Collapsible Thinking Section (for persisted messages)

private final class ThinkingSectionView: NSView {

    private let headerButton = NSButton(frame: .zero)
    private let thinkingField = NSTextField(wrappingLabelWithString: "")
    private var isCollapsed = false  // Start EXPANDED so thinking is visible in history

    var onToggle: (() -> Void)?

    override init(frame: NSRect) {
        super.init(frame: frame)
        setupViews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.backgroundColor = NSColor.systemPurple.withAlphaComponent(0.04).cgColor

        // Header button
        headerButton.bezelStyle = .inline
        headerButton.isBordered = false
        headerButton.contentTintColor = .secondaryLabelColor
        headerButton.font = .systemFont(ofSize: 11, weight: .medium)
        headerButton.target = self
        headerButton.action = #selector(toggleCollapse)
        updateHeader()
        headerButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(headerButton)

        // Thinking text (visible by default)
        thinkingField.isEditable = false
        thinkingField.isSelectable = true
        thinkingField.drawsBackground = false
        thinkingField.isBezeled = false
        thinkingField.font = .systemFont(ofSize: 12)
        thinkingField.textColor = .secondaryLabelColor
        thinkingField.lineBreakMode = .byWordWrapping
        thinkingField.maximumNumberOfLines = 0
        thinkingField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        thinkingField.isHidden = false  // Visible by default
        thinkingField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(thinkingField)

        NSLayoutConstraint.activate([
            headerButton.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            headerButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            headerButton.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -8),

            thinkingField.topAnchor.constraint(equalTo: headerButton.bottomAnchor, constant: 4),
            thinkingField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            thinkingField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            thinkingField.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
        ])
    }

    private func updateHeader() {
        let chevron = isCollapsed ? "chevron.right" : "chevron.down"
        if let chevronImage = NSImage(systemSymbolName: chevron, accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 9, weight: .medium)
            headerButton.image = chevronImage.withSymbolConfiguration(config)
            headerButton.imagePosition = .imageLeading
        }
        headerButton.title = "Thinking"
    }

    @objc private func toggleCollapse() {
        isCollapsed.toggle()
        updateHeader()

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            ctx.allowsImplicitAnimation = true
            self.thinkingField.isHidden = self.isCollapsed
            self.superview?.layoutSubtreeIfNeeded()
        }, completionHandler: { [weak self] in
            self?.onToggle?()
        })

        onToggle?()
    }

    func setText(_ text: String) {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 2

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: style,
        ]
        thinkingField.attributedStringValue = NSAttributedString(string: text, attributes: attrs)
    }
}

// MARK: - MessageCellView

final class MessageCellView: NSTableCellView {

    private let roleLabel = NSTextField(labelWithString: "")
    private let thinkingSection = ThinkingSectionView(frame: .zero)
    private let contentLabel = RichTextView()
    private let toolCallStack = NSStackView()
    private let stack = NSStackView()
    private var configuredMessageId: String?

    var onThinkingToggle: (() -> Void)?
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
        roleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        roleLabel.setContentHuggingPriority(.required, for: .vertical)

        thinkingSection.isHidden = true
        thinkingSection.translatesAutoresizingMaskIntoConstraints = false
        thinkingSection.onToggle = { [weak self] in
            self?.onThinkingToggle?()
        }

        contentLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        contentLabel.translatesAutoresizingMaskIntoConstraints = false

        toolCallStack.orientation = .vertical
        toolCallStack.alignment = .leading
        toolCallStack.spacing = 4
        toolCallStack.isHidden = true
        toolCallStack.translatesAutoresizingMaskIntoConstraints = false

        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.detachesHiddenViews = true
        stack.setViews([roleLabel, thinkingSection, contentLabel, toolCallStack], in: .leading)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),

            thinkingSection.leadingAnchor.constraint(equalTo: stack.leadingAnchor),
            thinkingSection.trailingAnchor.constraint(equalTo: stack.trailingAnchor),

            contentLabel.leadingAnchor.constraint(equalTo: stack.leadingAnchor),
            contentLabel.trailingAnchor.constraint(equalTo: stack.trailingAnchor),

            toolCallStack.leadingAnchor.constraint(equalTo: stack.leadingAnchor),
            toolCallStack.trailingAnchor.constraint(equalTo: stack.trailingAnchor),
        ])
    }

    func configure(with message: Message, workspacePath: String? = nil) {
        // Skip full reconfiguration if already showing this message
        // (preserves expanded/collapsed state across reloadData calls)
        if configuredMessageId == message.id { return }
        configuredMessageId = message.id

        let isUser = message.role == "user"

        roleLabel.stringValue = isUser ? "You" : "Shire"
        roleLabel.textColor = isUser ? .systemBlue : .systemPurple

        // Thinking section (assistant only) — visible by default when present
        if !isUser, let thinking = message.thinkingContent, !thinking.isEmpty {
            thinkingSection.isHidden = false
            thinkingSection.setText(thinking)
        } else {
            thinkingSection.isHidden = true
        }

        // Content
        if let content = message.content, !content.isEmpty {
            contentLabel.isHidden = false
            if isUser {
                contentLabel.setRichText(NSAttributedString(string: content, attributes: [
                    .font: NSFont.systemFont(ofSize: 13),
                    .foregroundColor: NSColor.labelColor,
                ]))
            } else {
                contentLabel.setRichText(MarkdownRenderer.render(content, workspacePath: workspacePath))
            }
        } else {
            contentLabel.isHidden = true
        }

        // Tool call collapsible cards (assistant messages with toolCalls)
        for v in toolCallStack.arrangedSubviews {
            toolCallStack.removeArrangedSubview(v)
            v.removeFromSuperview()
        }
        if !isUser,
           let toolCallsJSON = message.toolCalls,
           let data = toolCallsJSON.data(using: .utf8),
           let calls = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
           !calls.isEmpty {
            toolCallStack.isHidden = false
            for call in calls {
                // Question tool calls get a read-only summary card
                if let summary = QuestionCardView.makePersistedSummary(from: call) {
                    toolCallStack.addArrangedSubview(summary)
                    summary.leadingAnchor.constraint(equalTo: toolCallStack.leadingAnchor).isActive = true
                    summary.trailingAnchor.constraint(equalTo: toolCallStack.trailingAnchor).isActive = true
                } else {
                    let card = ToolCallCellView.makeCollapsibleCard(from: call)
                    card.onToggle = { [weak self] in self?.onCardToggle?() }
                    toolCallStack.addArrangedSubview(card)
                    card.leadingAnchor.constraint(equalTo: toolCallStack.leadingAnchor).isActive = true
                    card.trailingAnchor.constraint(equalTo: toolCallStack.trailingAnchor).isActive = true
                }
            }
        } else {
            toolCallStack.isHidden = true
        }
    }
}
