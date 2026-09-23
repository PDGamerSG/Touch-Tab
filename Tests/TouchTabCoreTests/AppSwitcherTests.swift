import CoreGraphics
import Foundation
import XCTest
@testable import TouchTabCore

private struct KeyEvent: Equatable {
    let key: CGKeyCode
    let down: Bool
    let flags: CGEventFlags

    static func == (lhs: KeyEvent, rhs: KeyEvent) -> Bool {
        return lhs.key == rhs.key && lhs.down == rhs.down && lhs.flags.rawValue == rhs.flags.rawValue
    }
}

final class AppSwitcherTests: XCTestCase {
    private var posted: [KeyEvent] = []
    private var appSwitcher: AppSwitcher!

    private let tab = AppSwitcher.tabKey
    private let command = AppSwitcher.leftCommandKey
    private let option = AppSwitcher.leftOptionKey

    override func setUp() {
        super.setUp()
        posted = []
        appSwitcher = AppSwitcher { [unowned self] key, down, flags in
            self.posted.append(KeyEvent(key: key, down: down, flags: flags))
        }
    }

    func testCmdTabHoldsCommandUntilSelection() {
        appSwitcher.cmdTab()
        XCTAssertTrue(appSwitcher.isCommandDown)
        appSwitcher.selectInAppSwitcher()
        XCTAssertFalse(appSwitcher.isCommandDown)
        XCTAssertEqual(posted, [
            KeyEvent(key: command, down: true, flags: .maskCommand),
            KeyEvent(key: tab, down: true, flags: .maskCommand),
            KeyEvent(key: tab, down: false, flags: .maskCommand),
            KeyEvent(key: command, down: false, flags: []),
        ])
    }

    func testCmdShiftTab() {
        appSwitcher.cmdShiftTab()
        appSwitcher.selectInAppSwitcher()
        XCTAssertEqual(posted, [
            KeyEvent(key: command, down: true, flags: .maskCommand),
            KeyEvent(key: tab, down: true, flags: [.maskCommand, .maskShift]),
            KeyEvent(key: tab, down: false, flags: [.maskCommand, .maskShift]),
            KeyEvent(key: command, down: false, flags: []),
        ])
    }

    func testCommandIsPressedOnlyOncePerGesture() {
        appSwitcher.cmdTab()
        appSwitcher.cmdTab()
        appSwitcher.cmdShiftTab()
        appSwitcher.selectInAppSwitcher()
        XCTAssertEqual(posted.filter { $0.key == command && $0.down }.count, 1)
        XCTAssertEqual(posted.filter { $0.key == command && !$0.down }.count, 1)
        XCTAssertEqual(posted.filter { $0.key == tab && $0.down }.count, 3)
        XCTAssertEqual(posted.first, KeyEvent(key: command, down: true, flags: .maskCommand))
        XCTAssertEqual(posted.last, KeyEvent(key: command, down: false, flags: []))
    }

    func testSelectWithoutSwitchDoesNothing() {
        appSwitcher.selectInAppSwitcher()
        appSwitcher.selectInAppSwitcher(restoreMinimizedWindows: true)
        XCTAssertEqual(posted, [])
    }

    func testSelectTwiceReleasesCommandOnce() {
        appSwitcher.cmdTab()
        appSwitcher.selectInAppSwitcher()
        appSwitcher.selectInAppSwitcher()
        XCTAssertEqual(posted.filter { $0.key == command && !$0.down }.count, 1)
    }

    func testRestoreMinimizedWindowsPressesOptionBeforeReleasingCommand() {
        appSwitcher.cmdTab()
        posted = []
        appSwitcher.selectInAppSwitcher(restoreMinimizedWindows: true)
        XCTAssertEqual(posted, [
            KeyEvent(key: option, down: true, flags: [.maskCommand, .maskAlternate]),
            KeyEvent(key: command, down: false, flags: .maskAlternate),
            KeyEvent(key: option, down: false, flags: []),
        ])
        XCTAssertFalse(appSwitcher.isCommandDown)
    }

    func testNextGesturePressesCommandAgain() {
        appSwitcher.cmdTab()
        appSwitcher.selectInAppSwitcher()
        posted = []
        appSwitcher.cmdShiftTab()
        XCTAssertEqual(posted.first, KeyEvent(key: command, down: true, flags: .maskCommand))
    }
}
