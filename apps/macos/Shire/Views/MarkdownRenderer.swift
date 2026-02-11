import AppKit
import Markdown

/// Custom NSAttributedString key for storing file path info
extension NSAttributedString.Key {
    static let fileReference = NSAttributedString.Key("com.shire.fileReference")
}

enum MarkdownRenderer {

    static func render(_ markdown: String, workspacePath: String? = nil) -> NSAttributedString {
        let document = Document(parsing: markdown)
        let builder = AttributedStringBuilder(workspacePath: workspacePath)
        builder.processDocument(document)

        // Post-process: detect file_path:line_number patterns in plain text
        if let wsPath = workspacePath {
            builder.detectFileReferences(workspacePath: wsPath)
        }

        return builder.result
    }
}

// MARK: - Attributed String Builder

private final class AttributedStringBuilder {

    let result = NSMutableAttributedString()
    let workspacePath: String?

    private var listDepth = 0
    private var orderedCounter = 0
    private var isFirstBlock = true

    private let baseFontSize: CGFloat = 13
    private let codeFontSize: CGFloat = 12

    init(workspacePath: String? = nil) {
        self.workspacePath = workspacePath
    }

    // MARK: - Document

    func processDocument(_ document: Document) {
        for child in document.children {
            processBlock(child)
        }
        // Trim trailing whitespace
        while result.length > 0 && result.string.hasSuffix("\n") {
            result.deleteCharacters(in: NSRange(location: result.length - 1, length: 1))
        }
    }

    // MARK: - File Reference Detection (post-processing)

    /// Scan the rendered text for file_path:line_number patterns and convert to clickable links
    func detectFileReferences(workspacePath: String) {
        let text = result.string as NSString

        // Match patterns like `src/file.swift:42` or `/abs/path/file.ts:10`
        // Requires: path with at least one slash or dot, followed by :lineNumber
        let pattern = #"(?<![`\w])([a-zA-Z0-9_./-]+\.[a-zA-Z]{1,10}):(\d+)(?![`\w])"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }

        let matches = regex.matches(in: result.string, range: NSRange(location: 0, length: text.length))

        // Apply in reverse so ranges stay valid
        for match in matches.reversed() {
            guard match.numberOfRanges >= 3 else { continue }

            let fullRange = match.range(at: 0)
            let pathRange = match.range(at: 1)
            let lineRange = match.range(at: 2)

            let relativePath = text.substring(with: pathRange)
            let lineStr = text.substring(with: lineRange)

            // Check if already inside an inline code or link (skip if so)
            var existingAttrs = result.attributes(at: fullRange.location, effectiveRange: nil)
            if existingAttrs[.link] != nil { continue }

            // Resolve the absolute path
            let absolutePath: String
            if relativePath.hasPrefix("/") {
                absolutePath = relativePath
            } else {
                absolutePath = (workspacePath as NSString).appendingPathComponent(relativePath)
            }

            // Verify the file exists
            guard FileManager.default.fileExists(atPath: absolutePath) else { continue }

            // Build the file reference URL
            var components = URLComponents()
            components.scheme = "shire-file"
            components.path = absolutePath
            components.queryItems = [URLQueryItem(name: "line", value: lineStr)]
            guard let url = components.url else { continue }

            // Apply file reference styling
            let fileAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: codeFontSize, weight: .medium),
                .foregroundColor: NSColor.systemTeal,
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .link: url,
                .cursor: NSCursor.pointingHand,
                .fileReference: absolutePath,
            ]

