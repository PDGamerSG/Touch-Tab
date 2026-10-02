import CoreGraphics
import Foundation
import XCTest
@testable import TouchTabCore

// Simulates fingers on the trackpad and feeds frames into a recognizer.
private class Trackpad {
    let recognizer: GestureRecognizer
    private(set) var events: [SwipeEvent] = []
    private var positions: [String: CGPoint] = [:]
    private var resting: Set<String> = []
    var time: TimeInterval = 100
    // Time between two frames. The trackpad reports touches at roughly 100Hz.
    var frameInterval: TimeInterval = 0.01

    init(fingerCount: Int = 3) {
        recognizer = GestureRecognizer(fingerCount: fingerCount)
    }

    func put(_ count: Int, resting restingCount: Int = 0) {
        for i in 0..<count {
            let id = "finger\(positions.count)"
            positions[id] = CGPoint(x: 0.4 + 0.05 * Double(i), y: 0.5)
            if i < restingCount {
                resting.insert(id)
            }
        }
        frame(phase: .began)
    }

    func move(dx: CGFloat, dy: CGFloat = 0, frames: Int = 1) {
        for _ in 0..<frames {
            for (id, position) in positions where !resting.contains(id) {
                positions[id] = CGPoint(x: position.x + dx, y: position.y + dy)
            }
            frame(phase: .moved)
        }
    }

    // Moves the given finger in the opposite direction to the others.
    func moveApart(dx: CGFloat, frames: Int) {
        let ids = positions.keys.sorted()
        for _ in 0..<frames {
            for (index, id) in ids.enumerated() {
                let direction: CGFloat = index == 0 ? -1 : 1
                positions[id] = CGPoint(x: positions[id]!.x + direction * dx, y: positions[id]!.y)
            }
            frame(phase: .moved)
        }
    }

    func wait(_ interval: TimeInterval) {
        time += interval
    }

    func lift(_ count: Int? = nil) {
        let ids = Array(positions.keys.sorted().suffix(count ?? positions.count))
        let touches = positions.map { id, position in
            TouchSample(id: id, position: position, phase: ids.contains(id) ? .ended : .stationary, isResting: resting.contains(id))
        }
        send(touches)
        for id in ids {
            positions.removeValue(forKey: id)
            resting.remove(id)
        }
    }

    func frame(phase: TouchSample.Phase) {
        let touches = positions.map { id, position in
            TouchSample(id: id, position: position, phase: phase, isResting: resting.contains(id))
        }
        send(touches)
    }

    func scroll(_ phase: ScrollPhase = .changed, momentum: Bool = false) -> ScrollAction {
        return recognizer.scrollAction(phase: phase, isMomentum: momentum, time: time)
    }

    func send(_ touches: [TouchSample]) {
        time += frameInterval
        if let event = recognizer.process(touches: touches, time: time) {
            events.append(event)
        }
    }
}

final class GestureRecognizerTests: XCTestCase {
    func testSwipeRightSwitchesToNextApp() {
        let trackpad = Trackpad()
        trackpad.put(3)
        trackpad.move(dx: 0.02, frames: 5)
        trackpad.lift()
        XCTAssertEqual(trackpad.events, [.startOrContinue(.right), .end])
    }

    func testSwipeLeftSwitchesToPreviousApp() {
        let trackpad = Trackpad()
        trackpad.put(3)
        trackpad.move(dx: -0.02, frames: 5)
        trackpad.lift()
        XCTAssertEqual(trackpad.events, [.startOrContinue(.left), .end])
    }

    func testBothDirectionsNeedTheSameDistance() {
        for dx in [CGFloat(0.02), CGFloat(-0.02)] {
            let trackpad = Trackpad()
            trackpad.put(3)
            // Putting the fingers only records positions, so 3 frames make 0.06 which is below the threshold.
            trackpad.move(dx: dx, frames: 3)
            XCTAssertEqual(trackpad.events, [], "dx \(dx)")
            trackpad.move(dx: dx, frames: 1)
            XCTAssertEqual(trackpad.events.count, 1, "dx \(dx)")
        }
    }

    func testShortSwipeDoesNothing() {
        let trackpad = Trackpad()
        trackpad.put(3)
        trackpad.move(dx: 0.01, frames: 3)
        trackpad.lift()
        XCTAssertEqual(trackpad.events, [])
    }

    func testFastSwipeSwitchesOnlyOnceUntilUIIsShown() {
        let trackpad = Trackpad()
        trackpad.put(3)
        // 10 frames take 0.1s which is less than the App Switcher UI delay.
        trackpad.move(dx: 0.05, frames: 10)
        XCTAssertEqual(trackpad.events, [.startOrContinue(.right)])
    }

