import Foundation
import XCTest
@testable import TouchTabCore

final class SettingsTests: XCTestCase {
    private let suiteName = "TouchTabCoreTests.Settings"
    private var originalDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        originalDefaults = Settings.defaults
        UserDefaults().removePersistentDomain(forName: suiteName)
        Settings.defaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() {
        UserDefaults().removePersistentDomain(forName: suiteName)
        Settings.defaults = originalDefaults
        super.tearDown()
    }

    func testDefaults() {
        XCTAssertEqual(Settings.fingerCount, 3)
        XCTAssertFalse(Settings.hapticFeedback)
        XCTAssertFalse(Settings.restoreMinimizedWindows)
    }

    func testFingerCountIsStored() {
        Settings.fingerCount = 4
        XCTAssertEqual(Settings.fingerCount, 4)
        Settings.fingerCount = 3
        XCTAssertEqual(Settings.fingerCount, 3)
    }

    func testUnsupportedFingerCountFallsBackToThree() {
        for value in [0, 1, 2, 5, -1] {
            Settings.defaults.set(value, forKey: "fingerCount")
            XCTAssertEqual(Settings.fingerCount, 3, "value \(value)")
        }
    }

    func testTogglesAreStored() {
        Settings.hapticFeedback = true
        Settings.restoreMinimizedWindows = true
        XCTAssertTrue(Settings.hapticFeedback)
        XCTAssertTrue(Settings.restoreMinimizedWindows)
        Settings.hapticFeedback = false
        XCTAssertFalse(Settings.hapticFeedback)
    }
}
