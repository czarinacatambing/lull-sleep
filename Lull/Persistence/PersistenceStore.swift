import Foundation

final class PersistenceStore {
    static let shared = PersistenceStore()
    private init() {}

    private let fileURL: URL = FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("lull_state.json")

    func load() -> PersistedState? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(PersistedState.self, from: data)
        } catch {
            #if DEBUG
            print("PersistenceStore: decode failed — \(error)")
            #endif
            return nil
        }
    }

    func save(_ snapshot: PersistedState) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(snapshot) else { return }
        // Atomic write: write to .tmp then rename so a mid-write crash can't corrupt.
        let tmp = fileURL.appendingPathExtension("tmp")
        try? data.write(to: tmp, options: .atomic)
        _ = try? FileManager.default.replaceItemAt(fileURL, withItemAt: tmp)
    }
}
