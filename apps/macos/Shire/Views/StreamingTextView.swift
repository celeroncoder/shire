import AppKit
import QuartzCore

// MARK: - Bars Loader (ported from React spinner "bars" variant)

private final class BarsLoaderView: NSView {

    private var bars: [CALayer] = []

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        return NSSize(width: 14, height: 14)
    }

    override func layout() {
        super.layout()
        setupIfNeeded()
    }

    private func setupIfNeeded() {
        guard bars.isEmpty, bounds.width > 0 else { return }

        let barWidth: CGFloat = 3
        let gap: CGFloat = 1.5
        let totalWidth = barWidth * 3 + gap * 2
        let startX = (bounds.width - totalWidth) / 2
        let fullHeight = bounds.height - 2
        let shortHeight = fullHeight * 0.58
        let centerY = bounds.midY

        // Staggered offsets matching CSS: -0.8s, -0.65s, -0.5s → 0, 0.15, 0.3
        let offsets: [CFTimeInterval] = [0, 0.15, 0.3]

        for i in 0..<3 {
            let bar = CALayer()
            bar.backgroundColor = NSColor.secondaryLabelColor.cgColor
            bar.cornerRadius = 1
            bar.bounds = CGRect(x: 0, y: 0, width: barWidth, height: fullHeight)
            bar.position = CGPoint(
                x: startX + CGFloat(i) * (barWidth + gap) + barWidth / 2,
                y: centerY
            )
            layer?.addSublayer(bar)
            bars.append(bar)

            // Height: full → short → full
            let heightAnim = CAKeyframeAnimation(keyPath: "bounds.size.height")
            heightAnim.values = [fullHeight, shortHeight, fullHeight]
            heightAnim.keyTimes = [0, 0.9375, 1.0]

            // Opacity: 1 → 0.2 → 1
            let opacityAnim = CAKeyframeAnimation(keyPath: "opacity")
            opacityAnim.values = [1.0, 0.2, 1.0]
            opacityAnim.keyTimes = [0, 0.9375, 1.0]

            let group = CAAnimationGroup()
            group.animations = [heightAnim, opacityAnim]
            group.duration = 0.8
            group.repeatCount = .infinity
            group.timeOffset = offsets[i]
            group.timingFunction = CAMediaTimingFunction(name: .linear)

            bar.add(group, forKey: "bars")
        }
    }
}

// MARK: - Shimmer Status Label

private final class ShimmerLabel: NSView {

    private static let phrases = [
        "Thinking...",
        "Generating...",
        "Mulling it over...",
        "Working on it...",
        "Reasoning...",
        "Crafting a response...",
        "Processing...",
        "Pondering...",
    ]

    private var baseTextLayer: CATextLayer!
    private var brightTextLayer: CATextLayer!
    private var shimmerMask: CAGradientLayer!
    private var phraseIndex: Int = 0
    private var phraseTimer: Timer?
    private let textFont = NSFont.systemFont(ofSize: 11, weight: .medium)

    override init(frame: NSRect) {
        super.init(frame: frame)
        phraseIndex = Int.random(in: 0..<Self.phrases.count)
        wantsLayer = true
        setupLayers()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        phraseTimer?.invalidate()
    }

    override var intrinsicContentSize: NSSize {
        var maxWidth: CGFloat = 0
        for phrase in Self.phrases {
            let size = (phrase as NSString).size(withAttributes: [.font: textFont])
            maxWidth = max(maxWidth, size.width)
        }
        return NSSize(width: ceil(maxWidth) + 4, height: 16)
    }

    private func makeTextLayer(color: CGColor) -> CATextLayer {
        let tl = CATextLayer()
        tl.string = Self.phrases[phraseIndex]
        tl.font = textFont
        tl.fontSize = textFont.pointSize
        tl.foregroundColor = color
        tl.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
        tl.truncationMode = .none
        tl.isWrapped = false
        tl.alignmentMode = .left
        return tl
    }

