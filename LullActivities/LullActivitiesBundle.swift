import WidgetKit
import SwiftUI

@main
struct LullActivitiesBundle: WidgetBundle {
    var body: some Widget {
        PrepChecklistActivityWidget()
        SleepCompanionWidget()
    }
}
