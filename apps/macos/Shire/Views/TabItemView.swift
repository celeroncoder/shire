import AppKit

final class TabItemView: NSView {

    var isActive = false { didSet { updateAppearance() } }
    var onSelect: (() -> Void)?
    var onClose: (() -> Void)?

    private let iconView = NSImageView()
    private let spinner = NSProgressIndicator()
    private let titleLabel = NSTextField(labelWithString: "")
    private let closeButton: NSButton
    private let bottomBar = NSView()
    private var trackingArea: NSTrackingArea?
    private var isHovered = false

    init(title: String) {
        closeButton = NSButton(
            image: NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close tab")!,
            target: nil,
            action: nil
        )
        super.init(frame: .zero)

        wantsLayer = true
        layer?.masksToBounds = true

        // Icon
        iconView.image = NSImage(systemSymbolName: "bubble.left.fill", accessibilityDescription: nil)
        iconView.contentTintColor = .tertiaryLabelColor
        iconView.imageScaling = .scaleProportionallyDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconView)

        // Spinner (overlays icon position)
        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.isDisplayedWhenStopped = false
        spinner.translatesAutoresizingMaskIntoConstraints = false
        addSubview(spinner)

        // Title
        titleLabel.stringValue = title
        titleLabel.font = .systemFont(ofSize: 11, weight: .medium)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.isEditable = false
        titleLabel.isBordered = false
        titleLabel.drawsBackground = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        // Close button
        closeButton.bezelStyle = .inline
        closeButton.isBordered = false
        closeButton.imageScaling = .scaleProportionallyDown
        closeButton.contentTintColor = .tertiaryLabelColor
        closeButton.target = self
        closeButton.action = #selector(handleClose)
        closeButton.alphaValue = 0
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(closeButton)

        // Bottom accent bar (active indicator)
        bottomBar.wantsLayer = true
        bottomBar.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
        bottomBar.isHidden = true
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bottomBar)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(greaterThanOrEqualToConstant: 100),
            widthAnchor.constraint(lessThanOrEqualToConstant: 200),

            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 12),
            iconView.heightAnchor.constraint(equalToConstant: 12),

            spinner.centerXAnchor.constraint(equalTo: iconView.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),
            spinner.widthAnchor.constraint(equalToConstant: 12),
            spinner.heightAnchor.constraint(equalToConstant: 12),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 5),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -4),

            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            closeButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 16),
            closeButton.heightAnchor.constraint(equalToConstant: 16),

            bottomBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: bottomAnchor),
            bottomBar.heightAnchor.constraint(equalToConstant: 2),
        ])

        updateAppearance()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateTitle(_ title: String) {
        titleLabel.stringValue = title
    }

    func setStreaming(_ streaming: Bool) {
        if streaming {
            iconView.isHidden = true
            spinner.startAnimation(nil)
        } else {
            iconView.isHidden = false
            spinner.stopAnimation(nil)
        }
    }

    // MARK: - Mouse Tracking

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea { removeTrackingArea(existing) }
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        updateAppearance()
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        updateAppearance()
    }

    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        if closeButton.frame.contains(location) { return }
        onSelect?()
    }

    @objc private func handleClose() {
        onClose?()
    }

    // MARK: - Appearance

    private func updateAppearance() {
        if isActive {
            layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.08).cgColor
            titleLabel.textColor = .labelColor
            titleLabel.font = .systemFont(ofSize: 11, weight: .semibold)
            iconView.contentTintColor = .controlAccentColor
            bottomBar.isHidden = false
            closeButton.alphaValue = 1
        } else {
            layer?.backgroundColor = isHovered
                ? NSColor.labelColor.withAlphaComponent(0.04).cgColor
                : nil
            titleLabel.textColor = .secondaryLabelColor
            titleLabel.font = .systemFont(ofSize: 11, weight: .medium)
            iconView.contentTintColor = .tertiaryLabelColor
            bottomBar.isHidden = true
            closeButton.alphaValue = isHovered ? 0.7 : 0
        }
    }
}
