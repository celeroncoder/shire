import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var mainWindowController: MainWindowController?
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize database
        DatabaseManager.shared.setup()

        // Build menu bar
        MainMenu.build()

        // Create and show main window
        let windowController = MainWindowController()
        windowController.showWindow(nil)
        mainWindowController = windowController

        // Listen for settings open from sidebar button
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openSettings(_:)),
            name: .openSettings,
            object: nil
        )

        // Activate the app — required for programmatic (no-nib) apps to bring the window to front
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Clean up
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            mainWindowController?.showWindow(nil)
        }
        return true
    }

    // MARK: - Menu Actions

    @objc func newSession(_ sender: Any?) {
        NotificationCenter.default.post(name: .newSession, object: nil)
    }

    @objc func newWorkspace(_ sender: Any?) {
        NotificationCenter.default.post(name: .newWorkspace, object: nil)
    }

    @objc func openSettings(_ sender: Any?) {
        // If settings window already exists, bring it to front
        if let window = settingsWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 780, height: 520),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.minSize = NSSize(width: 640, height: 400)
        window.contentViewController = SettingsViewController()
        window.isReleasedWhenClosed = false

        // Center on main window
        if let mainWindow = mainWindowController?.window {
            let mainFrame = mainWindow.frame
            let x = mainFrame.midX - 390
            let y = mainFrame.midY - 260
            window.setFrameOrigin(NSPoint(x: x, y: y))
        } else {
            window.center()
        }

        window.makeKeyAndOrderFront(nil)
        settingsWindow = window
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let newSession = Notification.Name("com.shire.newSession")
    static let newWorkspace = Notification.Name("com.shire.newWorkspace")
    static let openSettings = Notification.Name("com.shire.openSettings")
    static let navigateToSession = Notification.Name("com.shire.navigateToSession")
    static let navigateToWorkspace = Notification.Name("com.shire.navigateToWorkspace")
    static let sidebarSelectionChanged = Notification.Name("com.shire.sidebarSelectionChanged")
    static let sessionTitleUpdated = Notification.Name("com.shire.sessionTitleUpdated")
    static let workspacesChanged = Notification.Name("com.shire.workspacesChanged")
    static let sessionsChanged = Notification.Name("com.shire.sessionsChanged")
    static let chatStreamingStarted = Notification.Name("com.shire.chatStreamingStarted")
    static let chatStreamingEnded = Notification.Name("com.shire.chatStreamingEnded")
    static let activeWorkspaceChanged = Notification.Name("com.shire.activeWorkspaceChanged")
    static let openFilePreview = Notification.Name("com.shire.openFilePreview")
    static let revealFileInTree = Notification.Name("com.shire.revealFileInTree")
    static let toolCallBanner = Notification.Name("com.shire.toolCallBanner")
    static let artifactCreated = Notification.Name("com.shire.artifactCreated")
}
