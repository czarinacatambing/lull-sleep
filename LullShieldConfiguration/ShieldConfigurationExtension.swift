import ManagedSettings
import ManagedSettingsUI
import UIKit

final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    private let appGroupSuite = "group.com.trylull.app"
    private let wakeTimeKey = "tenthirty_shieldWakeTimeText"
    private let lockReasonKey = "tenthirty_shieldLockReason"

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        shieldConfiguration(systemIcon: super.configuration(shielding: application).icon)
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        shieldConfiguration(systemIcon: super.configuration(shielding: application, in: category).icon)
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        shieldConfiguration(systemIcon: super.configuration(shielding: webDomain).icon)
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        shieldConfiguration(systemIcon: super.configuration(shielding: webDomain, in: category).icon)
    }

    private func shieldConfiguration(systemIcon: UIImage?) -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: UIColor(red: 0.05, green: 0.03, blue: 0.02, alpha: 1),
            // Preserve iOS's shielded-app icon and native lock badge while
            // customizing the surrounding TenThirty copy and colors.
            icon: systemIcon,
            title: ShieldConfiguration.Label(
                text: titleText,
                color: UIColor(red: 1.0, green: 0.96, blue: 0.90, alpha: 1)
            ),
            subtitle: ShieldConfiguration.Label(
                text: subtitleText,
                color: UIColor(red: 0.78, green: 0.70, blue: 0.62, alpha: 1)
            )
        )
    }

    private var titleText: String {
        switch lockReason {
        case "rule":
            return "TenThirty has locked this app."
        case "sleep_window":
            return "TenThirty is protecting your sleep from doomscrolling."
        default:
            return "Scroll-lock is active."
        }
    }

    private var subtitleText: String {
        switch lockReason {
        case "rule":
            return "You missed a commitment and have to first complete it before gaining access to this app."
        case "sleep_window":
            return "We're protecting your sleep. You can access this app outside your sleep window."
        default:
            return "We're protecting your sleep. You can access this app outside your sleep window."
        }
    }

    private var wakeTimeText: String {
        UserDefaults(suiteName: appGroupSuite)?.string(forKey: wakeTimeKey) ?? "your wake time"
    }

    private var lockReason: String {
        UserDefaults(suiteName: appGroupSuite)?.string(forKey: lockReasonKey) ?? "sleep_window"
    }

}
