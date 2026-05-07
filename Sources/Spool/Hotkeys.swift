import AppKit
import Carbon.HIToolbox

final class HotkeyManager {
    typealias Action = () -> Void

    private var actions: [UInt32: Action] = [:]
    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var handler: EventHandlerRef?
    private var nextID: UInt32 = 1

    init() {
        installHandler()
    }

    deinit {
        for (_, ref) in refs { UnregisterEventHotKey(ref) }
        if let h = handler { RemoveEventHandler(h) }
    }

    private func installHandler() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, evtRef, userData -> OSStatus in
            guard let evtRef = evtRef, let userData = userData else { return noErr }
            let mgr = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            var hkID = EventHotKeyID()
            GetEventParameter(evtRef,
                              EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID),
                              nil,
                              MemoryLayout<EventHotKeyID>.size,
                              nil,
                              &hkID)
            DispatchQueue.main.async {
                mgr.actions[hkID.id]?()
            }
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }

    @discardableResult
    func register(keyCode: UInt32, modifiers: UInt32, action: @escaping Action) -> UInt32? {
        let id = nextID
        nextID += 1
        let sig: OSType = 0x53504C00 // 'SPL\0'
        let hkID = EventHotKeyID(signature: sig, id: id)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(keyCode, modifiers, hkID, GetApplicationEventTarget(), 0, &ref)
        if status == noErr, let r = ref {
            refs[id] = r
            actions[id] = action
            return id
        }
        return nil
    }

    func unregister(id: UInt32) {
        if let r = refs[id] {
            UnregisterEventHotKey(r)
            refs[id] = nil
            actions[id] = nil
        }
    }

    func unregisterAll() {
        for (id, _) in refs { unregister(id: id) }
    }
}
