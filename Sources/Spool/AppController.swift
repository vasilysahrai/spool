import SwiftUI
import Combine
import ApplicationServices

@MainActor
final class AppController: ObservableObject {
    let recorder = MacroRecorder()
    let player = MacroPlayer()
    let store = MacroStore()
    private let hotkeys = HotkeyManager()

    @Published var hotkeyConfig: HotkeyConfig = .default
    @Published var pendingEvents: [MacroEvent]? = nil
    @Published var pendingDuration: TimeInterval = 0
    @Published var status: String = "READY"
    @Published var selectedMacroID: UUID?
    @Published var accessibilityGranted: Bool = AXIsProcessTrusted()

    private var registeredIDs: [UInt32] = []
    private var permTimer: Timer?
    private var cancellables: Set<AnyCancellable> = []

    private let hotkeyURL: URL = {
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Spool", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("hotkeys.json")
    }()

    init() {
        loadHotkeys()
        registerAllHotkeys()
        startPermissionPoll()

        recorder.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        player.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        store.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    private func startPermissionPoll() {
        permTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                let g = AXIsProcessTrusted()
                if g != self.accessibilityGranted {
                    self.accessibilityGranted = g
                }
            }
        }
    }

    func requestAccessibility() {
        let key = "AXTrustedCheckOptionPrompt" as CFString
        let opts: NSDictionary = [key: kCFBooleanTrue as Any]
        _ = AXIsProcessTrustedWithOptions(opts)
    }

    func registerAllHotkeys() {
        hotkeys.unregisterAll()
        registeredIDs.removeAll()
        if let h = hotkeyConfig.record,
           let id = hotkeys.register(keyCode: h.keyCode, modifiers: h.modifiers, action: { [weak self] in self?.recordToggleAction() }) {
            registeredIDs.append(id)
        }
        if let h = hotkeyConfig.pause,
           let id = hotkeys.register(keyCode: h.keyCode, modifiers: h.modifiers, action: { [weak self] in self?.pauseToggleAction() }) {
            registeredIDs.append(id)
        }
        if let h = hotkeyConfig.stop,
           let id = hotkeys.register(keyCode: h.keyCode, modifiers: h.modifiers, action: { [weak self] in self?.stopAction() }) {
            registeredIDs.append(id)
        }
        if let h = hotkeyConfig.play,
           let id = hotkeys.register(keyCode: h.keyCode, modifiers: h.modifiers, action: { [weak self] in self?.playAction() }) {
            registeredIDs.append(id)
        }
    }

    func recordToggleAction() {
        switch recorder.state {
        case .idle:
            startRecording()
        case .recording, .paused:
            stopAction()
        }
    }

    func startRecording() {
        guard recorder.state == .idle else { return }
        guard accessibilityGranted else {
            status = "GRANT ACCESSIBILITY FIRST"
            requestAccessibility()
            return
        }
        if recorder.start() {
            status = "● RECORDING"
        } else {
            status = "TAP FAILED · CHECK PERMISSIONS"
        }
    }

    func pauseToggleAction() {
        switch recorder.state {
        case .recording:
            recorder.pause()
            status = "‖ PAUSED"
        case .paused:
            recorder.resume()
            status = "● RECORDING"
        case .idle:
            break
        }
    }

    func stopAction() {
        if recorder.state != .idle {
            let result = recorder.stop()
            pendingDuration = result.duration
            if result.events.isEmpty {
                pendingEvents = nil
                status = "EMPTY · DISCARDED"
            } else {
                pendingEvents = result.events
                status = "SAVE MACRO?"
            }
        } else if player.state == .playing {
            player.stop()
            status = "PLAYBACK STOPPED"
        }
    }

    func playAction() {
        if player.state == .playing {
            player.stop()
            status = "PLAYBACK STOPPED"
            return
        }
        let target: Macro? = {
            if let id = selectedMacroID, let m = store.macros.first(where: { $0.id == id }) { return m }
            return store.macros.first
        }()
        guard let m = target else {
            status = "NO MACRO TO PLAY"
            return
        }
        player.play(m)
        status = "▶ PLAYING · \(m.name)"
    }

    func play(_ macro: Macro) {
        selectedMacroID = macro.id
        if player.state == .playing { player.stop() }
        player.play(macro)
        status = "▶ PLAYING · \(macro.name)"
    }

    func saveMacro(name: String) {
        guard let events = pendingEvents else { return }
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let final = n.isEmpty ? defaultName() : n
        let m = Macro(name: final, events: events, duration: pendingDuration, createdAt: Date())
        store.add(m)
        selectedMacroID = m.id
        pendingEvents = nil
        status = "SAVED · \(final)"
    }

    func discardPending() {
        pendingEvents = nil
        status = "DISCARDED"
    }

    func delete(_ m: Macro) {
        store.delete(m)
        if selectedMacroID == m.id { selectedMacroID = store.macros.first?.id }
    }

    func rename(_ m: Macro, to name: String) {
        store.rename(m, to: name)
    }

    func loadHotkeys() {
        if let data = try? Data(contentsOf: hotkeyURL),
           let cfg = try? JSONDecoder().decode(HotkeyConfig.self, from: data) {
            hotkeyConfig = cfg
        }
    }

    func saveHotkeys() {
        if let data = try? JSONEncoder().encode(hotkeyConfig) {
            try? data.write(to: hotkeyURL, options: .atomic)
        }
        registerAllHotkeys()
    }

    func resetHotkeys() {
        hotkeyConfig = .default
        saveHotkeys()
    }

    private func defaultName() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmmss"
        return "macro-\(f.string(from: Date()))"
    }
}