    private func setupLayers() {
        // Base dim text — always visible
        baseTextLayer = makeTextLayer(color: NSColor.tertiaryLabelColor.cgColor)
        layer?.addSublayer(baseTextLayer)

        // Bright overlay text — masked by shimmer sweep
        brightTextLayer = makeTextLayer(color: NSColor.labelColor.withAlphaComponent(0.8).cgColor)
        layer?.addSublayer(brightTextLayer)

        // Gradient mask: transparent → white → transparent
        shimmerMask = CAGradientLayer()
        shimmerMask.colors = [
            CGColor(gray: 1, alpha: 0),
            CGColor(gray: 1, alpha: 1),
            CGColor(gray: 1, alpha: 0),
        ]
        shimmerMask.startPoint = CGPoint(x: 0, y: 0.5)
        shimmerMask.endPoint = CGPoint(x: 1, y: 0.5)
        brightTextLayer.mask = shimmerMask
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            startAnimations()
        } else {
            phraseTimer?.invalidate()
            phraseTimer = nil
        }
    }

    override func layout() {
        super.layout()
        guard bounds.width > 0 else { return }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        baseTextLayer.frame = bounds
        brightTextLayer.frame = bounds
        let bandWidth = max(bounds.width * 0.35, 40)
        shimmerMask.bounds = CGRect(x: 0, y: 0, width: bandWidth, height: bounds.height)
        shimmerMask.position = CGPoint(x: -bandWidth / 2, y: bounds.midY)
        CATransaction.commit()

        restartShimmer()
    }

    private func startAnimations() {
        restartShimmer()
        guard phraseTimer == nil else { return }
        phraseTimer = Timer.scheduledTimer(withTimeInterval: 12.0, repeats: true) { [weak self] _ in
            self?.rotatePhrase()
        }
    }

    private func restartShimmer() {
        shimmerMask.removeAnimation(forKey: "shimmer")
        guard bounds.width > 0 else { return }

        let bandWidth = max(bounds.width * 0.35, 40)
        let anim = CABasicAnimation(keyPath: "position.x")
        anim.fromValue = -bandWidth / 2
        anim.toValue = bounds.width + bandWidth / 2
        anim.duration = 1.8
        anim.repeatCount = .infinity
        anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        shimmerMask.add(anim, forKey: "shimmer")
    }

    private func rotatePhrase() {
        phraseIndex = (phraseIndex + 1) % Self.phrases.count
        let text = Self.phrases[phraseIndex]

        let fade = CATransition()
        fade.type = .fade
        fade.duration = 0.35

        baseTextLayer.add(fade, forKey: "phraseChange")
        baseTextLayer.string = text

        brightTextLayer.add(fade, forKey: "phraseChange")
        brightTextLayer.string = text
    }
}

// MARK: - Collapsible Thinking Block

private final class ThinkingBlockView: NSView {

    private let headerButton = NSButton(frame: .zero)
    private let thinkingField = NSTextField(wrappingLabelWithString: "")
    private var isCollapsed = false

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

        // Header button with disclosure chevron
        headerButton.bezelStyle = .inline
        headerButton.isBordered = false
        headerButton.contentTintColor = .secondaryLabelColor
        headerButton.font = .systemFont(ofSize: 11, weight: .medium)
        headerButton.target = self
        headerButton.action = #selector(toggleCollapse)
        updateHeaderTitle()
        headerButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(headerButton)

        // Thinking text field
        thinkingField.isEditable = false
        thinkingField.isSelectable = true
        thinkingField.drawsBackground = false
        thinkingField.isBezeled = false
        thinkingField.font = .systemFont(ofSize: 12)
        thinkingField.textColor = .secondaryLabelColor
        thinkingField.lineBreakMode = .byWordWrapping
        thinkingField.maximumNumberOfLines = 0
        thinkingField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
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

