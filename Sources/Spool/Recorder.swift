import Cocoa
import CoreGraphics

final class MacroRecorder: ObservableObject {
    enum State: String { case idle, recording, paused }

    @Published private(set) var state: State = .idle
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var events: [MacroEvent] = []

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var startDate: Date?
    private var accumulated: TimeInterval = 0
    private var graceUntil: Date?
    private var timer: Timer?
    private let ownPID: pid_t = ProcessInfo.processInfo.processIdentifier

    private static let modKeycodeToMask: [UInt16: UInt64] = [
        56: CGEventFlags.maskShift.rawValue,
        60: CGEventFlags.maskShift.rawValue,
        59: CGEventFlags.maskControl.rawValue,
        62: CGEventFlags.maskControl.rawValue,
        58: CGEventFlags.maskAlternate.rawValue,
        61: CGEventFlags.maskAlternate.rawValue,
        55: CGEventFlags.maskCommand.rawValue,
        54: CGEventFlags.maskCommand.rawValue,
        57: CGEventFlags.maskAlphaShift.rawValue,
        63: CGEventFlags.maskSecondaryFn.rawValue
    ]

    @discardableResult
    func start() -> Bool {
        guard state == .idle else { return true }
        if !installTap() { return false }
        events = []
        accumulated = 0
        startDate = Date()
        graceUntil = Date().addingTimeInterval(0.30)
        state = .recording
        startTimer()
        return true
    }

    func pause() {
        guard state == .recording else { return }
        if let s = startDate {
            accumulated += Date().timeIntervalSince(s)
        }
        startDate = nil
        state = .paused
    }

    func resume() {
        guard state == .paused else { return }
        startDate = Date()
        graceUntil = Date().addingTimeInterval(0.20)
        state = .recording
    }

    @discardableResult
    func stop() -> (events: [MacroEvent], duration: TimeInterval) {
        if state == .recording, let s = startDate {
            accumulated += Date().timeIntervalSince(s)
        }
        let dur = accumulated
        let out = events
        startDate = nil
        accumulated = 0
        events = []
        elapsed = 0
        state = .idle
        stopTimer()
        removeTap()
        return (out, dur)
    }

    func cancel() {
        startDate = nil
        accumulated = 0
        events = []
        elapsed = 0
        state = .idle
        stopTimer()
        removeTap()
    }

    private var currentTime: TimeInterval {
        if state == .recording, let s = startDate {
            return accumulated + Date().timeIntervalSince(s)
        }
        return accumulated
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0/30.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.elapsed = self.currentTime
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func installTap() -> Bool {
        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue)        |
            (1 << CGEventType.keyUp.rawValue)          |
            (1 << CGEventType.flagsChanged.rawValue)   |
            (1 << CGEventType.leftMouseDown.rawValue)  |
            (1 << CGEventType.leftMouseUp.rawValue)    |
            (1 << CGEventType.rightMouseDown.rawValue) |
            (1 << CGEventType.rightMouseUp.rawValue)

        guard let t = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                let r = Unmanaged<MacroRecorder>.fromOpaque(refcon).takeUnretainedValue()
                r.handle(type: type, event: event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }
        self.tap = t
        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, t, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: t, enable: true)
        self.runLoopSource = src
        return true
    }

    private func removeTap() {
        if let src = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes)
        }
        if let t = tap { CGEvent.tapEnable(tap: t, enable: false) }
        tap = nil
        runLoopSource = nil
    }

    private func handle(type: CGEventType, event: CGEvent) {
        guard state == .recording else { return }
        if let g = graceUntil, Date() < g { return }
        let pid = pid_t(event.getIntegerValueField(.eventSourceUnixProcessID))
        if pid == ownPID { return }
        let t = currentTime
        let flags = event.flags.rawValue
        var ev: MacroEvent?
        switch type {
        case .keyDown:
            let kc = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            ev = MacroEvent(kind: .keyDown, time: t, keyCode: kc, modifiers: flags, x: nil, y: nil)
        case .keyUp:
            let kc = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            ev = MacroEvent(kind: .keyUp, time: t, keyCode: kc, modifiers: flags, x: nil, y: nil)
        case .flagsChanged:
            let kc = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            if let mask = Self.modKeycodeToMask[kc] {
                let pressed = (flags & mask) != 0
                ev = MacroEvent(kind: pressed ? .keyDown : .keyUp, time: t, keyCode: kc, modifiers: flags, x: nil, y: nil)
            }
        case .leftMouseDown:
            let p = event.location
            ev = MacroEvent(kind: .mouseDown, time: t, keyCode: 0, modifiers: flags, x: p.x, y: p.y)
        case .leftMouseUp:
            let p = event.location
            ev = MacroEvent(kind: .mouseUp, time: t, keyCode: 0, modifiers: flags, x: p.x, y: p.y)
        case .rightMouseDown:
            let p = event.location
            ev = MacroEvent(kind: .mouseDown, time: t, keyCode: 1, modifiers: flags, x: p.x, y: p.y)
        case .rightMouseUp:
            let p = event.location
            ev = MacroEvent(kind: .mouseUp, time: t, keyCode: 1, modifiers: flags, x: p.x, y: p.y)
        default:
            break
        }
        if let ev = ev {
            DispatchQueue.main.async { [weak self] in
                self?.events.append(ev)
            }
        }
    }
}
