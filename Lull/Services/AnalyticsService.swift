import Foundation

enum AnalyticsService {
    typealias Properties = [String: String]

    private struct Config {
        let apiKey: String
        let host: URL

        static var current: Config? {
            let info = Bundle.main.infoDictionary ?? [:]
            let enabled = AnalyticsService.infoBool(info["LullAnalyticsEnabled"], defaultValue: true)
            guard enabled else { return nil }
            guard let key = info["LullPostHogAPIKey"] as? String,
                  !key.isEmpty,
                  !key.contains("$("),
                  !key.contains("YOUR_") else {
                return nil
            }
            let hostString = (info["LullPostHogHost"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let host = URL(string: hostString?.isEmpty == false ? hostString! : "https://us.i.posthog.com")
                ?? URL(string: "https://us.i.posthog.com")!
            return Config(apiKey: key, host: host)
        }
    }

    static func infoBool(_ value: Any?, defaultValue: Bool) -> Bool {
        if let bool = value as? Bool { return bool }
        guard let string = value as? String else { return defaultValue }
        let normalized = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.contains("$(") { return false }
        switch normalized {
        case "1", "true", "yes": return true
        case "0", "false", "no", "": return false
        default:
            return defaultValue
        }
    }

    private struct CaptureRequest: Encodable {
        let apiKey: String
        let event: String
        let distinctId: String
        let properties: Properties

        enum CodingKeys: String, CodingKey {
            case apiKey = "api_key"
            case event
            case distinctId = "distinct_id"
            case properties
        }
    }

    static func track(_ event: String,
                      installId: String,
                      properties: Properties = [:]) {
        guard let config = Config.current else { return }
        var merged = baseProperties()
        properties.forEach { merged[$0.key] = $0.value }

        Task.detached(priority: .utility) {
            await send(
                CaptureRequest(
                    apiKey: config.apiKey,
                    event: event,
                    distinctId: installId,
                    properties: merged
                ),
                to: config.host
            )
        }
    }

    private static func send(_ payload: CaptureRequest, to host: URL) async {
        let url = host.appendingPathComponent("capture/")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONEncoder().encode(payload)
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                #if DEBUG
                print("[AnalyticsService] capture failed HTTP \(http.statusCode)")
                #endif
            }
        } catch {
            #if DEBUG
            print("[AnalyticsService] capture failed: \(error.localizedDescription)")
            #endif
        }
    }

    private static func baseProperties() -> Properties {
        [
            "app_version": Bundle.main.lullAppVersion,
            "app_build": Bundle.main.lullBuildNumber,
            "platform": "ios",
            "telemetry_schema": "1"
        ]
    }
}

extension Bundle {
    var lullAppVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    var lullBuildNumber: String {
        infoDictionary?["CFBundleVersion"] as? String ?? "?"
    }
}
