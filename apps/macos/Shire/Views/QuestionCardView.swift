import AppKit

// MARK: - QuestionItem

struct QuestionItem {
    let text: String
    let options: [String]
    let multiSelect: Bool
}

// MARK: - QuestionCardView

final class QuestionCardView: NSView, NSTextFieldDelegate {

    // MARK: - State

    private var questions: [QuestionItem] = []
    private var currentIndex = 0
    private var selections: [[Int]] = []
    private var freeTextAnswers: [String] = []

    // MARK: - Callbacks

    var onSubmit: (([[String]]) -> Void)?
    var onDismiss: (() -> Void)?
    var onToggle: (() -> Void)?

    // MARK: - UI Elements

    private let mainStack = NSStackView()
    private let headerStack = NSStackView()
    private let questionLabel = NSTextField(wrappingLabelWithString: "")
    private let dismissButton = NSButton()
    private let optionsStack = NSStackView()
    private let freeTextField = NSTextField()
    private let footerStack = NSStackView()
    private let navContainer = NSStackView()
    private let prevButton = NSButton()
    private let nextButton = NSButton()
    private let dotsStack = NSStackView()
    private let submitButton = NSButton()

    // MARK: - Init

    override init(frame: NSRect) {
        super.init(frame: frame)
        setupViews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - First Responder (keyboard shortcuts)

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        guard currentIndex < questions.count else {
            super.keyDown(with: event)
            return
        }

        let question = questions[currentIndex]

        // Number keys to toggle options (1-9, 0 for 10th)
        if !question.options.isEmpty, let char = event.characters?.first, char.isNumber {
            let num = Int(String(char))!
            let optionIndex: Int
            if num == 0 {
                optionIndex = min(9, question.options.count - 1)
            } else {
                optionIndex = num - 1
            }
            if optionIndex >= 0 && optionIndex < question.options.count {
                toggleOption(at: optionIndex)
                return
            }
        }

        // Return to submit
        if event.keyCode == 36 && allQuestionsAnswered {
            submitClicked()
            return
        }

        // Left/Right arrows for multi-question navigation
        if event.keyCode == 123 { goPrev(); return }
        if event.keyCode == 124 { goNext(); return }

        // Escape to dismiss
        if event.keyCode == 53 { dismissClicked(); return }

        super.keyDown(with: event)
    }

    // MARK: - Setup

    private func setupViews() {
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        layer?.borderWidth = 0.5
        layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.5).cgColor
        translatesAutoresizingMaskIntoConstraints = false