    private func updateHeaderTitle() {
        let chevron = isCollapsed ? "chevron.right" : "chevron.down"
        if let chevronImage = NSImage(systemSymbolName: chevron, accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 9, weight: .medium)
            let tinted = chevronImage.withSymbolConfiguration(config)!
            headerButton.image = tinted
            headerButton.imagePosition = .imageLeading
        }
        headerButton.title = "Thinking"
    }

    @objc private func toggleCollapse() {
        isCollapsed.toggle()
        updateHeaderTitle()

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

    func setCollapsedState(_ collapsed: Bool) {
        isCollapsed = collapsed
        updateHeaderTitle()
        thinkingField.isHidden = collapsed
    }
}

// MARK: - StreamingTextView

final class StreamingTextView: NSTableCellView {

    private let roleLabel = NSTextField(labelWithString: "Shire")
    private let thinkingBlock = ThinkingBlockView(frame: .zero)
    private let contentStack = NSStackView()
    private let barsLoader = BarsLoaderView(frame: .zero)
    private let shimmerLabel = ShimmerLabel(frame: .zero)
    private let statusRow: NSStackView

    private var renderedItemCount = 0
    private var currentTextFields: [RichTextView] = []
    private var thinkingAutoCollapsed = false

    var onThinkingToggle: (() -> Void)?
    var onAcceptToolCall: ((Int) -> Void)?
    var onDeclineToolCall: ((Int) -> Void)?
    var onSubmitQuestion: ((Int, [[String]]) -> Void)?
    var onStop: (() -> Void)?
    var onCardToggle: (() -> Void)?

    init(identifier: NSUserInterfaceItemIdentifier) {
        statusRow = NSStackView(views: [barsLoader, shimmerLabel])
        super.init(frame: .zero)
        self.identifier = identifier
        setupViews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        // Role label
        roleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        roleLabel.textColor = .systemPurple
        roleLabel.setContentHuggingPriority(.required, for: .vertical)

        // Thinking block — starts hidden
        thinkingBlock.isHidden = true
        thinkingBlock.translatesAutoresizingMaskIntoConstraints = false
        thinkingBlock.onToggle = { [weak self] in
            self?.onThinkingToggle?()
        }

        // Content stack for interleaved text + tool cards
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 8
        contentStack.detachesHiddenViews = true
        contentStack.isHidden = true
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        // Bars loader
        barsLoader.translatesAutoresizingMaskIntoConstraints = false

        // Shimmer label
        shimmerLabel.translatesAutoresizingMaskIntoConstraints = false

        // Status row: [bars] [shimmer label]
        statusRow.orientation = .horizontal
        statusRow.alignment = .centerY
        statusRow.spacing = 6

        // Vertical stack
        let mainStack = NSStackView(views: [roleLabel, thinkingBlock, contentStack, statusRow])
        mainStack.orientation = .vertical
        mainStack.alignment = .leading
        mainStack.spacing = 8
        mainStack.detachesHiddenViews = true
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(mainStack)

        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            mainStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            mainStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            mainStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),

            thinkingBlock.leadingAnchor.constraint(equalTo: mainStack.leadingAnchor),
            thinkingBlock.trailingAnchor.constraint(equalTo: mainStack.trailingAnchor),

            contentStack.leadingAnchor.constraint(equalTo: mainStack.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: mainStack.trailingAnchor),

            barsLoader.widthAnchor.constraint(equalToConstant: 14),
            barsLoader.heightAnchor.constraint(equalToConstant: 14),