    func testLongSwipeSwitchesMultipleApps() {
        let trackpad = Trackpad()
        trackpad.put(3)
        trackpad.move(dx: 0.03, frames: 4)
        trackpad.wait(GestureRecognizer.appSwitcherUIDelay)
        trackpad.move(dx: 0.03, frames: 8)
        trackpad.lift()
        XCTAssertGreaterThan(trackpad.events.count, 3)
        XCTAssertEqual(trackpad.events.last, .end)
        XCTAssertTrue(trackpad.events.dropLast().allSatisfy { $0 == .startOrContinue(.right) })
    }

    func testChangingDirectionWithinOneGesture() {
        let trackpad = Trackpad()
        trackpad.put(3)
        trackpad.move(dx: 0.03, frames: 4)
        trackpad.wait(GestureRecognizer.appSwitcherUIDelay)
        trackpad.move(dx: -0.03, frames: 4)
        trackpad.lift()
        XCTAssertEqual(trackpad.events, [.startOrContinue(.right), .startOrContinue(.left), .end])
    }

    func testVerticalSwipeIsIgnored() {
        let trackpad = Trackpad()
        trackpad.put(3)
        trackpad.move(dx: 0.01, dy: 0.05, frames: 10)
        trackpad.lift()
        XCTAssertEqual(trackpad.events, [])
    }

    func testFingersMovingApartAreIgnored() {
        let trackpad = Trackpad()
        trackpad.put(3)
        trackpad.moveApart(dx: 0.05, frames: 10)
        trackpad.lift()
        XCTAssertEqual(trackpad.events, [])
    }

    func testTwoFingersDoNothing() {
        let trackpad = Trackpad()
        trackpad.put(2)
        trackpad.move(dx: 0.05, frames: 10)
        trackpad.lift()
        XCTAssertEqual(trackpad.events, [])
    }

    func testFourFingersDoNothingInThreeFingerMode() {
        let trackpad = Trackpad(fingerCount: 3)
        trackpad.put(4)
        trackpad.move(dx: 0.05, frames: 10)
        trackpad.lift()
        XCTAssertEqual(trackpad.events, [])
    }

    func testFourFingerMode() {
        let trackpad = Trackpad(fingerCount: 4)
        trackpad.put(3)
        trackpad.move(dx: 0.05, frames: 10)
        trackpad.lift()
        XCTAssertEqual(trackpad.events, [], "3 fingers must not switch apps in 4-finger mode")

        trackpad.put(4)
        trackpad.move(dx: 0.02, frames: 5)
        trackpad.lift()
        XCTAssertEqual(trackpad.events, [.startOrContinue(.right), .end])
    }

    func testLiftingOneFingerKeepsAppSwitcherOpenForTwoFingerScrolling() {
        let trackpad = Trackpad()
        trackpad.put(3)
        trackpad.move(dx: 0.02, frames: 5)
        trackpad.lift(1)
        trackpad.move(dx: 0.05, frames: 10)
        XCTAssertEqual(trackpad.events, [.startOrContinue(.right)])
        trackpad.lift()
        XCTAssertEqual(trackpad.events, [.startOrContinue(.right), .end])
    }

    func testRestingThumbIsIgnored() {
        let trackpad = Trackpad()
        // A thumb resting on the trackpad plus 3 swiping fingers.
        trackpad.put(4, resting: 1)
        trackpad.move(dx: -0.02, frames: 5)
        trackpad.lift()
        XCTAssertEqual(trackpad.events, [.startOrContinue(.left), .end])
    }

    func testEmptyTouchEventsAreSkipped() {
        let trackpad = Trackpad()
        trackpad.put(3)
        trackpad.move(dx: 0.02, frames: 5)
        trackpad.send([])
        XCTAssertTrue(trackpad.recognizer.isGestureActive)
        trackpad.lift()
        XCTAssertEqual(trackpad.events, [.startOrContinue(.right), .end])
    }

    func testCancelledTouchesEndTheGesture() {
        let trackpad = Trackpad()
        trackpad.put(3)
        trackpad.move(dx: 0.02, frames: 5)
        trackpad.send((0..<3).map { TouchSample(id: "finger\($0)", position: .zero, phase: .cancelled) })
        XCTAssertEqual(trackpad.events, [.startOrContinue(.right), .end])
    }

    func testConsecutiveGestures() {
        let trackpad = Trackpad()
        for _ in 0..<3 {
            trackpad.put(3)
            trackpad.move(dx: 0.02, frames: 5)
            trackpad.lift()
        }
        XCTAssertEqual(trackpad.events, Array(repeating: [SwipeEvent.startOrContinue(.right), .end], count: 3).flatMap { $0 })
    }

    func testResetEndsActiveGesture() {
        let trackpad = Trackpad()
        trackpad.put(3)
        trackpad.move(dx: 0.02, frames: 5)
        XCTAssertEqual(trackpad.recognizer.reset(), .end)
        XCTAssertFalse(trackpad.recognizer.isGestureActive)
        XCTAssertEqual(trackpad.recognizer.reset(), nil)
    }

