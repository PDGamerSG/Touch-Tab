import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private static let statusIcon = templateImage(named: "StatusIcon")
    private static let statusIconWarning = templateImage(named: "StatusIcon-Warning")
    // How often the event tap and the accessibility permission are checked.
    private static let healthCheckInterval: TimeInterval = 2

    private var statusBarItem: NSStatusItem!
    private var aboutWindow: NSWindow!
    private var healthCheckTimer: Timer?
    private var accessibilityWarningMenuItems: [NSMenuItem] = []
    private var fingerCountMenuItems: [NSMenuItem] = []
    private var launchAtLoginMenuItem: NSMenuItem?
    private var hapticFeedbackMenuItem: NSMenuItem!
    private var restoreMinimizedWindowsMenuItem: NSMenuItem!

    private static func templateImage(named: String) -> NSImage? {
        let image = NSImage(named: named)
        image?.isTemplate = true
        return image
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        #if DEBUG
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            return
        }
        #endif

        createStatusBarItem()
        observeSystemEvents()

        let isAccessibilityPermissionGranted = PrivacyHelper.isProcessTrustedWithPrompt()
        debugPrint("Accessibility permission", isAccessibilityPermissionGranted)
        checkHealth()
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: AppDelegate.healthCheckInterval, repeats: true) { [weak self] _ in
            self?.checkHealth()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        SwipeManager.stop()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        statusBarItem.isVisible = true
        return true
    }

    // Keeps the event tap alive and reacts to the accessibility permission being granted or revoked while running.
    private func checkHealth() {
        if AXIsProcessTrusted() {
            removeAccessibilityWarning()
            SwipeManager.ensureRunning()
        } else {
            addAccessibilityWarning()
            SwipeManager.stop()
        }
    }

    private func observeSystemEvents() {
        let notificationCenter = NSWorkspace.shared.notificationCenter
        let onSleep: (Notification) -> Void = { _ in
            debugPrint("System is going to sleep")
            // Don't leave Command pressed or a half-finished gesture behind.
            SwipeManager.reset()
        }
        let onWake: (Notification) -> Void = { [weak self] _ in
            debugPrint("System woke up")
            // The event tap often stops receiving events after a long sleep, so create a fresh one.
            if AXIsProcessTrusted() {
                SwipeManager.restart()
            }
            self?.checkHealth()
        }
        notificationCenter.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main, using: onSleep)
        notificationCenter.addObserver(forName: NSWorkspace.sessionDidResignActiveNotification, object: nil, queue: .main, using: onSleep)
        notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main, using: onWake)
        notificationCenter.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main, using: onWake)
        notificationCenter.addObserver(forName: NSWorkspace.sessionDidBecomeActiveNotification, object: nil, queue: .main, using: onWake)
    }

    private func createStatusBarItem() {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusBarItem.button?.image = AppDelegate.statusIcon
        statusBarItem.button?.toolTip = BundleInfo.displayName()
        statusBarItem.behavior = .removalAllowed

        let menu = NSMenu()
        menu.delegate = self

        let fingersMenu = NSMenu()
        for fingerCount in Settings.supportedFingerCounts {
            let item = NSMenuItem(title: "\(fingerCount) Fingers", action: #selector(selectFingerCount(_:)), keyEquivalent: "")
            item.target = self
            item.tag = fingerCount
            fingersMenu.addItem(item)
            fingerCountMenuItems.append(item)
        }
        let fingersMenuItem = NSMenuItem(title: "Swipe With", action: nil, keyEquivalent: "")
        fingersMenuItem.submenu = fingersMenu
        menu.addItem(fingersMenuItem)

        hapticFeedbackMenuItem = NSMenuItem(title: "Haptic Feedback", action: #selector(toggleHapticFeedback), keyEquivalent: "")
        hapticFeedbackMenuItem.target = self
        menu.addItem(hapticFeedbackMenuItem)

        restoreMinimizedWindowsMenuItem = NSMenuItem(title: "Restore Minimized Windows", action: #selector(toggleRestoreMinimizedWindows), keyEquivalent: "")
        restoreMinimizedWindowsMenuItem.target = self
        restoreMinimizedWindowsMenuItem.toolTip = "Unminimize windows of the selected app"
        menu.addItem(restoreMinimizedWindowsMenuItem)

        if LaunchAtLogin.isSupported {
            let item = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
            item.target = self
            menu.addItem(item)
            launchAtLoginMenuItem = item
        }

        menu.addItem(NSMenuItem.separator())

        let aboutMenuItem = NSMenuItem(title: "About \(BundleInfo.displayName())", action: #selector(showAbout), keyEquivalent: "")
        aboutMenuItem.target = self
        menu.addItem(aboutMenuItem)
        let quitMenuItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitMenuItem.target = self
        menu.addItem(quitMenuItem)

        statusBarItem.menu = menu
        updateMenuItemStates()
    }

    func menuWillOpen(_ menu: NSMenu) {
        updateMenuItemStates()
    }

    private func updateMenuItemStates() {
        for item in fingerCountMenuItems {
            item.state = item.tag == Settings.fingerCount ? .on : .off
        }
        hapticFeedbackMenuItem.state = Settings.hapticFeedback ? .on : .off
        restoreMinimizedWindowsMenuItem.state = Settings.restoreMinimizedWindows ? .on : .off
        launchAtLoginMenuItem?.state = LaunchAtLogin.isEnabled ? .on : .off
    }

    private func addAccessibilityWarning() {
        if !accessibilityWarningMenuItems.isEmpty {
            return
        }
        statusBarItem.button?.image = AppDelegate.statusIconWarning
        let warningDescriptionMenuItem = NSMenuItem(title: "No Accessibility Access", action: nil, keyEquivalent: "")
        warningDescriptionMenuItem.image = AppDelegate.templateImage(named: "MenuItem-Warning")
        warningDescriptionMenuItem.toolTip = "Grant access to this application in Privacy & Security settings, located in System Settings"
        warningDescriptionMenuItem.isEnabled = false
        let openPrivacyAccessibilityMenuItem = NSMenuItem(title: "Authorize...", action: #selector(openPrivacyAccessibility), keyEquivalent: "")
        openPrivacyAccessibilityMenuItem.target = self
        accessibilityWarningMenuItems = [warningDescriptionMenuItem, openPrivacyAccessibilityMenuItem, NSMenuItem.separator()]
        for (index, item) in accessibilityWarningMenuItems.enumerated() {
            statusBarItem.menu?.insertItem(item, at: index)
        }
    }

    private func removeAccessibilityWarning() {
        if accessibilityWarningMenuItems.isEmpty {
            return
        }
        debugPrint("Accessibility permission granted")
        statusBarItem.button?.image = AppDelegate.statusIcon
        for item in accessibilityWarningMenuItems {
            statusBarItem.menu?.removeItem(item)
        }
        accessibilityWarningMenuItems = []
    }

    @objc private func selectFingerCount(_ sender: NSMenuItem) {
        SwipeManager.reset()
        Settings.fingerCount = sender.tag
        updateMenuItemStates()
    }

    @objc private func toggleHapticFeedback() {
        Settings.hapticFeedback = !Settings.hapticFeedback
        updateMenuItemStates()
    }

    @objc private func toggleRestoreMinimizedWindows() {
        Settings.restoreMinimizedWindows = !Settings.restoreMinimizedWindows
        updateMenuItemStates()
    }

    @objc private func toggleLaunchAtLogin() {
        LaunchAtLogin.setEnabled(!LaunchAtLogin.isEnabled)
        updateMenuItemStates()
    }

    @objc private func openPrivacyAccessibility() {
        let privacyAccessibilityURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(privacyAccessibilityURL)
    }

    @objc private func quit() {
        NSApplication.shared.terminate(self)
    }

    @objc private func showAbout() {
        if aboutWindow == nil {
            aboutWindow = NSWindow(contentViewController: NSHostingController(rootView: AboutView().fixedSize()))
            aboutWindow.styleMask = [.closable, .titled]
            aboutWindow.title = ""
            aboutWindow.isReleasedWhenClosed = false
        }
        aboutWindow.center()
        aboutWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