        setupHeader()
        setupOptions()
        setupFreeText()
        setupFooter()
        setupMainStack()
    }

    private func setupHeader() {
        // Question text
        questionLabel.font = .systemFont(ofSize: 14, weight: .medium)
        questionLabel.textColor = .labelColor
        questionLabel.lineBreakMode = .byWordWrapping
        questionLabel.maximumNumberOfLines = 0
        questionLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        // Dismiss (X) button
        dismissButton.bezelStyle = .inline
        dismissButton.isBordered = false
        let xConfig = NSImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
        dismissButton.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Dismiss")?.withSymbolConfiguration(xConfig)
        dismissButton.contentTintColor = .tertiaryLabelColor
        dismissButton.target = self
        dismissButton.action = #selector(dismissClicked)
        dismissButton.setContentHuggingPriority(.required, for: .horizontal)
        dismissButton.setContentCompressionResistancePriority(.required, for: .horizontal)

        headerStack.orientation = .horizontal
        headerStack.alignment = .top
        headerStack.spacing = 8
        headerStack.setViews([questionLabel, dismissButton], in: .leading)
    }

    private func setupOptions() {
        optionsStack.orientation = .vertical
        optionsStack.alignment = .leading
        optionsStack.spacing = 1
    }

    private func setupFreeText() {
        freeTextField.placeholderString = "Type your answer..."
        freeTextField.font = .systemFont(ofSize: 13)
        freeTextField.textColor = .labelColor
        freeTextField.drawsBackground = true
        freeTextField.isBordered = true
        freeTextField.bezelStyle = .roundedBezel
        freeTextField.focusRingType = .exterior
        freeTextField.delegate = self
        freeTextField.isHidden = true
    }

    private func setupFooter() {
        // Previous button
        let leftConfig = NSImage.SymbolConfiguration(pointSize: 10, weight: .medium)
        prevButton.bezelStyle = .inline
        prevButton.isBordered = false
        prevButton.image = NSImage(systemSymbolName: "chevron.left", accessibilityDescription: "Previous")?.withSymbolConfiguration(leftConfig)
        prevButton.contentTintColor = .secondaryLabelColor
        prevButton.target = self
        prevButton.action = #selector(prevClicked)
        prevButton.setContentHuggingPriority(.required, for: .horizontal)

        // Dots
        dotsStack.orientation = .horizontal
        dotsStack.alignment = .centerY
        dotsStack.spacing = 5

        // Next button
        let rightConfig = NSImage.SymbolConfiguration(pointSize: 10, weight: .medium)
        nextButton.bezelStyle = .inline
        nextButton.isBordered = false
        nextButton.image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: "Next")?.withSymbolConfiguration(rightConfig)
        nextButton.contentTintColor = .secondaryLabelColor
        nextButton.target = self
        nextButton.action = #selector(nextClicked)
        nextButton.setContentHuggingPriority(.required, for: .horizontal)

        // Nav container (prev + dots + next)
        navContainer.orientation = .horizontal
        navContainer.alignment = .centerY
        navContainer.spacing = 4
        navContainer.setViews([prevButton, dotsStack, nextButton], in: .leading)
        navContainer.isHidden = true

        // Submit button (rounded rect with arrow up, inverted colors)
        let arrowConfig = NSImage.SymbolConfiguration(pointSize: 12, weight: .bold)
        submitButton.bezelStyle = .inline
        submitButton.isBordered = false
        submitButton.wantsLayer = true
        submitButton.layer?.cornerRadius = 6
        submitButton.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.15).cgColor
        submitButton.image = NSImage(systemSymbolName: "arrow.up", accessibilityDescription: "Submit")?.withSymbolConfiguration(arrowConfig)
        submitButton.contentTintColor = .labelColor
        submitButton.target = self
        submitButton.action = #selector(submitClicked)

        // Footer layout: [nav] --- [submit]
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        footerStack.orientation = .horizontal
        footerStack.alignment = .centerY
        footerStack.spacing = 8
        footerStack.setViews([navContainer, spacer, submitButton], in: .leading)
    }

    private func setupMainStack() {
        mainStack.orientation = .vertical
        mainStack.alignment = .leading
        mainStack.spacing = 12
        mainStack.edgeInsets = NSEdgeInsets(top: 16, left: 0, bottom: 12, right: 0)
        mainStack.detachesHiddenViews = true
        mainStack.setViews([headerStack, optionsStack, freeTextField, footerStack], in: .leading)
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(mainStack)

        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: topAnchor),
            mainStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            mainStack.bottomAnchor.constraint(equalTo: bottomAnchor),

            headerStack.leadingAnchor.constraint(equalTo: mainStack.leadingAnchor, constant: 16),
            headerStack.trailingAnchor.constraint(equalTo: mainStack.trailingAnchor, constant: -14),

            optionsStack.leadingAnchor.constraint(equalTo: mainStack.leadingAnchor, constant: 6),
            optionsStack.trailingAnchor.constraint(equalTo: mainStack.trailingAnchor, constant: -6),

            freeTextField.leadingAnchor.constraint(equalTo: mainStack.leadingAnchor, constant: 16),
            freeTextField.trailingAnchor.constraint(equalTo: mainStack.trailingAnchor, constant: -16),
            freeTextField.heightAnchor.constraint(equalToConstant: 32),

            footerStack.leadingAnchor.constraint(equalTo: mainStack.leadingAnchor, constant: 12),
            footerStack.trailingAnchor.constraint(equalTo: mainStack.trailingAnchor, constant: -12),

            submitButton.widthAnchor.constraint(equalToConstant: 28),
            submitButton.heightAnchor.constraint(equalToConstant: 28),

            dismissButton.widthAnchor.constraint(equalToConstant: 20),
            dismissButton.heightAnchor.constraint(equalToConstant: 20),
        ])
    }

    // MARK: - Configure

    func configure(with questions: [QuestionItem]) {
        self.questions = questions
        self.currentIndex = 0
        self.selections = Array(repeating: [], count: questions.count)
        self.freeTextAnswers = Array(repeating: "", count: questions.count)
        renderCurrentQuestion()
    }

    // MARK: - Rendering

    private func renderCurrentQuestion() {
        guard currentIndex < questions.count else { return }
        let question = questions[currentIndex]

        questionLabel.stringValue = question.text

        // Clear existing option rows
        for v in optionsStack.arrangedSubviews {
            optionsStack.removeArrangedSubview(v)
            v.removeFromSuperview()
        }

        if question.options.isEmpty {
            // Free-text mode
            optionsStack.isHidden = true
            freeTextField.isHidden = false
            freeTextField.stringValue = freeTextAnswers[currentIndex]
        } else {
            // Options mode
            optionsStack.isHidden = false
            freeTextField.isHidden = true
            let selected = selections[currentIndex]
            for (i, option) in question.options.enumerated() {
                let row = makeOptionRow(
                    text: option,
                    index: i,
                    isSelected: selected.contains(i),
                    isMultiSelect: question.multiSelect
                )
                optionsStack.addArrangedSubview(row)
                row.leadingAnchor.constraint(equalTo: optionsStack.leadingAnchor).isActive = true
                row.trailingAnchor.constraint(equalTo: optionsStack.trailingAnchor).isActive = true
            }
        }

        // Multi-question navigation
        navContainer.isHidden = questions.count <= 1
        prevButton.isEnabled = currentIndex > 0
        prevButton.alphaValue = currentIndex > 0 ? 1.0 : 0.3
        nextButton.isEnabled = currentIndex < questions.count - 1
        nextButton.alphaValue = currentIndex < questions.count - 1 ? 1.0 : 0.3
        updateDots()

        updateSubmitState()
        onToggle?()
    }

    private var allQuestionsAnswered: Bool {
        for (i, question) in questions.enumerated() {
            if question.options.isEmpty {
                if freeTextAnswers[i].trimmingCharacters(in: .whitespaces).isEmpty { return false }
            } else {
                if selections[i].isEmpty { return false }
            }
        }
        return true
    }

    private func updateSubmitState() {
        let enabled = allQuestionsAnswered
        submitButton.isEnabled = enabled
        submitButton.alphaValue = enabled ? 1.0 : 0.35
    }

    // MARK: - Option Row

    private func makeOptionRow(text: String, index: Int, isSelected: Bool, isMultiSelect: Bool) -> NSView {
        let row = NSView()
        row.wantsLayer = true
        row.layer?.cornerRadius = 8
        row.translatesAutoresizingMaskIntoConstraints = false

        // Selected row highlight
        row.layer?.backgroundColor = isSelected
            ? NSColor.labelColor.withAlphaComponent(0.06).cgColor
            : NSColor.clear.cgColor

        // Number badge (keyboard shortcut indicator)
        let numberBadge = NSTextField(labelWithString: "")
        let displayNumber = index < 9 ? "\(index + 1)" : "0"
        numberBadge.stringValue = displayNumber
        numberBadge.font = .monospacedSystemFont(ofSize: 11, weight: .medium)
        numberBadge.textColor = isSelected ? .labelColor : .tertiaryLabelColor
        numberBadge.alignment = .center
        numberBadge.wantsLayer = true
        numberBadge.layer?.cornerRadius = 4
        numberBadge.layer?.backgroundColor = isSelected
            ? NSColor.labelColor.withAlphaComponent(0.1).cgColor
            : NSColor.labelColor.withAlphaComponent(0.04).cgColor
        numberBadge.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(numberBadge)

        // Option text
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = .systemFont(ofSize: 13)
        label.textColor = isSelected ? .labelColor : .secondaryLabelColor
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(label)

        // Checkbox on the right
        let checkbox = NSImageView()
        checkbox.translatesAutoresizingMaskIntoConstraints = false
        let checkConfig = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        if isSelected {
            checkbox.image = NSImage(systemSymbolName: "checkmark.square.fill", accessibilityDescription: "Selected")?.withSymbolConfiguration(checkConfig)
            checkbox.contentTintColor = .controlAccentColor
        } else {
            checkbox.image = NSImage(systemSymbolName: "square", accessibilityDescription: "Not selected")?.withSymbolConfiguration(checkConfig)
            checkbox.contentTintColor = .tertiaryLabelColor
        }
        row.addSubview(checkbox)

        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(greaterThanOrEqualToConstant: 38),

            numberBadge.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 10),
            numberBadge.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            numberBadge.widthAnchor.constraint(equalToConstant: 22),
            numberBadge.heightAnchor.constraint(equalToConstant: 22),

            label.leadingAnchor.constraint(equalTo: numberBadge.trailingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: checkbox.leadingAnchor, constant: -10),
            label.topAnchor.constraint(equalTo: row.topAnchor, constant: 9),
            label.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -9),

            checkbox.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -10),
            checkbox.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            checkbox.widthAnchor.constraint(equalToConstant: 20),
            checkbox.heightAnchor.constraint(equalToConstant: 20),
        ])

        // Click gesture
        let click = NSClickGestureRecognizer(target: self, action: #selector(optionClicked(_:)))
        row.addGestureRecognizer(click)
        row.setAccessibilityIdentifier("option_\(index)")

        return row
    }

    // MARK: - Navigation Dots

    private func updateDots() {
        for v in dotsStack.arrangedSubviews {
            dotsStack.removeArrangedSubview(v)
            v.removeFromSuperview()
        }

        for i in 0..<questions.count {
            let dot = NSView()
            dot.wantsLayer = true
            dot.translatesAutoresizingMaskIntoConstraints = false
            let size: CGFloat = 7
            dot.layer?.cornerRadius = size / 2

            if i == currentIndex {
                dot.layer?.backgroundColor = NSColor.labelColor.cgColor
            } else if !selections[i].isEmpty || !freeTextAnswers[i].trimmingCharacters(in: .whitespaces).isEmpty {
                dot.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.4).cgColor
            } else {
                dot.layer?.backgroundColor = NSColor.tertiaryLabelColor.cgColor
            }

            dotsStack.addArrangedSubview(dot)
            NSLayoutConstraint.activate([
                dot.widthAnchor.constraint(equalToConstant: size),
                dot.heightAnchor.constraint(equalToConstant: size),
            ])
        }
    }

    // MARK: - Actions

    private func toggleOption(at index: Int) {
        guard currentIndex < questions.count else { return }
        let question = questions[currentIndex]

        if question.multiSelect {
            if let pos = selections[currentIndex].firstIndex(of: index) {
                selections[currentIndex].remove(at: pos)
            } else {
                selections[currentIndex].append(index)
            }
        } else {
            selections[currentIndex] = [index]
        }

        renderCurrentQuestion()

        // Single-select: auto-advance to next question
        if !question.multiSelect && currentIndex < questions.count - 1 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.goNext()
            }
        }
    }

    @objc private func optionClicked(_ gesture: NSClickGestureRecognizer) {
        guard let pill = gesture.view else { return }
        let identifier = pill.accessibilityIdentifier()
        guard identifier.hasPrefix("option_"),
              let index = Int(identifier.replacingOccurrences(of: "option_", with: "")) else { return }
        toggleOption(at: index)
    }

    @objc private func prevClicked() { goPrev() }
    @objc private func nextClicked() { goNext() }

    @objc private func dismissClicked() {
        onDismiss?()
    }

    @objc private func submitClicked() {
        saveFreeTextIfNeeded()
        guard allQuestionsAnswered else { return }

        // Build answers
        var answers: [[String]] = []
        for (qi, question) in questions.enumerated() {
            if question.options.isEmpty {
                answers.append([freeTextAnswers[qi]])
            } else {
                let selected = selections[qi].map { question.options[$0] }
                answers.append(selected)
            }
        }

        // Visual feedback
        submitButton.isEnabled = false
        submitButton.layer?.backgroundColor = NSColor.systemGreen.withAlphaComponent(0.8).cgColor
        isUserInteractionEnabled = false

        onSubmit?(answers)
    }

    private func saveFreeTextIfNeeded() {
        if currentIndex < questions.count && questions[currentIndex].options.isEmpty {
            freeTextAnswers[currentIndex] = freeTextField.stringValue
        }
    }

    private func goPrev() {
        guard currentIndex > 0 else { return }
        saveFreeTextIfNeeded()
        currentIndex -= 1
        renderCurrentQuestion()
    }

    private func goNext() {
        guard currentIndex < questions.count - 1 else { return }
        saveFreeTextIfNeeded()
        currentIndex += 1
        renderCurrentQuestion()
    }

    // MARK: - User Interaction Control

    private var isUserInteractionEnabled = true

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard isUserInteractionEnabled else { return nil }
        return super.hitTest(point)
    }

    // MARK: - NSTextFieldDelegate

    func controlTextDidChange(_ obj: Notification) {
        guard currentIndex < questions.count else { return }
        freeTextAnswers[currentIndex] = freeTextField.stringValue
        updateSubmitState()
    }

    // MARK: - Parse Helper

    /// Parse questions from tool call input details
    static func parseQuestions(from input: [String: Any]?) -> [QuestionItem]? {
        guard let input = input,
              let questionsArray = input["questions"] as? [[String: Any]],
              !questionsArray.isEmpty else { return nil }

        var items: [QuestionItem] = []
        for q in questionsArray {
            guard let questionText = q["question"] as? String else { continue }
            let options = q["options"] as? [String] ?? []
            let multiSelect = q["multiSelect"] as? Bool ?? false
            items.append(QuestionItem(text: questionText, options: options, multiSelect: multiSelect))
        }

        return items.isEmpty ? nil : items
    }

    /// Check if a tool call is a question tool
    static func isQuestionToolCall(_ info: ToolCallBannerInfo) -> Bool {
        let name = info.toolName.lowercased()
        if name.contains("askuser") || name.contains("question") {
            if let _ = parseQuestions(from: info.inputDetails) {
                return true
            }
        }
        if let _ = parseQuestions(from: info.inputDetails) {
            return true
        }
        return false
    }
}

