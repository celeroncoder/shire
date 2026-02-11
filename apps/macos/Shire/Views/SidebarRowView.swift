import AppKit

final class SidebarRowView: NSTableCellView {

    private let iconView = NSImageView()
    private let label = NSTextField(labelWithString: "")
    private let addButton = NSButton()
    private let spinner = NSProgressIndicator()
    var onAddSession: (() -> Void)?

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
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyUpOrDown
        addSubview(iconView)

        label.translatesAutoresizingMaskIntoConstraints = false
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1
        addSubview(label)
        self.textField = label

        addButton.image = NSImage(systemSymbolName: "plus", accessibilityDescription: "New Session")
        addButton.bezelStyle = .inline
        addButton.isBordered = false
        addButton.isHidden = true
        addButton.target = self
        addButton.action = #selector(addSessionClicked)
        addButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(addButton)

        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.isDisplayedWhenStopped = false
        spinner.translatesAutoresizingMaskIntoConstraints = false
        addSubview(spinner)

        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: iconView.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),
            spinner.widthAnchor.constraint(equalToConstant: 14),
            spinner.heightAnchor.constraint(equalToConstant: 14),

            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),

            label.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 6),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.trailingAnchor.constraint(lessThanOrEqualTo: addButton.leadingAnchor, constant: -4),

            addButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            addButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            addButton.widthAnchor.constraint(equalToConstant: 16),
            addButton.heightAnchor.constraint(equalToConstant: 16),
        ])

        // Track mouse for hover
        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }

    func configure(workspace: Workspace) {
        label.stringValue = workspace.name
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .labelColor
        iconView.image = NSImage(systemSymbolName: "folder.fill", accessibilityDescription: "Workspace")
        iconView.contentTintColor = .systemBlue
        addButton.isHidden = true // shown on hover
    }

    func configure(session: Session) {
        label.stringValue = session.title ?? "New Chat"
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        iconView.image = NSImage(systemSymbolName: "bubble.left", accessibilityDescription: "Chat")
        iconView.contentTintColor = .tertiaryLabelColor
        addButton.isHidden = true
        setStreaming(false)
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

    @objc private func addSessionClicked() {
        onAddSession?()
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        // Show add button only for workspace rows
        if iconView.contentTintColor == .systemBlue {
            addButton.isHidden = false
        }
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        addButton.isHidden = true
    }
}
