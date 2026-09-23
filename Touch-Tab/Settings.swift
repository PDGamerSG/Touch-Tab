import Foundation

class Settings {
    static let supportedFingerCounts = [3, 4]

    private static let fingerCountKey = "fingerCount"
    private static let hapticFeedbackKey = "hapticFeedback"
    private static let restoreMinimizedWindowsKey = "restoreMinimizedWindows"

    static var defaults = UserDefaults.standard

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
