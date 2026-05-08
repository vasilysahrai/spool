import AppKit
import SwiftUI

enum RecordPhase: Equatable {
    case idle
    case countdown(Int)
    case recording
    case paused
}

@MainActor
final class OverlayController {
    private var window: NSWindow?
    private weak var ctrl: AppController?
    private let size = NSSize(width: 200, height: 200)

    init(controller: AppController) {
        self.ctrl = controller
    }

    func show() {
        if window == nil { build() }
        positionTopLeft()
        window?.alphaValue = 1.0
        window?.setIsVisible(true)
        window?.orderFrontRegardless()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) { [weak self] in
            self?.window?.orderFrontRegardless()
        }
    }

    func hide() {
        window?.orderOut(nil)
    }

    private func build() {
        guard let ctrl = ctrl else { return }
        let w = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        w.level = .floating
        w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        w.isOpaque = false
        w.backgroundColor = .clear
        w.hasShadow = true
        w.ignoresMouseEvents = true
        w.hidesOnDeactivate = false
        w.isReleasedWhenClosed = false
        w.isMovable = false
        w.acceptsMouseMovedEvents = false

        let view = OverlayView().environmentObject(ctrl)
        let host = NSHostingView(rootView: AnyView(view))
        host.frame = NSRect(origin: .zero, size: size)
        host.autoresizingMask = [.width, .height]
        w.contentView = host
        self.window = w
    }

    private func positionTopLeft() {
        guard let w = window, let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let visible = screen.visibleFrame
        let margin: CGFloat = 16
        let originX = visible.origin.x + margin
        let originY = visible.maxY - size.height - margin
        w.setFrame(NSRect(origin: NSPoint(x: originX, y: originY), size: size), display: true)
    }
}

struct OverlayView: View {
    @EnvironmentObject var ctrl: AppController
    @State private var nowTick: Date = Date()
    private let tick = Timer.publish(every: 1.0/30.0, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(borderColor.opacity(0.5)).frame(height: 1)
            ZStack {
                bigDisplay
                if case .recording = ctrl.recordPhase {
                    blinkingDot
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            Rectangle().fill(borderColor.opacity(0.5)).frame(height: 1)
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg)
        .overlay(Rectangle().stroke(borderColor, lineWidth: 2))
        .onReceive(tick) { _ in nowTick = Date() }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text(stateGlyph)
                .foregroundColor(stateColor)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
            Text(stateLabel)
                .foregroundColor(stateColor)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
            Spacer()
            Text("SPOOL")
                .foregroundColor(Theme.muted)
                .font(.system(size: 12, design: .monospaced))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var footer: some View {
        HStack {
            Text(footerText)
                .foregroundColor(Theme.muted)
                .font(.system(size: 11, design: .monospaced))
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var bigDisplay: some View {
        Group {
            switch ctrl.recordPhase {
            case .countdown(let n):
                Text("\(n)")
                    .font(.system(size: 100, weight: .semibold, design: .monospaced))
                    .foregroundColor(Theme.amber)
                    .transition(.scale.combined(with: .opacity))
                    .id(n)
            case .recording:
                Text(formatStopwatch(ctrl.recorder.elapsed))
                    .font(.system(size: 28, weight: .medium, design: .monospaced))
                    .foregroundColor(Theme.accent)
            case .paused:
                Text(formatStopwatch(ctrl.recorder.elapsed))
                    .font(.system(size: 28, weight: .medium, design: .monospaced))
                    .foregroundColor(Theme.amber)
            case .idle:
                Text("—")
                    .font(.system(size: 28, weight: .medium, design: .monospaced))
                    .foregroundColor(Theme.muted)
            }
        }
        .animation(.easeOut(duration: 0.18), value: ctrl.recordPhase)
    }

    private var blinkingDot: some View {
        let on = Int(nowTick.timeIntervalSinceReferenceDate * 2) % 2 == 0
        return VStack {
            HStack {
                Spacer()
                Text("●")
                    .font(.system(size: 10))
                    .foregroundColor(on ? Theme.accent : Color.clear)
                    .padding(.trailing, 8)
                    .padding(.top, 6)
            }
            Spacer()
        }
    }

    private var stateGlyph: String {
        switch ctrl.recordPhase {
        case .countdown: return "⏲"
        case .recording: return "●"
        case .paused:    return "‖"
        case .idle:      return "◌"
        }
    }

    private var stateLabel: String {
        switch ctrl.recordPhase {
        case .countdown: return "READY"
        case .recording: return "REC"
        case .paused:    return "PAUSED"
        case .idle:      return "IDLE"
        }
    }

    private var stateColor: Color {
        switch ctrl.recordPhase {
        case .countdown: return Theme.amber
        case .recording: return Theme.accent
        case .paused:    return Theme.amber
        case .idle:      return Theme.muted
        }
    }

    private var borderColor: Color {
        switch ctrl.recordPhase {
        case .countdown: return Theme.amber
        case .recording: return Theme.accent
        case .paused:    return Theme.amber
        case .idle:      return Theme.border
        }
    }

    private var footerText: String {
        switch ctrl.recordPhase {
        case .countdown: return "alt-tab to your app"
        case .recording: return "ev: \(ctrl.recorder.events.count) · F8 to stop"
        case .paused:    return "press resume"
        case .idle:      return "—"
        }
    }

    private func formatStopwatch(_ t: TimeInterval) -> String {
        let total = max(0, t)
        let m = Int(total) / 60
        let s = Int(total) % 60
        let cs = Int((total - Double(Int(total))) * 100)
        return String(format: "%02d:%02d.%02d", m, s, cs)
    }
}
