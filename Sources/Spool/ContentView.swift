import SwiftUI

struct ContentView: View {
    @EnvironmentObject var ctrl: AppController
    @State private var showSettings = false
    @State private var saveName = ""
    @State private var nowTick: Date = Date()
    @State private var renamingID: UUID?
    @State private var renameDraft: String = ""

    private let tick = Timer.publish(every: 1.0/30.0, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack(alignment: .top) {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                Rectangle().fill(Theme.border).frame(height: 1)
                if !ctrl.accessibilityGranted { permissionBanner }
                HSplitView {
                    leftPane
                        .frame(minWidth: 280, idealWidth: 320)
                    rightPane
                        .frame(minWidth: 360)
                }
            }
        }
        .background(WindowAccessor { window in
            ctrl.mainWindowRef = window
        })
        .foregroundColor(Theme.fg)
        .font(Theme.mono)
        .onReceive(tick) { _ in nowTick = Date() }
        .sheet(isPresented: Binding(
            get: { ctrl.pendingEvents != nil },
            set: { if !$0 { ctrl.discardPending() } }
        )) {
            SavePromptView(name: $saveName, duration: ctrl.pendingDuration, count: ctrl.pendingEvents?.count ?? 0) { final in
                ctrl.saveMacro(name: final)
                saveName = ""
            } onDiscard: {
                ctrl.discardPending()
                saveName = ""
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView().environmentObject(ctrl)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("◉ SPOOL")
                .font(Theme.monoMd.weight(.bold))
                .foregroundColor(Theme.fg)
            Text("//")
                .foregroundColor(Theme.muted)
            Text("macro recorder")
                .foregroundColor(Theme.dim)
            Spacer()
            Text("[ \(ctrl.status) ]")
                .foregroundColor(statusColor)
                .font(Theme.mono)
            Button(action: { showSettings = true }) {
                Text("⚙ HOTKEYS")
                    .font(Theme.mono)
            }
            .buttonStyle(HackerButtonStyle())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Theme.surface)
    }

    private var statusColor: Color {
        switch ctrl.recorder.state {
        case .recording: return Theme.accent
        case .paused: return Theme.amber
        case .idle: return ctrl.player.state == .playing ? Theme.amber : Theme.dim
        }
    }