    func testResetWithoutGestureDoesNothing() {
        let recognizer = GestureRecognizer(fingerCount: 3)
        XCTAssertEqual(recognizer.reset(), nil)
    }

    // MARK: Scrolling

    func testScrollIsBlockedWhileGestureFingersAreDown() {
        let trackpad = Trackpad()
        trackpad.put(3)
        XCTAssertEqual(trackpad.scroll(), .block)
        XCTAssertTrue(trackpad.recognizer.shouldBlockSwipe)
        trackpad.move(dx: 0.02, frames: 5)
        XCTAssertEqual(trackpad.scroll(), .block)
    }

    func testMomentumAfterBlockedScrollIsBlocked() {
        let trackpad = Trackpad()
        trackpad.put(3)
        XCTAssertEqual(trackpad.scroll(), .block)
        trackpad.lift()
        XCTAssertEqual(trackpad.scroll(momentum: true), .block)
        XCTAssertFalse(trackpad.recognizer.shouldBlockSwipe)
    }

    func testTwoFingerScrollIsNotBlocked() {
        let trackpad = Trackpad()
        trackpad.put(2)
        XCTAssertEqual(trackpad.scroll(), .pass)
        XCTAssertFalse(trackpad.recognizer.shouldBlockSwipe)
        trackpad.lift()
        XCTAssertEqual(trackpad.scroll(momentum: true), .pass)
    }

    func testNewScrollAfterBlockedOneIsNotBlocked() {
        let trackpad = Trackpad()
        trackpad.put(3)
        XCTAssertEqual(trackpad.scroll(), .block)
        trackpad.lift()
        trackpad.put(2)
        XCTAssertEqual(trackpad.scroll(), .pass)
        XCTAssertEqual(trackpad.scroll(momentum: true), .pass)
    }

    func testTwoFingerScrollInAppSwitcherIsNotBlocked() {
        let trackpad = Trackpad()
        trackpad.put(3)
        trackpad.move(dx: 0.02, frames: 5)
        trackpad.wait(GestureRecognizer.appSwitcherUIDelay)
        trackpad.lift(1)
        XCTAssertTrue(trackpad.recognizer.isGestureActive)
        XCTAssertEqual(trackpad.scroll(), .pass)
    }

    func testScrollWhileCommandIsHeldBeforeAppSwitcherUIIsBlocked() {
        let trackpad = Trackpad()
        trackpad.put(3)
        trackpad.move(dx: 0.02, frames: 5)
        trackpad.lift(1)
        XCTAssertTrue(trackpad.recognizer.isGestureActive)
        XCTAssertEqual(trackpad.scroll(.began), .block)
        trackpad.lift()
        XCTAssertEqual(trackpad.scroll(.began), .pass)
    }

    func testScrollStartedBeforeGestureFingersIsEnded() {
        let trackpad = Trackpad()
        // The fingers don't land at the same time, so two of them may start a scroll.
        trackpad.put(2)
        XCTAssertEqual(trackpad.scroll(.began), .pass)
        XCTAssertEqual(trackpad.scroll(.changed), .pass)
        trackpad.put(1)
        XCTAssertEqual(trackpad.scroll(.changed), .end)
        XCTAssertEqual(trackpad.scroll(.changed), .block)
        XCTAssertEqual(trackpad.scroll(momentum: true), .block)
    }

    func testFinishedScrollIsNotEndedAgain() {
        let trackpad = Trackpad()
        trackpad.put(2)
        XCTAssertEqual(trackpad.scroll(.began), .pass)
        XCTAssertEqual(trackpad.scroll(.ended), .pass)
        trackpad.put(1)
        XCTAssertEqual(trackpad.scroll(.began), .block)
    }

    func testRestingThumbAloneEndsGesture() {
        let trackpad = Trackpad()
        trackpad.put(4, resting: 1)
        trackpad.move(dx: 0.02, frames: 5)
        // The frame where the swiping fingers end is missing, only the thumb is reported.
        trackpad.send([TouchSample(id: "finger0", position: CGPoint(x: 0.4, y: 0.5), phase: .stationary, isResting: true)])
        XCTAssertEqual(trackpad.events, [.startOrContinue(.right), .end])
    }

    func testScrollIsNotBlockedAfterReset() {
        let trackpad = Trackpad()
        trackpad.put(3)
        XCTAssertEqual(trackpad.scroll(), .block)
        _ = trackpad.recognizer.reset()
        XCTAssertEqual(trackpad.scroll(momentum: true), .pass)
        XCTAssertEqual(trackpad.scroll(), .pass)
    }

    func testChangingFingerCountForgetsTouches() {
        let trackpad = Trackpad()
        trackpad.put(3)
        trackpad.recognizer.fingerCount = 4
        XCTAssertEqual(trackpad.scroll(), .pass)
    }
}
