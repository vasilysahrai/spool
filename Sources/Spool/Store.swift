import Foundation

final class MacroStore: ObservableObject {
    @Published private(set) var macros: [Macro] = []
    private let url: URL

    init() {
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Spool", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        self.url = dir.appendingPathComponent("macros.json")
        load()
    }

    func load() {
        guard let data = try? Data(contentsOf: url) else { return }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        if let arr = try? dec.decode([Macro].self, from: data) {
            macros = arr.sorted { $0.createdAt > $1.createdAt }
        }
    }

    func save() {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        if let data = try? enc.encode(macros) {
            try? data.write(to: url, options: .atomic)
        }
    }

    func add(_ m: Macro) {
        macros.insert(m, at: 0)
        save()
    }

    func delete(_ m: Macro) {
        macros.removeAll { $0.id == m.id }
        save()
    }

    func rename(_ m: Macro, to newName: String) {
        guard let i = macros.firstIndex(where: { $0.id == m.id }) else { return }
        macros[i].name = newName
        save()
    }
}
