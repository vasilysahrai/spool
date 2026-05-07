import Cocoa
import CoreGraphics

final class MacroPlayer: ObservableObject {
    enum State: String { case idle, playing }

    @Published private(set) var state: State = .idle
    @Published private(set) var nowPlaying: Macro?

    private var task: Task<Void, Never>?

    func play(_ macro: Macro) {
        guard state == .idle else { return }
        state = .playing
        nowPlaying = macro
        let events = macro.events
        task = Task.detached(priority: .userInitiated) { [weak self] in
            guard let strong = self else { return }
            await strong.run(events: events)
            await MainActor.run { [weak strong] in
                strong?.state = .idle
                strong?.nowPlaying = nil
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        state = .idle
        nowPlaying = nil
        releaseHeldKeys()
    }

    private func run(events: [MacroEvent]) async {
        let startNS = DispatchTime.now().uptimeNanoseconds
        var heldKeys: Set<UInt16> = []
        var heldMouse: Set<Int> = []
        var lastMouse: CGPoint?

        for ev in events {
            if Task.isCancelled { break }
            let targetNS = startNS &+ UInt64(max(0, ev.time) * 1_000_000_000)
            let nowNS = DispatchTime.now().uptimeNanoseconds
            if targetNS > nowNS {
                let sleepNS = targetNS - nowNS
                try? await Task.sleep(nanoseconds: sleepNS)
            }
            if Task.isCancelled { break }

            switch ev.kind {
            case .keyDown:
                if let kc = ev.keyCode {
                    postKey(keyCode: kc, down: true, flags: ev.modifiers ?? 0)
                    heldKeys.insert(kc)
                }
            case .keyUp:
                if let kc = ev.keyCode {
                    postKey(keyCode: kc, down: false, flags: ev.modifiers ?? 0)
                    heldKeys.remove(kc)
                }
            case .mouseDown:
                if let x = ev.x, let y = ev.y {
                    let p = CGPoint(x: x, y: y)
                    if lastMouse != p {
                        postMouseMove(to: p)
                        lastMouse = p
                    }
                    let btn = Int(ev.keyCode ?? 0)
                    postMouse(to: p, button: btn, down: true, flags: ev.modifiers ?? 0)
                    heldMouse.insert(btn)
                }
            case .mouseUp:
                if let x = ev.x, let y = ev.y {
                    let p = CGPoint(x: x, y: y)
                    let btn = Int(ev.keyCode ?? 0)
                    postMouse(to: p, button: btn, down: false, flags: ev.modifiers ?? 0)
                    heldMouse.remove(btn)
                    lastMouse = p
                }
            }
        }

        if Task.isCancelled {
            for kc in heldKeys { postKey(keyCode: kc, down: false, flags: 0) }
            for btn in heldMouse {
                if let p = lastMouse {
                    postMouse(to: p, button: btn, down: false, flags: 0)
                }
            }
        }
    }

    private func releaseHeldKeys() {}

    private func postKey(keyCode: UInt16, down: Bool, flags: UInt64) {
        let src = CGEventSource(stateID: .hidSystemState)
        guard let e = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(keyCode), keyDown: down) else { return }
        e.flags = CGEventFlags(rawValue: flags)
        e.post(tap: .cghidEventTap)
    }

    private func postMouseMove(to p: CGPoint) {
        let src = CGEventSource(stateID: .hidSystemState)
        guard let e = CGEvent(mouseEventSource: src, mouseType: .mouseMoved, mouseCursorPosition: p, mouseButton: .left) else { return }
        e.post(tap: .cghidEventTap)
    }

    private func postMouse(to p: CGPoint, button: Int, down: Bool, flags: UInt64) {
        let src = CGEventSource(stateID: .hidSystemState)
        let mb: CGMouseButton = button == 1 ? .right : .left
        let etype: CGEventType
        switch (button, down) {
        case (1, true):  etype = .rightMouseDown
        case (1, false): etype = .rightMouseUp
        case (_, true):  etype = .leftMouseDown
        case (_, false): etype = .leftMouseUp
        }
        guard let e = CGEvent(mouseEventSource: src, mouseType: etype, mouseCursorPosition: p, mouseButton: mb) else { return }
        e.flags = CGEventFlags(rawValue: flags)
        e.post(tap: .cghidEventTap)
    }
}
