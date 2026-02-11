import AppKit

/// NSTextView subclass that preserves rich text formatting permanently.
///
/// Unlike the old NSTextField approach, NSTextView owns its own NSTextStorage
/// directly — no shared "field editor" that strips custom attributes when the
/// user clicks to select text. This eliminates the bug where file-path styling
/// (teal, underlined, clickable) disappeared on click.
///
/// NSTextView also provides built-in link handling: pointing-hand cursor on
/// hover, and a delegate callback on click — no manual NSLayoutManager
/// hit-testing needed.
///
/// Uses an explicit TextKit 1 stack so `layoutManager` is always available
/// for intrinsic content size calculation (TextKit 2, the default on macOS 12+,
/// uses `textLayoutManager` instead, which causes `layoutManager` to be nil).
final class RichTextView: NSTextView, NSTextViewDelegate {

    private var lastWidth: CGFloat = 0

    convenience init() {
        // Build an explicit TextKit 1 stack so layoutManager is never nil.
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        let textContainer = NSTextContainer(size: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        textContainer.lineFragmentPadding = 0
        layoutManager.addTextContainer(textContainer)

        self.init(frame: .zero, textContainer: textContainer)
    }

    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        commonInit()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func commonInit() {
        isEditable = false
        isSelectable = true
        drawsBackground = false
        isVerticallyResizable = false
        isHorizontallyResizable = false
        textContainer?.widthTracksTextView = true
        textContainer?.lineFragmentPadding = 0
        textContainerInset = .zero

        // Preserve our custom link styling — empty dict prevents NSTextView
        // from overlaying default blue-underline on top of our teal styling.
        linkTextAttributes = [:]
        isAutomaticLinkDetectionEnabled = false

        delegate = self
    }

    // MARK: - Auto-sizing for Stack Views

    override var intrinsicContentSize: NSSize {
        guard let layoutManager = layoutManager,
              let textContainer = textContainer else {
            return NSSize(width: NSView.noIntrinsicMetric, height: 0)
        }

        // Before the view has been laid out, bounds.width is 0. Computing text
        // layout at width 0 wraps every character onto its own line, producing a
        // wildly inflated height that the table view locks in. Return a compact
        // placeholder until the real width is established — setFrameSize will
        // call invalidateIntrinsicContentSize once the frame is set.
        guard bounds.width > 0 else {
            return NSSize(width: NSView.noIntrinsicMetric, height: 18)
        }

        layoutManager.ensureLayout(for: textContainer)
        let rect = layoutManager.usedRect(for: textContainer)
        return NSSize(
            width: NSView.noIntrinsicMetric,
            height: ceil(rect.height + textContainerInset.height * 2)
        )
    }

    override func setFrameSize(_ newSize: NSSize) {
        let widthChanged = newSize.width != lastWidth
        lastWidth = newSize.width
        super.setFrameSize(newSize)
        if widthChanged {
            invalidateIntrinsicContentSize()
        }
    }

    /// Set rich text content and trigger re-layout.
    func setRichText(_ attributedString: NSAttributedString) {
        textStorage?.setAttributedString(attributedString)
        invalidateIntrinsicContentSize()
    }

    // MARK: - Link Handling (NSTextViewDelegate)

    func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
        guard let url = link as? URL else { return false }

        if url.scheme == "shire-file" {
            let filePath = url.path
            let lineNumber = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "line" })?.value

            var userInfo: [String: Any] = ["filePath": filePath]
            if let line = lineNumber {
                userInfo["lineNumber"] = line
            }

            NotificationCenter.default.post(
                name: .openFilePreview,
                object: nil,
                userInfo: userInfo
            )
            return true
        }

        // Regular URLs → open in browser
        NSWorkspace.shared.open(url)
        return true
    }
}