    private var permissionBanner: some View {
        HStack {
            Text("⚠ ACCESSIBILITY PERMISSION REQUIRED")
                .foregroundColor(Theme.amber)
            Spacer()
            Button("GRANT") { ctrl.requestAccessibility() }
                .buttonStyle(HackerButtonStyle())
            Button("OPEN SYSTEM SETTINGS") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(HackerButtonStyle())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.4))
        .overlay(Rectangle().stroke(Theme.amber.opacity(0.4), lineWidth: 1))
    }

    // MARK: - Left pane: macro list

    private var leftPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("// MACROS [\(ctrl.store.macros.count)]")
                    .foregroundColor(Theme.dim)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Theme.surface)

            Rectangle().fill(Theme.border).frame(height: 1)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if ctrl.store.macros.isEmpty {
                        emptyState
                    } else {
                        ForEach(ctrl.store.macros) { m in
                            macroRow(m)
                            Rectangle().fill(Theme.border.opacity(0.4)).frame(height: 1)
                        }
                    }
                }
            }
            .background(Theme.bg)
        }
        .background(Theme.bg)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("$ no macros yet")
                .foregroundColor(Theme.muted)
            Text("press [\(ctrl.hotkeyConfig.record?.label ?? "—")] to start recording")
                .foregroundColor(Theme.muted)
                .font(Theme.monoSm)
        }
        .padding(14)
    }

    private func macroRow(_ m: Macro) -> some View {
        let selected = ctrl.selectedMacroID == m.id
        let renaming = renamingID == m.id
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(selected ? ">" : " ")
                    .foregroundColor(Theme.fg)
                if renaming {
                    TextField("name", text: $renameDraft, onCommit: {
                        ctrl.rename(m, to: renameDraft)
                        renamingID = nil
                    })
                    .textFieldStyle(.plain)
                    .foregroundColor(Theme.fg)
                    .font(Theme.mono)
                    .onExitCommand { renamingID = nil }
                } else {
                    Text(m.name)
                        .foregroundColor(selected ? Theme.fg : Theme.dim)
                        .lineLimit(1)
                }
                Spacer()
                if ctrl.player.nowPlaying?.id == m.id {
                    Text("▶")
                        .foregroundColor(Theme.amber)
                }
            }
            HStack(spacing: 8) {
                Text(formatDuration(m.duration))
                Text("·")
                Text("\(m.events.count) ev")
                Text("·")
                Text(formatDate(m.createdAt))
            }
            .foregroundColor(Theme.muted)
            .font(Theme.monoSm)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(selected ? Theme.panel : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            renameDraft = m.name
            renamingID = m.id
        }
        .onTapGesture {
            ctrl.selectedMacroID = m.id
        }
        .contextMenu {
            Button("PLAY") { ctrl.play(m) }
            Button("RENAME") {
                renameDraft = m.name
                renamingID = m.id
            }
            Divider()
            Button("DELETE", role: .destructive) { ctrl.delete(m) }
        }
    }

    // MARK: - Right pane: stopwatch + controls

    private var rightPane: some View {
        VStack(spacing: 18) {
            stopwatchPanel
            controlsPanel
            hotkeyHints
            Spacer()
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.bg)
    }

    private var stopwatchTime: TimeInterval {
        if ctrl.recorder.state != .idle {
            return ctrl.recorder.elapsed
        }
        if ctrl.player.state == .playing, let m = ctrl.player.nowPlaying {
            return m.duration
        }
        return 0
    }

    private var stopwatchPanel: some View {
        VStack(spacing: 8) {
            HStack {
                Text("// STOPWATCH")
                    .foregroundColor(Theme.dim)
                Spacer()
                Text(stateLabel)
                    .foregroundColor(stateColor)
            }
            Text(formatStopwatch(stopwatchTime))
                .font(Theme.monoXL.weight(.medium))
                .foregroundColor(stopwatchColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(Theme.panel)
                .overlay(Rectangle().stroke(Theme.border, lineWidth: 1))
            HStack {
                Text("events: \(ctrl.recorder.events.count)")
                Spacer()
                if ctrl.recorder.state == .recording {
                    blinkingDot
                }
            }
            .foregroundColor(Theme.muted)
            .font(Theme.monoSm)
        }
        .padding(14)
        .background(Theme.surface)
        .overlay(Rectangle().stroke(Theme.border, lineWidth: 1))
    }

    private var stateLabel: String {
        switch ctrl.recorder.state {
        case .recording: return "● REC"
        case .paused:    return "‖ PAUSED"
        case .idle:      return ctrl.player.state == .playing ? "▶ PLAY" : "◌ IDLE"
        }
    }

    private var stateColor: Color {
        switch ctrl.recorder.state {
        case .recording: return Theme.accent
        case .paused:    return Theme.amber
        case .idle:      return ctrl.player.state == .playing ? Theme.amber : Theme.muted
        }
    }

    private var stopwatchColor: Color {
        switch ctrl.recorder.state {
        case .recording: return Theme.accent
        case .paused:    return Theme.amber
        case .idle:      return ctrl.player.state == .playing ? Theme.amber : Theme.fg
        }
    }

    private var blinkingDot: some View {
        let on = Int(nowTick.timeIntervalSinceReferenceDate * 2) % 2 == 0
        return Text("●").foregroundColor(on ? Theme.accent : Color.clear)
    }

    private var controlsPanel: some View {
        HStack(spacing: 10) {
            ControlButton(
                label: "RECORD",
                glyph: "●",
                tint: Theme.accent,
                disabled: ctrl.recorder.state != .idle || ctrl.player.state == .playing
            ) {
                ctrl.startRecording()
            }
            ControlButton(
                label: ctrl.recorder.state == .paused ? "RESUME" : "PAUSE",
                glyph: ctrl.recorder.state == .paused ? "▶" : "‖",
                tint: Theme.amber,
                disabled: ctrl.recorder.state == .idle
            ) {
                ctrl.pauseToggleAction()
            }
            ControlButton(
                label: "STOP",
                glyph: "■",
                tint: Theme.fg,
                disabled: ctrl.recorder.state == .idle && ctrl.player.state == .idle
            ) {
                ctrl.stopAction()
            }
            ControlButton(
                label: "PLAY",
                glyph: "▶",
                tint: Theme.fg,
                disabled: ctrl.store.macros.isEmpty || ctrl.recorder.state != .idle
            ) {
                ctrl.playAction()
            }
        }
    }

    private var hotkeyHints: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("// HOTKEYS")
                .foregroundColor(Theme.dim)
            HStack(spacing: 14) {
                hotkeyRow("REC",   ctrl.hotkeyConfig.record?.label)
                hotkeyRow("PAUSE", ctrl.hotkeyConfig.pause?.label)
                hotkeyRow("STOP",  ctrl.hotkeyConfig.stop?.label)
                hotkeyRow("PLAY",  ctrl.hotkeyConfig.play?.label)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .overlay(Rectangle().stroke(Theme.border, lineWidth: 1))
    }

    private func hotkeyRow(_ label: String, _ key: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).foregroundColor(Theme.muted).font(Theme.monoSm)
            Text(key ?? "—").foregroundColor(Theme.fg)
        }
    }

    // MARK: - Helpers

    private func formatStopwatch(_ t: TimeInterval) -> String {
        let total = max(0, t)
        let m = Int(total) / 60
        let s = Int(total) % 60
        let cs = Int((total - Double(Int(total))) * 100)
        return String(format: "%02d:%02d.%02d", m, s, cs)
    }

    private func formatDuration(_ t: TimeInterval) -> String {
        let total = max(0, t)
        let m = Int(total) / 60
        let s = Int(total) % 60
        return String(format: "%dm%02ds", m, s)
    }

    private func formatDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d HH:mm"
        return f.string(from: d)
    }
}

// MARK: - Window capture

struct WindowAccessor: NSViewRepresentable {
    let onResolved: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        DispatchQueue.main.async {
            onResolved(v.window)
        }
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if nsView.window != nil {
            DispatchQueue.main.async {
                onResolved(nsView.window)
            }
        }
    }
}

// MARK: - Buttons

struct HackerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.mono)
            .foregroundColor(Theme.fg)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(configuration.isPressed ? Theme.panel : Theme.surface)
            .overlay(Rectangle().stroke(Theme.border, lineWidth: 1))
            .contentShape(Rectangle())
    }
}

struct ControlButton: View {
    let label: String
    let glyph: String
    let tint: Color
    let disabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(glyph)
                    .font(Theme.monoLg)
                    .foregroundColor(disabled ? Theme.muted : tint)
                Text(label)
                    .font(Theme.monoSm)
                    .foregroundColor(disabled ? Theme.muted : Theme.fg)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Theme.surface)
            .overlay(Rectangle().stroke(disabled ? Theme.border.opacity(0.4) : Theme.border, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}