// MARK: - Read-Only Summary (for persisted messages)

extension QuestionCardView {

    /// Create a read-only summary card for persisted question tool calls
    static func makePersistedSummary(from call: [String: Any]) -> NSView? {
        let input = call["input"] as? [String: Any]
        guard let questions = parseQuestions(from: input) else { return nil }

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.wantsLayer = true
        stack.layer?.cornerRadius = 10
        stack.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        stack.layer?.borderWidth = 0.5
        stack.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.3).cgColor
        stack.edgeInsets = NSEdgeInsets(top: 12, left: 14, bottom: 12, right: 14)
        stack.translatesAutoresizingMaskIntoConstraints = false

        // Header with checkmark
        let headerStack = NSStackView()
        headerStack.orientation = .horizontal
        headerStack.alignment = .centerY
        headerStack.spacing = 6

        let icon = NSImageView()
        let iconConfig = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        icon.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "Answered")?.withSymbolConfiguration(iconConfig)
        icon.contentTintColor = .systemGreen
        icon.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: "Question Answered")
        titleLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        titleLabel.textColor = .secondaryLabelColor

        headerStack.setViews([icon, titleLabel], in: .leading)
        stack.addArrangedSubview(headerStack)

        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 16),
            icon.heightAnchor.constraint(equalToConstant: 16),
        ])

        // Question text summaries
        for question in questions {
            let qLabel = NSTextField(wrappingLabelWithString: question.text)
            qLabel.font = .systemFont(ofSize: 12, weight: .medium)
            qLabel.textColor = .labelColor
            qLabel.lineBreakMode = .byWordWrapping
            qLabel.maximumNumberOfLines = 0
            qLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            qLabel.translatesAutoresizingMaskIntoConstraints = false
            stack.addArrangedSubview(qLabel)
            qLabel.leadingAnchor.constraint(equalTo: stack.leadingAnchor, constant: 14).isActive = true
            qLabel.trailingAnchor.constraint(equalTo: stack.trailingAnchor, constant: -14).isActive = true
        }

        return stack
    }
}