            shimmerLabel.heightAnchor.constraint(equalToConstant: 16),
        ])
    }

    // MARK: - Configure with interleaved items

    func configure(thinkingText: String, items: [StreamingItem], isAskMode: Bool, workspacePath: String? = nil) {
        // Reset if this cell is being reused from a previous streaming session
        // (items shrink only when a new session starts with a fresh array)
        if items.count < renderedItemCount {
            reset()
        }

        // Thinking
        if thinkingText.isEmpty {
            thinkingBlock.isHidden = true
        } else {
            thinkingBlock.isHidden = false
            thinkingBlock.setText(thinkingText)
        }

        // Content items
        let hasContent = items.contains(where: {
            if case .text(let t) = $0 { return !t.isEmpty }
            return true
        })
        contentStack.isHidden = !hasContent

        // Add new items that don't have views yet
        for i in renderedItemCount..<items.count {
            switch items[i] {
            case .text:
                let field = makeTextField()
                contentStack.addArrangedSubview(field)
                currentTextFields.append(field)
                // Full width
                field.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor).isActive = true
                field.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor).isActive = true

            case .toolCall(let info):
                let itemIndex = i

                if QuestionCardView.isQuestionToolCall(info) {
                    // Question is rendered as overlay above composer (handled by ChatViewController)
                    // Add zero-height placeholder to keep view indices aligned with item indices
                    let placeholder = NSView()
                    placeholder.translatesAutoresizingMaskIntoConstraints = false
                    placeholder.heightAnchor.constraint(equalToConstant: 0).isActive = true
                    contentStack.addArrangedSubview(placeholder)
                } else {
                    // Regular tool card
                    let classified = ToolClassification.classify(name: info.toolName, input: info.inputDetails)
                    let card = CollapsibleToolCardView()
                    card.configure(
                        name: info.toolName,
                        input: info.inputDetails,
                        operation: classified.operation,
                        displayPath: classified.displayPath ?? info.filePath,
                        badgeColor: classified.badgeColor,
                        iconName: classified.iconName,
                        status: info.status,
                        isAskMode: isAskMode,
                        requiresPermission: info.requiresPermission
                    )
                    card.onAccept = { [weak self] in self?.onAcceptToolCall?(itemIndex) }
                    card.onDecline = { [weak self] in self?.onDeclineToolCall?(itemIndex) }
                    card.onToggle = { [weak self] in self?.onCardToggle?() }
                    contentStack.addArrangedSubview(card)
                    card.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor).isActive = true
                    card.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor).isActive = true
                }
            }
            renderedItemCount += 1
        }

        // Update all text fields with current content
        var textIndex = 0
        for item in items {
            if case .text(let text) = item {
                if textIndex < currentTextFields.count && !text.isEmpty {
                    currentTextFields[textIndex].setRichText(MarkdownRenderer.render(text, workspacePath: workspacePath))
                }
                textIndex += 1
            }
        }

        // Update tool call statuses (for accept/decline changes)
        // Skip QuestionCardView instances — they manage their own state
        for (i, item) in items.enumerated() {
            if case .toolCall(let info) = item, i < renderedItemCount {
                let viewIndex = i
                if viewIndex < contentStack.arrangedSubviews.count,
                   let card = contentStack.arrangedSubviews[viewIndex] as? CollapsibleToolCardView {
                    let classified = ToolClassification.classify(name: info.toolName, input: info.inputDetails)
                    card.configure(
                        name: info.toolName,
                        input: info.inputDetails,
                        operation: classified.operation,
                        displayPath: classified.displayPath ?? info.filePath,
                        badgeColor: classified.badgeColor,
                        iconName: classified.iconName,
                        status: info.status,
                        isAskMode: isAskMode,
                        requiresPermission: info.requiresPermission
                    )
                }
            }
        }

        // Auto-collapse thinking once response text starts arriving
        if hasContent && !thinkingBlock.isHidden && !thinkingAutoCollapsed {
            thinkingAutoCollapsed = true
            thinkingBlock.setCollapsedState(true)
        }
    }

    func reset() {
        for v in contentStack.arrangedSubviews {
            contentStack.removeArrangedSubview(v)
            v.removeFromSuperview()
        }
        currentTextFields = []
        renderedItemCount = 0
        thinkingAutoCollapsed = false
        thinkingBlock.isHidden = true
        contentStack.isHidden = true
    }

    // MARK: - Helpers

    private func makeTextField() -> RichTextView {
        let view = RichTextView()
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }
}
