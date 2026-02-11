import AppKit

final class SplitViewController: NSSplitViewController {

    private let sidebarVC = SidebarViewController()
    private let contentVC = ContentViewController()
    private let fileTreeVC = FileTreeViewController()
    private var didSetInitialPositions = false

    override func viewDidLoad() {
        super.viewDidLoad()

        // Sidebar item (left) — regular item, not floating/overlay sidebar
        let sidebarItem = NSSplitViewItem(viewController: sidebarVC)
        sidebarItem.minimumThickness = 220
        sidebarItem.maximumThickness = 350
        sidebarItem.canCollapse = true
        sidebarItem.holdingPriority = .defaultLow + 1
        addSplitViewItem(sidebarItem)

        // Content item (center)
        let contentItem = NSSplitViewItem(viewController: contentVC)
        contentItem.minimumThickness = 400
        addSplitViewItem(contentItem)

        // File tree item (right)
        let fileTreeItem = NSSplitViewItem(viewController: fileTreeVC)
        fileTreeItem.minimumThickness = 200
        fileTreeItem.maximumThickness = 350
        fileTreeItem.canCollapse = true
        fileTreeItem.holdingPriority = .defaultLow
        addSplitViewItem(fileTreeItem)

        // Set left sidebar initial width
        splitView.setPosition(240, ofDividerAt: 0)

        // Sidebar visibility based on navigation
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(showSidebar), name: .navigateToSession, object: nil)
        nc.addObserver(self, selector: #selector(showSidebar), name: .navigateToWorkspace, object: nil)
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        // Set right panel position only on first layout
        if !didSetInitialPositions {
            didSetInitialPositions = true
            let rightPosition = splitView.bounds.width - 260
            if splitView.subviews.count >= 3 {
                splitView.setPosition(rightPosition, ofDividerAt: 1)
            }
        }
    }

    @objc private func showSidebar() {
        guard let sidebarItem = splitViewItems.first, sidebarItem.isCollapsed else { return }
        sidebarItem.animator().isCollapsed = false
    }

    @objc private func hideSidebar() {
        guard let sidebarItem = splitViewItems.first, !sidebarItem.isCollapsed else { return }
        sidebarItem.animator().isCollapsed = true
    }
}
