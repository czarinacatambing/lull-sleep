import Foundation

enum ResearchValue: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case stringArray([String])
    case intArray([Int])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([Int].self) {
            self = .intArray(value)
        } else if let value = try? container.decode([String].self) {
            self = .stringArray(value)
        } else {
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):      try container.encode(value)
        case .int(let value):         try container.encode(value)
        case .double(let value):      try container.encode(value)
        case .bool(let value):        try container.encode(value)
        case .stringArray(let value): try container.encode(value)
        case .intArray(let value):    try container.encode(value)
        case .null:                   try container.encodeNil()
        }
    }
}

struct ResearchEventEnvelope: Codable, Identifiable {
    var id = UUID()
    var eventName: String
    var installId: String
    var occurredAt: Date
    var appVersion: String
    var appBuild: String
    var schemaVersion: Int
    var payload: [String: ResearchValue]
}

actor ResearchDataService {
    static let shared = ResearchDataService()

    private struct Config {
        let endpoint: URL
        let token: String?

        static var current: Config? {
            let info = Bundle.main.infoDictionary ?? [:]
            let enabled = info["LullResearchDataEnabled"] as? Bool ?? true
            guard enabled else { return nil }
            guard let endpointString = info["LullResearchDataEndpoint"] as? String,
                  !endpointString.isEmpty,
                  !endpointString.contains("YOUR_"),
                  let endpoint = URL(string: endpointString) else {
                return nil
            }
            let token = (info["LullResearchDataToken"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return Config(endpoint: endpoint, token: token?.isEmpty == false ? token : nil)
        }
    }

    private let outboxURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private init() {
        outboxURL = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("lull_research_outbox.json")

        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func submit(eventName: String,
                installId: String,
                payload: [String: ResearchValue]) async {
        let event = ResearchEventEnvelope(
            eventName: eventName,
            installId: installId,
            occurredAt: Date(),
            appVersion: Bundle.main.lullAppVersion,
            appBuild: Bundle.main.lullBuildNumber,
            schemaVersion: 1,
            payload: payload
        )

        guard let config = Config.current else { return }
        do {
            try await post(event, config: config)
        } catch {
            await enqueue(event)
        }
    }

    func flushQueued() async {
        guard let config = Config.current else { return }
        let queued = loadQueue()
        guard !queued.isEmpty else { return }

        var failed: [ResearchEventEnvelope] = []
        for event in queued {
            do {
                try await post(event, config: config)
            } catch {
                failed.append(event)
            }
        }
        saveQueue(failed)
    }

    private func post(_ event: ResearchEventEnvelope, config: Config) async throws {
        var request = URLRequest(url: config.endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = config.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try encoder.encode(event)

        let (_, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
    }

    private func enqueue(_ event: ResearchEventEnvelope) async {
        var queued = loadQueue()
        queued.append(event)
        saveQueue(queued)
    }

    private func loadQueue() -> [ResearchEventEnvelope] {
        guard let data = try? Data(contentsOf: outboxURL) else { return [] }
        return (try? decoder.decode([ResearchEventEnvelope].self, from: data)) ?? []
    }

    private func saveQueue(_ events: [ResearchEventEnvelope]) {
        if events.isEmpty {
            try? FileManager.default.removeItem(at: outboxURL)
            return
        }
        guard let data = try? encoder.encode(events) else { return }
        let tmp = outboxURL.appendingPathExtension("tmp")
        try? data.write(to: tmp, options: .atomic)
        _ = try? FileManager.default.replaceItemAt(outboxURL, withItemAt: tmp)
    }
}
