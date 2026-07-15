import ManagedSettings
import ManagedSettingsUI
import UIKit

final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    private let appGroupSuite = "group.com.trylull.app"
    private let wakeTimeKey = "tenthirty_shieldWakeTimeText"
    private let lockReasonKey = "tenthirty_shieldLockReason"
    private let ruleTitleKey = "tenthirty_shieldRuleTitle"

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        shieldConfiguration()
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        shieldConfiguration()
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        shieldConfiguration()
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        shieldConfiguration()
    }

    private func shieldConfiguration() -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: UIColor(red: 0.05, green: 0.03, blue: 0.02, alpha: 1),
            icon: UIImage(systemName: "moon.stars.fill"),
            title: ShieldConfiguration.Label(
                text: "Scroll-lock is active.",
                color: UIColor(red: 1.0, green: 0.96, blue: 0.90, alpha: 1)
            ),
            subtitle: ShieldConfiguration.Label(
                text: subtitleText,
                color: UIColor(red: 0.78, green: 0.70, blue: 0.62, alpha: 1)
            )
        )
    }

    private var subtitleText: String {
        switch lockReason {
        case "rule":
            if let ruleTitle, !ruleTitle.isEmpty {
                return "Open TenThirty and confirm \(ruleTitle) to start recovery."
            }
            return "Open TenThirty and confirm your rule to start recovery."
        case "sleep_window":
            return "Your sleep window is protected until \(wakeTimeText)."
        default:
            return "TenThirty is protecting your scroll-lock window until \(wakeTimeText)."
        }
    }

    private var wakeTimeText: String {
        UserDefaults(suiteName: appGroupSuite)?.string(forKey: wakeTimeKey) ?? "your wake time"
    }

    private var lockReason: String {
        UserDefaults(suiteName: appGroupSuite)?.string(forKey: lockReasonKey) ?? "sleep_window"
    }

    private var ruleTitle: String? {
        UserDefaults(suiteName: appGroupSuite)?.string(forKey: ruleTitleKey)
    }
}
