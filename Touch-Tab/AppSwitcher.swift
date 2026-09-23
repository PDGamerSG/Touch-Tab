import Cocoa

class AppSwitcher {
    private static let keyboardEventSource = CGEventSource(stateID: CGEventSourceStateID.hidSystemState)
    private static let tabKey = CGKeyCode(0x30);
    private static let leftCommandKey = CGKeyCode(0x37);
    private static let leftOptionKey = CGKeyCode(0x3A);

    // Command is held down from the first switch until the gesture ends, the same way it is held when using a keyboard.
    private static var isCommandDown = false

    static func selectInAppSwitcher() {
        if !isCommandDown {
            return
        }
        if Settings.restoreMinimizedWindows {
            // Pressing Option before releasing Command restores minimized windows of the selected app.
            postKeyEvent(key: leftOptionKey, down: true, flags: [.maskCommand, .maskAlternate])
            postKeyEvent(key: leftCommandKey, down: false, flags: .maskAlternate)
            postKeyEvent(key: leftOptionKey, down: false)
        } else {
            postKeyEvent(key: leftCommandKey, down: false)
        }
        isCommandDown = false
    }

    static func cmdTab() {
        pressCommand()
        postKeyEvent(key: tabKey, down: true, flags: .maskCommand)
        postKeyEvent(key: tabKey, down: false, flags: .maskCommand)
    }

    static func cmdShiftTab() {
        pressCommand()
        postKeyEvent(key: tabKey, down: true, flags: [.maskCommand, .maskShift])
        postKeyEvent(key: tabKey, down: false, flags: [.maskCommand, .maskShift])
    }

    private static func pressCommand() {
        if isCommandDown {
            return
        }
        postKeyEvent(key: leftCommandKey, down: true, flags: .maskCommand)
        isCommandDown = true
    }

    private static func postKeyEvent(key: CGKeyCode, down: Bool, flags: CGEventFlags = []) {
        let event = CGEvent(keyboardEventSource: keyboardEventSource, virtualKey: key, keyDown: down)
        event?.flags = flags
        event?.post(tap: CGEventTapLocation.cghidEventTap)
    }
}
