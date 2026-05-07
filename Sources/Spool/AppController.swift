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
    @Published var recordPhase: RecordPhase = .idle

    private var registeredIDs: [UInt32] = []
    private var permTimer: Timer?
    private var cancellables: Set<AnyCancellable> = []
    private var overlay: OverlayController!
    private var countdownTask: Task<Void, Never>?
    private var previousApp: NSRunningApplication?
    private var workspaceObserver: NSObjectProtocol?

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
        observeWorkspace()
        overlay = OverlayController(controller: self)

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

    private func observeWorkspace() {
        let myPID = NSRunningApplication.current.processIdentifier
        if let cur = NSWorkspace.shared.frontmostApplication, cur.processIdentifier != myPID {
            previousApp = cur
        }
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            if app.processIdentifier == NSRunningApplication.current.processIdentifier { return }
            Task { @MainActor [weak self] in
                self?.previousApp = app
            }
        }
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
        guard recorder.state == .idle, recordPhase == .idle else { return }
        guard accessibilityGranted else {
            status = "GRANT ACCESSIBILITY FIRST"
            requestAccessibility()
            return
        }

        countdownTask?.cancel()
        recordPhase = .countdown(3)
        status = "COUNTDOWN…"
        overlay.show()
        hideMainWindow()
        activatePreviousApp()

        countdownTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            for n in stride(from: 3, through: 1, by: -1) {
                if Task.isCancelled { return }
                self.recordPhase = .countdown(n)
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            if Task.isCancelled { return }
            if self.recorder.start() {
                self.recordPhase = .recording
                self.status = "● RECORDING"
            } else {
                self.recordPhase = .idle
                self.overlay.hide()
                self.restoreMainWindow()
                self.status = "TAP FAILED · CHECK PERMISSIONS"
            }
        }
    }

    func pauseToggleAction() {
        switch recorder.state {
        case .recording:
            recorder.pause()
            recordPhase = .paused
            status = "‖ PAUSED"
        case .paused:
            recorder.resume()
            recordPhase = .recording
            status = "● RECORDING"
        case .idle:
            break
        }
    }

    func stopAction() {
        if case .countdown = recordPhase {
            countdownTask?.cancel()
            countdownTask = nil
            recordPhase = .idle
            overlay.hide()
            restoreMainWindow()
            status = "CANCELLED"
            return
        }

        if recorder.state != .idle {
            let result = recorder.stop()
            recordPhase = .idle
            overlay.hide()
            restoreMainWindow()
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

    private func mainWindow() -> NSWindow? {
        NSApp.windows.first { !($0 is NSPanel) && $0.canBecomeMain }
    }

    private func hideMainWindow() {
        mainWindow()?.orderOut(nil)
    }

    private func restoreMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let w = mainWindow() {
            w.makeKeyAndOrderFront(nil)
        }
    }

    private func activatePreviousApp() {
        guard let prev = previousApp,
              prev.processIdentifier != NSRunningApplication.current.processIdentifier,
              !prev.isTerminated else { return }
        prev.activate(options: [])
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