            result.setAttributes(fileAttrs, range: fullRange)
        }
    }

    // MARK: - Block Spacing

    private func addBlockSpacing() {
        guard !isFirstBlock, result.length > 0 else {
            isFirstBlock = false
            return
        }
        isFirstBlock = false

        let str = result.string
        if str.hasSuffix("\n\n") { return }
        if str.hasSuffix("\n") {
            append("\n", bodyAttrs())
        } else {
            append("\n\n", bodyAttrs())
        }
    }

    // MARK: - Block Processing

    private func processBlock(_ markup: any Markup) {
        if let paragraph = markup as? Paragraph {
            if listDepth == 0 { addBlockSpacing() }
            processInlineChildren(paragraph.children, bodyAttrs())
        } else if let heading = markup as? Heading {
            addBlockSpacing()
            processHeading(heading)
        } else if let codeBlock = markup as? CodeBlock {
            addBlockSpacing()
            processCodeBlock(codeBlock)
        } else if let list = markup as? UnorderedList {
            if listDepth == 0 { addBlockSpacing() }
            processUnorderedList(list)
        } else if let list = markup as? OrderedList {
            if listDepth == 0 { addBlockSpacing() }
            processOrderedList(list)
        } else if markup is ThematicBreak {
            addBlockSpacing()
            append("────────────────────\n", [
                .font: NSFont.systemFont(ofSize: baseFontSize),
                .foregroundColor: NSColor.separatorColor,
            ])
        } else if let blockquote = markup as? BlockQuote {
            addBlockSpacing()
            processBlockQuote(blockquote)
        } else {
            for child in markup.children {
                processBlock(child)
            }
        }
    }

    // MARK: - Heading

    private func processHeading(_ heading: Heading) {
        let size: CGFloat
        switch heading.level {
        case 1: size = 22
        case 2: size = 18
        case 3: size = 16
        default: size = 14
        }
        let attrs = headingAttrs(size: size)
        processInlineChildren(heading.children, attrs)
        append("\n", bodyAttrs())
    }

    // MARK: - Code Block

    private func processCodeBlock(_ codeBlock: CodeBlock) {
        var code = codeBlock.code
        if code.hasSuffix("\n") { code = String(code.dropLast()) }

        let style = NSMutableParagraphStyle()
        style.lineSpacing = 2
        style.headIndent = 12
        style.firstLineHeadIndent = 12
        style.tailIndent = -12

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: codeFontSize, weight: .regular),
            .foregroundColor: NSColor.secondaryLabelColor,
            .backgroundColor: NSColor(white: 0.5, alpha: 0.08),
            .paragraphStyle: style,
        ]

        append("\n", bodyAttrs())
        append(code, attrs)
        append("\n", bodyAttrs())
    }

    // MARK: - Lists

    private func processUnorderedList(_ list: UnorderedList) {
        listDepth += 1
        for child in list.children {
            if let item = child as? ListItem {
                processUnorderedListItem(item)
            }
        }
        listDepth -= 1
    }

    private func processOrderedList(_ list: OrderedList) {
        listDepth += 1
        let savedCounter = orderedCounter
        orderedCounter = 0
        for child in list.children {
            if let item = child as? ListItem {
                orderedCounter += 1
                processOrderedListItem(item, number: orderedCounter)
            }
        }
        orderedCounter = savedCounter
        listDepth -= 1
    }

    private func processUnorderedListItem(_ item: ListItem) {
        let indent = String(repeating: "    ", count: listDepth - 1)
        let bullet = listDepth == 1 ? "  •  " : "  ◦  "

        append(indent + bullet, [
            .font: NSFont.systemFont(ofSize: baseFontSize),
            .foregroundColor: NSColor.tertiaryLabelColor,
        ])

        for (i, child) in item.children.enumerated() {
            if let para = child as? Paragraph {
                processInlineChildren(para.children, bodyAttrs())
            } else if child is UnorderedList || child is OrderedList {
                append("\n", bodyAttrs())
                processBlock(child)
                continue
            } else {
                processBlock(child)
            }
            if i < item.childCount - 1, !(item.children.dropFirst(i + 1).first is UnorderedList),
               !(item.children.dropFirst(i + 1).first is OrderedList) {
                // Space between sub-blocks
            }
        }
        append("\n", bodyAttrs())
    }

    private func processOrderedListItem(_ item: ListItem, number: Int) {
        let indent = String(repeating: "    ", count: listDepth - 1)

        append(indent + "  \(number).  ", [
            .font: NSFont.systemFont(ofSize: baseFontSize),
            .foregroundColor: NSColor.tertiaryLabelColor,
        ])

        for child in item.children {
            if let para = child as? Paragraph {
                processInlineChildren(para.children, bodyAttrs())
            } else if child is UnorderedList || child is OrderedList {
                append("\n", bodyAttrs())
                processBlock(child)
                continue
            } else {
                processBlock(child)
            }
        }
        append("\n", bodyAttrs())
    }

    // MARK: - Block Quote

    private func processBlockQuote(_ blockquote: BlockQuote) {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 2
        style.headIndent = 20
        style.firstLineHeadIndent = 20

        let quoteAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: baseFontSize),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: style,
        ]

        append("  ┃  ", [
            .font: NSFont.systemFont(ofSize: baseFontSize),
            .foregroundColor: NSColor.tertiaryLabelColor,
        ])

        for child in blockquote.children {
            if let para = child as? Paragraph {
                processInlineChildren(para.children, quoteAttrs)
            } else {
                processBlock(child)
            }
        }
        append("\n", bodyAttrs())
    }

    // MARK: - Inline Processing

    private func processInlineChildren(_ children: some Sequence<any Markup>, _ attrs: [NSAttributedString.Key: Any]) {
        for child in children {
            processInline(child, attrs)
        }
    }

    private func processInline(_ markup: any Markup, _ attrs: [NSAttributedString.Key: Any]) {
        if let text = markup as? Markdown.Text {
            append(text.string, attrs)
        } else if let code = markup as? InlineCode {
            append(" ", attrs)

            // Check if inline code looks like a file path in the workspace
            if let fileAttrs = fileReferenceAttrs(for: code.code) {
                append(code.code, fileAttrs)
            } else {
                append(code.code, inlineCodeAttrs())
            }

            append(" ", attrs)
        } else if let strong = markup as? Strong {
            var boldAttrs = attrs
            if let font = attrs[.font] as? NSFont {
                boldAttrs[.font] = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
            }
            processInlineChildren(strong.children, boldAttrs)
        } else if let emphasis = markup as? Emphasis {
            var italicAttrs = attrs
            if let font = attrs[.font] as? NSFont {
                italicAttrs[.font] = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
            }
            processInlineChildren(emphasis.children, italicAttrs)
        } else if let link = markup as? Markdown.Link {
            var linkAttrs = attrs
            linkAttrs[.foregroundColor] = NSColor.systemBlue
            linkAttrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
            if let dest = link.destination, let url = URL(string: dest) {
                linkAttrs[.link] = url
            }
            processInlineChildren(link.children, linkAttrs)
        } else if markup is SoftBreak {
            append(" ", attrs)
        } else if markup is LineBreak {
            append("\n", attrs)
        } else {
            processInlineChildren(markup.children, attrs)
        }
    }

    // MARK: - File Reference Detection (inline code)

    /// Check if an inline code string looks like a file path that exists in the workspace.
    /// Returns styled attributes with a clickable link if so, nil otherwise.
    private func fileReferenceAttrs(for code: String) -> [NSAttributedString.Key: Any]? {
        guard let wsPath = workspacePath else { return nil }

        // Must contain a dot (file extension) or a slash
        guard code.contains(".") || code.contains("/") else { return nil }

        // Skip things that are clearly not file paths
        if code.contains("(") || code.contains(")") || code.contains(" ") || code.contains("=") {
            return nil
        }

        // Handle path:line format — strip line number for existence check
        var filePath = code
        var lineNumber: String?
        if let colonRange = code.range(of: #":(\d+)$"#, options: .regularExpression) {
            let lineStr = String(code[colonRange].dropFirst()) // drop the colon
            lineNumber = lineStr
            filePath = String(code[code.startIndex..<colonRange.lowerBound])
        }

        // Resolve absolute path
        let absolutePath: String
        if filePath.hasPrefix("/") {
            absolutePath = filePath
        } else {
            absolutePath = (wsPath as NSString).appendingPathComponent(filePath)
        }

        // Must exist on disk
        guard FileManager.default.fileExists(atPath: absolutePath) else { return nil }

        // Build shire-file URL
        var components = URLComponents()
        components.scheme = "shire-file"
        components.path = absolutePath
        if let line = lineNumber {
            components.queryItems = [URLQueryItem(name: "line", value: line)]
        }
        guard let url = components.url else { return nil }

        return [
            .font: NSFont.monospacedSystemFont(ofSize: codeFontSize, weight: .medium),
            .foregroundColor: NSColor.systemTeal,
            .backgroundColor: NSColor.systemTeal.withAlphaComponent(0.08),
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .link: url,
            .fileReference: absolutePath,
        ]
    }

    // MARK: - Helpers

    private func append(_ string: String, _ attrs: [NSAttributedString.Key: Any]) {
        result.append(NSAttributedString(string: string, attributes: attrs))
    }

    private func bodyAttrs() -> [NSAttributedString.Key: Any] {
        return [
            .font: NSFont.systemFont(ofSize: baseFontSize),
            .foregroundColor: NSColor.labelColor,
        ]
    }

    private func headingAttrs(size: CGFloat) -> [NSAttributedString.Key: Any] {
        return [
            .font: NSFont.systemFont(ofSize: size, weight: .bold),
            .foregroundColor: NSColor.labelColor,
        ]
    }

    private func inlineCodeAttrs() -> [NSAttributedString.Key: Any] {
        return [
            .font: NSFont.monospacedSystemFont(ofSize: codeFontSize, weight: .medium),
            .foregroundColor: NSColor.systemOrange,
            .backgroundColor: NSColor(white: 0.5, alpha: 0.1),
        ]
    }
}
