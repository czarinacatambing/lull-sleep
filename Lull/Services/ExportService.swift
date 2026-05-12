import Foundation

// Sends a snapshot of the user's sleep data to a Google Apps Script webhook
// which appends it as a row to a Google Sheet owned by the Lull team.
// No personal identifiers are sent — only a per-install UUID.
enum ExportService {

    // ── Setup ─────────────────────────────────────────────────────────────────
    // 1. In your Lull team Google Sheet, open Extensions → Apps Script.
    // 2. Paste the Apps Script code from the project README into Code.gs.
    // 3. Deploy → New deployment → type "Web app" → execute as "Me" → access
    //    "Anyone". Copy the resulting /exec URL and paste it below.
    // 4. Each "New deployment" gets a new URL, so don't redeploy unless needed.
    static let endpointURL: URL? = URL(string: "https://script.google.com/macros/s/AKfycbwrm03vDYReZeSbfUx0NANpWWpu1TcmECMjc_TVigDIsT7AO_867WMS6irs-ey6_QeArw/exec")
    // ──────────────────────────────────────────────────────────────────────────

    enum ExportError: LocalizedError {
        case notConfigured
        case httpError(Int, String)

        var errorDescription: String? {
            switch self {
            case .notConfigured: return "Export endpoint not configured."
            case .httpError(let code, let body):
                let snippet = body.prefix(120)
                return "HTTP \(code) · \(snippet)"
            }
        }
    }

    struct Payload: Encodable {
        let installId: String
        let exportedAt: Date
        let appVersion: String
        let state: PersistedState
    }

    static func send(installId: String, state: PersistedState) async throws {
        guard let url = endpointURL, !url.absoluteString.isEmpty else {
            throw ExportError.notConfigured
        }

        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let payload = Payload(installId: installId, exportedAt: Date(), appVersion: version, state: state)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try encoder.encode(payload)

        let (data, response) = try await URLSession.shared.data(for: req)
        let bodyText = String(data: data, encoding: .utf8) ?? ""
        print("[ExportService] response: \(response) body: \(bodyText)")
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw ExportError.httpError(http.statusCode, bodyText)
        }
    }
}
