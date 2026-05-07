import SwiftUI
import AppKit

struct SavePromptView: View {
    @Binding var name: String
    let duration: TimeInterval
    let count: Int
    let onSave: (String) -> Void
    let onDiscard: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14) {
                Text("// SAVE MACRO")
                    .font(Theme.monoMd.weight(.bold))
                    .foregroundColor(Theme.fg)
                Text("captured \(count) events · \(formatDuration(duration))")
                    .foregroundColor(Theme.muted)
                    .font(Theme.monoSm)

                HStack(spacing: 6) {
                    Text("$").foregroundColor(Theme.dim)
                    TextField("name", text: $name)
                        .textFieldStyle(.plain)
                        .foregroundColor(Theme.fg)
                        .font(Theme.mono)
                        .onSubmit { commit() }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Theme.panel)
                .overlay(Rectangle().stroke(Theme.border, lineWidth: 1))

                HStack {
                    Button("DISCARD") {
                        onDiscard(); dismiss()
                    }.buttonStyle(HackerButtonStyle())
                    Spacer()
                    Button("SAVE") { commit() }
                        .buttonStyle(HackerButtonStyle())
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(20)
            .frame(width: 380)
        }
    }

    private func commit() {
        onSave(name); dismiss()
    }

    private func formatDuration(_ t: TimeInterval) -> String {
        let total = max(0, t)
        let m = Int(total) / 60
        let s = Int(total) % 60
        let cs = Int((total - Double(Int(total))) * 100)
        return String(format: "%02d:%02d.%02d", m, s, cs)
    }
}

struct SettingsView: View {
    @EnvironmentObject var ctrl: AppController
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 12) {
                Text("// HOTKEYS")
                    .font(Theme.monoMd.weight(.bold))
                    .foregroundColor(Theme.fg)
                Text("click a slot, then press a key combo")
                    .foregroundColor(Theme.muted)
                    .font(Theme.monoSm)

                hotkeyRow("RECORD", binding: Binding(
                    get: { ctrl.hotkeyConfig.record },
                    set: { ctrl.hotkeyConfig.record = $0; ctrl.saveHotkeys() }
                ))
                hotkeyRow("PAUSE", binding: Binding(
                    get: { ctrl.hotkeyConfig.pause },
                    set: { ctrl.hotkeyConfig.pause = $0; ctrl.saveHotkeys() }
                ))
                hotkeyRow("STOP", binding: Binding(
                    get: { ctrl.hotkeyConfig.stop },
                    set: { ctrl.hotkeyConfig.stop = $0; ctrl.saveHotkeys() }
                ))
                hotkeyRow("PLAY", binding: Binding(
                    get: { ctrl.hotkeyConfig.play },
                    set: { ctrl.hotkeyConfig.play = $0; ctrl.saveHotkeys() }
                ))

                HStack {
                    Button("RESET DEFAULTS") { ctrl.resetHotkeys() }
                        .buttonStyle(HackerButtonStyle())
                    Spacer()
                    Button("DONE") { dismiss() }
                        .buttonStyle(HackerButtonStyle())
                        .keyboardShortcut(.defaultAction)
                }
                .padding(.top, 8)
            }
            .padding(20)
            .frame(width: 460)
        }
    }

    private func hotkeyRow(_ label: String, binding: Binding<HotkeyDef?>) -> some View {
        HStack {
            Text(label)
                .foregroundColor(Theme.dim)
                .frame(width: 80, alignment: .leading)
            HotkeyCaptureField(hotkey: binding)
            Button("CLEAR") { binding.wrappedValue = nil }
                .buttonStyle(HackerButtonStyle())
        }
    }
}

struct HotkeyCaptureField: View {
    @Binding var hotkey: HotkeyDef?
    @State private var capturing = false
    @State private var monitor: Any?

    var body: some View {
        Button(action: toggle) {
            Text(capturing ? "press a key…" : (hotkey?.label ?? "—"))
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(Theme.mono)
                .foregroundColor(capturing ? Theme.amber : Theme.fg)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(capturing ? Theme.panel : Theme.surface)
                .overlay(Rectangle().stroke(capturing ? Theme.amber : Theme.border, lineWidth: 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onDisappear { stop() }
    }

    private func toggle() {
        if capturing { stop() } else { start() }
    }

    private func start() {
        capturing = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { ev in
            let kc = UInt32(ev.keyCode)
            let mods = KeyMap.carbonModifiers(from: ev.modifierFlags)
            let label = KeyMap.label(keyCode: ev.keyCode, modifiers: ev.modifierFlags)
            hotkey = HotkeyDef(keyCode: kc, modifiers: mods, label: label)
            stop()
            return nil
        }
    }

    private func stop() {
        capturing = false
        if let m = monitor { NSEvent.removeMonitor(m) }
        monitor = nil
    }
}
