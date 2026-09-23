import Cocoa

class SwipeManager {
    private static let eventsOfInterest: CGEventMask =
        NSEvent.EventTypeMask.gesture.rawValue |
        NSEvent.EventTypeMask.scrollWheel.rawValue |
        NSEvent.EventTypeMask.swipe.rawValue

    private static var eventTap: CFMachPort? = nil
    private static var runLoopSource: CFRunLoopSource? = nil
    private static let recognizer = GestureRecognizer(fingerCount: Settings.fingerCount)
    private static let appSwitcher = AppSwitcher()

    //TODO: move it somewhere else?
    private static func listener(_ event: SwipeEvent?) {
        switch event {
        case .startOrContinue(.left):
            appSwitcher.cmdShiftTab()
            performHapticFeedback()
        case .startOrContinue(.right):
            appSwitcher.cmdTab()
            performHapticFeedback()
        case .end:
            appSwitcher.selectInAppSwitcher(restoreMinimizedWindows: Settings.restoreMinimizedWindows)
        case nil:
            break
        }
    }

    private static func performHapticFeedback() {
        if Settings.hapticFeedback {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }
    }

    static var fingerCount: Int {
        get { return recognizer.fingerCount }
        set {
            reset()
            recognizer.fingerCount = newValue
        }
    }

    static func start() {
        if eventTap != nil {
            debugPrint("SwipeManager is already started")
            return
        }
        debugPrint("SwipeManager start")
        eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventsOfInterest,
            callback: { proxy, type, cgEvent, userInfo in
                return SwipeManager.eventHandler(proxy: proxy, eventType: type, cgEvent: cgEvent, userInfo: userInfo)
            },
            userInfo: nil
        )
        guard let eventTap = eventTap else {
            debugPrint("SwipeManager couldn't create event tap")
            return
        }

        runLoopSource = CFMachPortCreateRunLoopSource(nil, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, CFRunLoopMode.commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    static func stop() {
        reset()
        guard let tap = eventTap else {
            return
        }
        debugPrint("SwipeManager stop")
        CGEvent.tapEnable(tap: tap, enable: false)
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, CFRunLoopMode.commonModes)
        }
        CFMachPortInvalidate(tap)
        runLoopSource = nil
        eventTap = nil
    }

    static func restart() {
        stop()
        start()
    }

    // The event tap may silently die after sleep, user switching or permission changes. Recreate or re-enable it if needed.
    static func ensureRunning() {
        guard let tap = eventTap, CFMachPortIsValid(tap) else {
            debugPrint("SwipeManager event tap is missing or invalid, recreating")
            restart()
            return
        }
        if !CGEvent.tapIsEnabled(tap: tap) {
            debugPrint("SwipeManager event tap is disabled, enabling")
            CGEvent.tapEnable(tap: tap, enable: true)
            if !CGEvent.tapIsEnabled(tap: tap) {
                restart()
            }
        }
    }

    // Finishes the current gesture (if any) so Command is never left pressed.
    static func reset() {
        listener(recognizer.reset())
    }

    private static func eventHandler(proxy: CGEventTapProxy, eventType: CGEventType, cgEvent: CGEvent, userInfo: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
        if eventType == .tapDisabledByUserInput || eventType == .tapDisabledByTimeout {
            debugPrint("SwipeManager tap disabled", eventType.rawValue)
            // Some touches may have been missed so start from scratch.
            reset()
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(cgEvent)
        }

        if eventType == .scrollWheel {
            let isMomentum = cgEvent.getIntegerValueField(.scrollWheelEventMomentumPhase) != 0
            return recognizer.shouldBlockScroll(isMomentum: isMomentum) ? nil : Unmanaged.passUnretained(cgEvent)
        }

        if eventType.rawValue == NSEvent.EventType.swipe.rawValue {
            return recognizer.shouldBlockSwipe ? nil : Unmanaged.passUnretained(cgEvent)
        }

        if eventType.rawValue == NSEvent.EventType.gesture.rawValue, let nsEvent = NSEvent(cgEvent: cgEvent) {
            let touches = nsEvent.allTouches().map(SwipeManager.touchSample)
            listener(recognizer.process(touches: touches, time: nsEvent.timestamp))
        }
        return Unmanaged.passUnretained(cgEvent)
    }

    private static func touchSample(_ touch: NSTouch) -> TouchSample {
        let phase: TouchSample.Phase
        switch touch.phase {
        case .began: phase = .began
        case .stationary: phase = .stationary
        case .ended: phase = .ended
        case .cancelled: phase = .cancelled
        default: phase = .moved
        }
        return TouchSample(id: "\(touch.identity)", position: touch.normalizedPosition, phase: phase, isResting: touch.isResting)
    }
}
