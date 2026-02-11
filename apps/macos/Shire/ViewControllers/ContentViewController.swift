import AppKit

final class ContentViewController: NSViewController {

    // MARK: - Tab State

    private struct Tab {
        let session: Session
        let viewController: ChatViewController
    }

    private var tabs: [Tab] = []
    private var activeTabIndex: Int?
    private var streamingSessionIds: Set<String> = []

    // MARK: - UI

    private var tabBar: NSView!
    private var tabStackView: NSStackView!
    private var tabBarSeparator: NSBox!
    private var contentContainer: NSView!
    private var emptyStateLabel: NSTextField!
    private var currentNonTabChild: NSViewController?

    override func loadView() {
        view = NSView()
        view.frame = NSRect(x: 0, y: 0, width: 800, height: 600)

        setupTabBar()
        setupContentContainer()
        setupConstraints()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(handleNavigateToSession(_:)), name: .navigateToSession, object: nil)
        nc.addObserver(self, selector: #selector(handleNavigateToWorkspace(_:)), name: .navigateToWorkspace, object: nil)
        nc.addObserver(self, selector: #selector(handleSessionTitleUpdate(_:)), name: .sessionTitleUpdated, object: nil)
        nc.addObserver(self, selector: #selector(handleSessionsChanged), name: .sessionsChanged, object: nil)
        nc.addObserver(self, selector: #selector(handleStreamingStarted(_:)), name: .init("com.shire.streamDelta"), object: nil)
        nc.addObserver(self, selector: #selector(handleStreamingEnded(_:)), name: .init("com.shire.streamDone"), object: nil)
        nc.addObserver(self, selector: #selector(handleStreamingEnded(_:)), name: .init("com.shire.streamError"), object: nil)

        showEmptyState()
    }

    // MARK: - Setup

    private func setupTabBar() {
        tabBar = NSView()
        tabBar.wantsLayer = true
        tabBar.layer?.masksToBounds = true
        tabBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tabBar)

        tabStackView = NSStackView()
        tabStackView.orientation = .horizontal
        tabStackView.spacing = 0
        tabStackView.translatesAutoresizingMaskIntoConstraints = false
        tabBar.addSubview(tabStackView)

        tabBarSeparator = NSBox()
        tabBarSeparator.boxType = .separator
        tabBarSeparator.translatesAutoresizingMaskIntoConstraints = false
        tabBar.addSubview(tabBarSeparator)

        NSLayoutConstraint.activate([
            tabStackView.topAnchor.constraint(equalTo: tabBar.topAnchor),
            tabStackView.leadingAnchor.constraint(equalTo: tabBar.leadingAnchor),
            tabStackView.bottomAnchor.constraint(equalTo: tabBarSeparator.topAnchor),

            tabBarSeparator.leadingAnchor.constraint(equalTo: tabBar.leadingAnchor),
            tabBarSeparator.trailingAnchor.constraint(equalTo: tabBar.trailingAnchor),
            tabBarSeparator.bottomAnchor.constraint(equalTo: tabBar.bottomAnchor),
        ])
    }

    private func setupContentContainer() {
        contentContainer = NSView()
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(contentContainer)

        emptyStateLabel = NSTextField(labelWithString: "Select a workspace or create a new one to get started")
        emptyStateLabel.font = .systemFont(ofSize: 16, weight: .medium)
        emptyStateLabel.textColor = .tertiaryLabelColor
        emptyStateLabel.alignment = .center
        emptyStateLabel.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(emptyStateLabel)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            tabBar.topAnchor.constraint(equalTo: view.topAnchor),
            tabBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tabBar.heightAnchor.constraint(equalToConstant: 32),

            contentContainer.topAnchor.constraint(equalTo: tabBar.bottomAnchor),
            contentContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyStateLabel.centerXAnchor.constraint(equalTo: contentContainer.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: contentContainer.centerYAnchor),
            emptyStateLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 400),
        ])
    }

    // MARK: - Tab Management

    private func openTab(for session: Session) {
        // If tab already exists, just select it
        if let index = tabs.firstIndex(where: { $0.session.id == session.id }) {
            selectTab(at: index)
            return
        }

        removeNonTabChild()
        emptyStateLabel.isHidden = true

        let chatVC = ChatViewController(session: session)
        let tab = Tab(session: session, viewController: chatVC)
        tabs.append(tab)

        selectTab(at: tabs.count - 1)
    }

    private func selectTab(at index: Int) {
        guard index >= 0, index < tabs.count else { return }

        // Remove non-tab content
        removeNonTabChild()
        emptyStateLabel.isHidden = true

        // Detach currently active tab's view
        if let current = activeTabIndex, current < tabs.count, current != index {
            let currentVC = tabs[current].viewController
            currentVC.view.removeFromSuperview()
            currentVC.removeFromParent()
        }

        activeTabIndex = index

        let tab = tabs[index]
        if tab.viewController.parent != self {
            addChild(tab.viewController)
            tab.viewController.view.frame = contentContainer.bounds
            tab.viewController.view.autoresizingMask = [.width, .height]
            contentContainer.addSubview(tab.viewController.view)
        }

        rebuildTabBar()

        // Notify file tree of workspace path and session ID
        if let workspace = WorkspaceRepository.shared.getById(id: tab.session.workspaceId) {
            postWorkspaceChanged(path: workspace.path, sessionId: tab.session.id)
        }
    }

    private func closeTab(at index: Int) {
        guard index >= 0, index < tabs.count else { return }

        let tab = tabs[index]
        tab.viewController.view.removeFromSuperview()
        tab.viewController.removeFromParent()
        tabs.remove(at: index)

        if tabs.isEmpty {
            activeTabIndex = nil
            showEmptyState()
            return
        }

        if let active = activeTabIndex {
            if index == active {
                // Closed the active tab — select adjacent
                let newIndex = min(index, tabs.count - 1)
                activeTabIndex = nil
                selectTab(at: newIndex)
            } else if index < active {
                activeTabIndex = active - 1
                rebuildTabBar()
            } else {
                rebuildTabBar()
            }
        }
    }

    private func rebuildTabBar() {
        for subview in tabStackView.arrangedSubviews {
            tabStackView.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }

        for (index, tab) in tabs.enumerated() {
            // Fetch latest session title from DB
            let title: String
            if let updated = SessionRepository.shared.getById(id: tab.session.id) {
                title = updated.title ?? "New Chat"
            } else {
                title = tab.session.title ?? "New Chat"
            }

            let tabView = TabItemView(title: title)
            tabView.isActive = (index == activeTabIndex)
            tabView.setStreaming(streamingSessionIds.contains(tab.session.id))
            tabView.translatesAutoresizingMaskIntoConstraints = false

            tabView.onSelect = { [weak self] in
                self?.selectTab(at: index)
            }
            tabView.onClose = { [weak self] in
                self?.closeTab(at: index)
            }

            tabStackView.addArrangedSubview(tabView)
        }
    }

    // MARK: - Non-Tab Content (Workspace / Settings)

    private func showNonTabContent(_ childVC: NSViewController) {
        // Detach active tab view but keep it in the tabs array
        if let active = activeTabIndex, active < tabs.count {
            let activeVC = tabs[active].viewController
            activeVC.view.removeFromSuperview()
            activeVC.removeFromParent()
        }
        activeTabIndex = nil

        removeNonTabChild()
        emptyStateLabel.isHidden = true

        addChild(childVC)
        childVC.view.frame = contentContainer.bounds
        childVC.view.autoresizingMask = [.width, .height]
        contentContainer.addSubview(childVC.view)
        currentNonTabChild = childVC

        rebuildTabBar()
    }

    private func removeNonTabChild() {
        if let child = currentNonTabChild {
            child.view.removeFromSuperview()
            child.removeFromParent()
            currentNonTabChild = nil
        }
    }

    private func showEmptyState() {
        if let active = activeTabIndex, active < tabs.count {
            tabs[active].viewController.view.removeFromSuperview()
            tabs[active].viewController.removeFromParent()
        }
        activeTabIndex = nil
        removeNonTabChild()

        emptyStateLabel.isHidden = false
        rebuildTabBar()
        postWorkspaceChanged(path: nil)
    }

    // MARK: - Navigation Handlers

    @objc private func handleNavigateToSession(_ notification: Notification) {
        guard let session = notification.userInfo?["session"] as? Session else { return }
        openTab(for: session)
    }

    @objc private func handleNavigateToWorkspace(_ notification: Notification) {
        guard let workspace = notification.userInfo?["workspace"] as? Workspace else { return }
        let workspaceVC = WorkspaceViewController(workspace: workspace)
        showNonTabContent(workspaceVC)
        postWorkspaceChanged(path: workspace.path)
    }

    @objc private func handleSessionTitleUpdate(_ notification: Notification) {
        rebuildTabBar()
    }

    @objc private func handleSessionsChanged() {
        // Remove tabs for sessions that no longer exist (iterate in reverse)
        for index in stride(from: tabs.count - 1, through: 0, by: -1) {
            if SessionRepository.shared.getById(id: tabs[index].session.id) == nil {
                closeTab(at: index)
            }
        }
    }

    // MARK: - Streaming Indicators

    @objc private func handleStreamingStarted(_ notification: Notification) {
        guard let sessionId = notification.userInfo?["sessionId"] as? String else { return }
        guard !streamingSessionIds.contains(sessionId) else { return }
        streamingSessionIds.insert(sessionId)
        updateTabStreamingIndicator(sessionId: sessionId, isStreaming: true)
    }

    @objc private func handleStreamingEnded(_ notification: Notification) {
        guard let sessionId = notification.userInfo?["sessionId"] as? String else { return }
        guard streamingSessionIds.contains(sessionId) else { return }
        streamingSessionIds.remove(sessionId)
        updateTabStreamingIndicator(sessionId: sessionId, isStreaming: false)
    }

    private func updateTabStreamingIndicator(sessionId: String, isStreaming: Bool) {
        for (index, tab) in tabs.enumerated() {
            if tab.session.id == sessionId,
               index < tabStackView.arrangedSubviews.count,
               let tabView = tabStackView.arrangedSubviews[index] as? TabItemView {
                tabView.setStreaming(isStreaming)
                break
            }
        }
    }

    private func postWorkspaceChanged(path: String?, sessionId: String? = nil) {
        var userInfo: [String: Any] = [:]
        if let path = path {
            userInfo["workspacePath"] = path
        }
        if let sessionId = sessionId {
            userInfo["sessionId"] = sessionId
        }
        NotificationCenter.default.post(name: .activeWorkspaceChanged, object: nil, userInfo: userInfo.isEmpty ? nil : userInfo)
    }
}
