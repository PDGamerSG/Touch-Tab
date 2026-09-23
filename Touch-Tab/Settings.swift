import Cocoa
import ServiceManagement

class Settings {
    static let supportedFingerCounts = [3, 4]

    private static let fingerCountKey = "fingerCount"
    private static let hapticFeedbackKey = "hapticFeedback"
    private static let restoreMinimizedWindowsKey = "restoreMinimizedWindows"

    private static var defaults: UserDefaults {
        return UserDefaults.standard
    }

    static var fingerCount: Int {
        get {
            let value = defaults.integer(forKey: fingerCountKey)
            return supportedFingerCounts.contains(value) ? value : 3
        }
        set {
            defaults.set(newValue, forKey: fingerCountKey)
        }
    }

    static var hapticFeedback: Bool {
        get { return defaults.bool(forKey: hapticFeedbackKey) }
        set { defaults.set(newValue, forKey: hapticFeedbackKey) }
    }

    static var restoreMinimizedWindows: Bool {
        get { return defaults.bool(forKey: restoreMinimizedWindowsKey) }
        set { defaults.set(newValue, forKey: restoreMinimizedWindowsKey) }
    }
}

class LaunchAtLogin {
    static var isSupported: Bool {
        if #available(macOS 13.0, *) {
            return true
        }
        return false
    }

    static var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    static func setEnabled(_ enabled: Bool) {
        guard #available(macOS 13.0, *) else {
            return
        }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            debugPrint("LaunchAtLogin couldn't change state", error)
            if enabled && SMAppService.mainApp.status == .requiresApproval {
                SMAppService.openSystemSettingsLoginItems()
            }
        }
    }
}
