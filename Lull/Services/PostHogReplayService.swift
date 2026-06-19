import Foundation
import PostHog

enum PostHogReplayService {
    private static var didConfigure = false

    static func configureIfNeeded(installId: String) {
        guard !didConfigure, let config = Config.current else { return }
        didConfigure = true

        let postHogConfig = PostHogConfig(projectToken: config.apiKey, host: config.host.absoluteString)
        postHogConfig.sessionReplay = true
        postHogConfig.sessionReplayConfig.screenshotMode = true
        postHogConfig.sessionReplayConfig.maskAllTextInputs = true
        postHogConfig.sessionReplayConfig.maskAllImages = true

        // Keep the existing manual event pipeline as the canonical analytics source.
        postHogConfig.captureApplicationLifecycleEvents = false
        postHogConfig.captureScreenViews = false
        postHogConfig.captureElementInteractions = false

        PostHogSDK.shared.setup(postHogConfig)
        PostHogSDK.shared.identify(
            installId,
            userProperties: [
                "app_version": Bundle.main.lullAppVersion,
                "app_build": Bundle.main.lullBuildNumber,
                "platform": "ios"
            ]
        )
    }

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
}
