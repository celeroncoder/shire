import AppKit

/// Represents a tool call that modifies files, shown as a visual banner
struct ToolCallBannerInfo {
    let id: String?
    let toolName: String       // "Write", "Edit", "Bash", etc.
    let filePath: String?      // Extracted from tool arguments
    let operation: String      // "create", "edit", "write", "execute"
    var status: ToolCallStatus
    var inputDetails: [String: Any]?  // Full input dict for collapsible detail view

    enum ToolCallStatus {
        case pending       // Awaiting decision (shown during streaming)
        case accepted      // User accepted
        case declined      // User declined
        case autoAccepted  // Auto-accepted (accept edits / bypass mode)
    }

    /// SF Symbol name for this tool type
    var iconName: String {
        switch operation.lowercased() {
        case "read": return "eye"
        case "search": return "magnifyingglass"
        case "bash": return "terminal"
        case "create", "write": return "doc.badge.plus"
        case "edit": return "pencil"
        default: return "gearshape"
        }
    }

    /// Short badge text
    var badgeText: String {
        operation.uppercased()
    }

    /// Badge tint color
    var badgeColor: NSColor {
        switch operation.lowercased() {
        case "read": return .systemBlue
        case "search": return .systemCyan
        case "bash": return .systemPurple
        case "create", "write": return .systemGreen
        case "edit": return .systemOrange
        default: return .secondaryLabelColor
        }
    }

    /// Whether this tool requires accept/decline in ask mode
    var requiresPermission: Bool {
        let op = operation.lowercased()
        return op == "create" || op == "write" || op == "edit"
    }
}

/// Rich inline banner for Write/Edit tool calls with accept/decline/stop actions
final class PermissionBannerView: NSTableCellView {

    var onAccept: (() -> Void)?
    var onDecline: (() -> Void)?
    var onStop: (() -> Void)?

