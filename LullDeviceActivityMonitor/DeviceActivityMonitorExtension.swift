import DeviceActivity
import Foundation

final class LullDeviceActivityMonitorExtension: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        AppBlockingMonitorStore.applyShield(for: activity)
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        AppBlockingMonitorStore.applyCurrentShield()
    }
}
