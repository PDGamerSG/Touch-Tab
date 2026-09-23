import CoreGraphics

class AppSwitcher {
    typealias KeyEventPoster = (_ key: CGKeyCode, _ down: Bool, _ flags: CGEventFlags) -> Void

    static let tabKey = CGKeyCode(0x30);
    static let leftCommandKey = CGKeyCode(0x37);
    static let leftOptionKey = CGKeyCode(0x3A);

    private static let keyboardEventSource = CGEventSource(stateID: CGEventSourceStateID.hidSystemState)

    private let postKeyEvent: KeyEventPoster
    // Command is held down from the first switch until the gesture ends, the same way it is held when using a keyboard.
    private(set) var isCommandDown = false

    init(postKeyEvent: @escaping KeyEventPoster = AppSwitcher.postHIDKeyEvent) {
        self.postKeyEvent = postKeyEvent
    }

    func selectInAppSwitcher(restoreMinimizedWindows: Bool = false) {
        if !isCommandDown {
            return
        }
        if restoreMinimizedWindows {
            // Pressing Option before releasing Command restores minimized windows of the selected app.
            postKeyEvent(AppSwitcher.leftOptionKey, true, [.maskCommand, .maskAlternate])
            postKeyEvent(AppSwitcher.leftCommandKey, false, .maskAlternate)
            postKeyEvent(AppSwitcher.leftOptionKey, false, [])
        } else {
            postKeyEvent(AppSwitcher.leftCommandKey, false, [])
        }
        isCommandDown = false
    }

    func cmdTab() {
        pressCommand()
        postKeyEvent(AppSwitcher.tabKey, true, .maskCommand)
        postKeyEvent(AppSwitcher.tabKey, false, .maskCommand)
    }

    func cmdShiftTab() {
        pressCommand()
        postKeyEvent(AppSwitcher.tabKey, true, [.maskCommand, .maskShift])
        postKeyEvent(AppSwitcher.tabKey, false, [.maskCommand, .maskShift])
    }

    private func pressCommand() {
        if isCommandDown {
            return
        }
        postKeyEvent(AppSwitcher.leftCommandKey, true, .maskCommand)
        isCommandDown = true
    }

    static func postHIDKeyEvent(key: CGKeyCode, down: Bool, flags: CGEventFlags) {
        let event = CGEvent(keyboardEventSource: keyboardEventSource, virtualKey: key, keyDown: down)
        event?.flags = flags
        event?.post(tap: CGEventTapLocation.cghidEventTap)
    }
}