    private let card = NSView()
    private let fileIconView = NSImageView()
    private let filePathLabel = NSTextField(labelWithString: "")
    private let operationBadge = NSView()
    private let operationLabel = NSTextField(labelWithString: "")
    private let acceptButton = NSButton()
    private let declineButton = NSButton()
    private let stopButton = NSButton()
    private let statusIndicator = NSTextField(labelWithString: "")
    private let buttonStack = NSStackView()
    private var pulseLayer: CALayer?

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
        // Card container with rounded corners and subtle border
        card.wantsLayer = true
        card.layer?.cornerRadius = 10
        card.layer?.borderWidth = 1
        card.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.4).cgColor
        card.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.6).cgColor
        card.translatesAutoresizingMaskIntoConstraints = false
        addSubview(card)

        // File icon
        fileIconView.image = NSImage(systemSymbolName: "doc.text.fill", accessibilityDescription: "File")
        fileIconView.contentTintColor = .secondaryLabelColor
        fileIconView.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(fileIconView)

        // File path label
        filePathLabel.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
        filePathLabel.textColor = .labelColor
        filePathLabel.lineBreakMode = .byTruncatingMiddle
        filePathLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        filePathLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(filePathLabel)

        // Operation badge (pill shape)
        operationBadge.wantsLayer = true
        operationBadge.layer?.cornerRadius = 4
        operationBadge.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(operationBadge)

        operationLabel.font = .systemFont(ofSize: 10, weight: .semibold)
        operationLabel.alignment = .center
        operationLabel.translatesAutoresizingMaskIntoConstraints = false
        operationBadge.addSubview(operationLabel)

        // Accept button
        acceptButton.bezelStyle = .inline
        acceptButton.isBordered = false
        acceptButton.wantsLayer = true
        acceptButton.layer?.cornerRadius = 6
        acceptButton.layer?.backgroundColor = NSColor.systemGreen.withAlphaComponent(0.12).cgColor
        acceptButton.contentTintColor = .systemGreen
        acceptButton.font = .systemFont(ofSize: 11, weight: .semibold)
        acceptButton.title = " Accept"
        acceptButton.image = NSImage(systemSymbolName: "checkmark", accessibilityDescription: "Accept")
        acceptButton.imagePosition = .imageLeading
        acceptButton.target = self
        acceptButton.action = #selector(acceptClicked)
        acceptButton.translatesAutoresizingMaskIntoConstraints = false

        // Decline button
        declineButton.bezelStyle = .inline
        declineButton.isBordered = false
        declineButton.wantsLayer = true
        declineButton.layer?.cornerRadius = 6
        declineButton.layer?.backgroundColor = NSColor.systemRed.withAlphaComponent(0.1).cgColor
        declineButton.contentTintColor = .systemRed
        declineButton.font = .systemFont(ofSize: 11, weight: .semibold)
        declineButton.title = " Decline"
        declineButton.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Decline")
        declineButton.imagePosition = .imageLeading
        declineButton.target = self
        declineButton.action = #selector(declineClicked)
        declineButton.translatesAutoresizingMaskIntoConstraints = false

        // Stop button
        stopButton.bezelStyle = .inline
        stopButton.isBordered = false
        stopButton.wantsLayer = true
        stopButton.layer?.cornerRadius = 6
        stopButton.layer?.backgroundColor = NSColor.systemOrange.withAlphaComponent(0.1).cgColor
        stopButton.contentTintColor = .systemOrange
        stopButton.font = .systemFont(ofSize: 11, weight: .semibold)
        stopButton.title = " Stop"
        stopButton.image = NSImage(systemSymbolName: "stop.fill", accessibilityDescription: "Stop")
        stopButton.imagePosition = .imageLeading
        stopButton.target = self
        stopButton.action = #selector(stopClicked)
        stopButton.translatesAutoresizingMaskIntoConstraints = false

        // Status indicator (shown after action taken)
        statusIndicator.font = .systemFont(ofSize: 11, weight: .medium)
        statusIndicator.isHidden = true
        statusIndicator.translatesAutoresizingMaskIntoConstraints = false

        // Button stack
        buttonStack.setViews([acceptButton, declineButton, stopButton, statusIndicator], in: .leading)
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 8
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(buttonStack)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            card.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            card.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            card.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),

            fileIconView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            fileIconView.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            fileIconView.widthAnchor.constraint(equalToConstant: 18),
            fileIconView.heightAnchor.constraint(equalToConstant: 18),

            filePathLabel.leadingAnchor.constraint(equalTo: fileIconView.trailingAnchor, constant: 8),
            filePathLabel.centerYAnchor.constraint(equalTo: fileIconView.centerYAnchor),
            filePathLabel.trailingAnchor.constraint(lessThanOrEqualTo: operationBadge.leadingAnchor, constant: -8),

            operationBadge.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            operationBadge.centerYAnchor.constraint(equalTo: fileIconView.centerYAnchor),

            operationLabel.topAnchor.constraint(equalTo: operationBadge.topAnchor, constant: 2),
            operationLabel.bottomAnchor.constraint(equalTo: operationBadge.bottomAnchor, constant: -2),
            operationLabel.leadingAnchor.constraint(equalTo: operationBadge.leadingAnchor, constant: 8),
            operationLabel.trailingAnchor.constraint(equalTo: operationBadge.trailingAnchor, constant: -8),

            buttonStack.topAnchor.constraint(equalTo: fileIconView.bottomAnchor, constant: 10),
            buttonStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            buttonStack.trailingAnchor.constraint(lessThanOrEqualTo: card.trailingAnchor, constant: -12),
            buttonStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -10),

            acceptButton.heightAnchor.constraint(equalToConstant: 26),
            declineButton.heightAnchor.constraint(equalToConstant: 26),
            stopButton.heightAnchor.constraint(equalToConstant: 26),
        ])
    }

    func configure(with info: ToolCallBannerInfo, isAskMode: Bool) {
        // Icon and path — use computed properties from ToolCallBannerInfo
        fileIconView.image = NSImage(systemSymbolName: info.iconName, accessibilityDescription: info.toolName)
        fileIconView.contentTintColor = info.badgeColor
        filePathLabel.stringValue = info.filePath ?? info.toolName

        // Operation badge
        operationLabel.stringValue = info.badgeText
        operationLabel.textColor = info.badgeColor
        operationBadge.layer?.backgroundColor = info.badgeColor.withAlphaComponent(0.12).cgColor

        // Update card border and buttons based on status
        switch info.status {
        case .pending:
            card.layer?.borderColor = info.badgeColor.withAlphaComponent(0.4).cgColor
            card.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.6).cgColor
            let showPermissionButtons = isAskMode && info.requiresPermission
            acceptButton.isHidden = !showPermissionButtons
            declineButton.isHidden = !showPermissionButtons
            stopButton.isHidden = false
            statusIndicator.isHidden = true
            if showPermissionButtons {
                acceptButton.alphaValue = 1.0
                declineButton.alphaValue = 1.0
                addPulse()
            } else {
                removePulse()
            }

        case .accepted:
            card.layer?.borderColor = NSColor.systemGreen.withAlphaComponent(0.4).cgColor
            card.layer?.backgroundColor = NSColor.systemGreen.withAlphaComponent(0.04).cgColor
            showButtons(false)
            statusIndicator.isHidden = false
            statusIndicator.stringValue = "Accepted"
            statusIndicator.textColor = .systemGreen
            removePulse()

        case .declined:
            card.layer?.borderColor = NSColor.systemRed.withAlphaComponent(0.4).cgColor
            card.layer?.backgroundColor = NSColor.systemRed.withAlphaComponent(0.04).cgColor
            showButtons(false)
            statusIndicator.isHidden = false
            statusIndicator.stringValue = "Declined"
            statusIndicator.textColor = .systemRed
            removePulse()

        case .autoAccepted:
            card.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.3).cgColor
            card.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.4).cgColor
            showButtons(false)
            statusIndicator.isHidden = false
            statusIndicator.stringValue = "Auto-accepted"
            statusIndicator.textColor = .tertiaryLabelColor
            removePulse()
        }
    }

    private func showButtons(_ show: Bool) {
        acceptButton.isHidden = !show
        declineButton.isHidden = !show
        stopButton.isHidden = !show
    }

    private func addPulse() {
        guard pulseLayer == nil else { return }
        let pulse = CALayer()
        pulse.cornerRadius = 10
        pulse.borderWidth = 2
        pulse.borderColor = NSColor.systemBlue.withAlphaComponent(0.3).cgColor
        pulse.frame = card.bounds.insetBy(dx: -1, dy: -1)
        card.layer?.addSublayer(pulse)
        pulseLayer = pulse

        let anim = CABasicAnimation(keyPath: "opacity")
        anim.fromValue = 0.8
        anim.toValue = 0.2
        anim.duration = 1.2
        anim.repeatCount = .infinity
        anim.autoreverses = true
        pulse.add(anim, forKey: "pulse")
    }

    private func removePulse() {
        pulseLayer?.removeFromSuperlayer()
        pulseLayer = nil
    }

    override func layout() {
        super.layout()
        pulseLayer?.frame = card.bounds.insetBy(dx: -1, dy: -1)
    }

    @objc private func acceptClicked() {
        onAccept?()
    }

    @objc private func declineClicked() {
        onDecline?()
    }

    @objc private func stopClicked() {
        onStop?()
    }
}
