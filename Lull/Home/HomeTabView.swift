import SwiftUI

struct HomeTabView: View {
    @EnvironmentObject var state: AppState
    @State private var selectedTab: Int

    init() { _selectedTab = State(initialValue: 0) }
    init(initialTab: Int) { _selectedTab = State(initialValue: initialTab) }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                DashboardView(selectedTab: $selectedTab)
                    .tag(0)
                MyRoutineView()
                    .tag(1)
                MidSleepModeView()
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            // Custom tab bar
            HStack(spacing: 0) {
                TabBarButton(title: "Tonight", icon: "moon.fill", selected: selectedTab == 0) {
                    selectedTab = 0
                }
                TabBarButton(title: "Routine", icon: "flask.fill", selected: selectedTab == 1) {
                    selectedTab = 1
                }
                TabBarButton(title: "Mid-sleep", icon: "moon.zzz.fill", selected: selectedTab == 2) {
                    selectedTab = 2
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
            .background(
                Color.lullBg1
                    .opacity(0.95)
                    .ignoresSafeArea(edges: .bottom)
            )
            .overlay(alignment: .top) {
                Color.lullLine.frame(height: 1)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        // Shake / programmatic activation → jump to tab 2
        .onChange(of: state.showMidSleepMode) { _, active in
            if active {
                selectedTab = 2
                state.showMidSleepMode = false
            }
        }
        // Restore brightness when navigating away from Mid-sleep
        .onChange(of: selectedTab) { oldTab, newTab in
            if oldTab == 2 && newTab != 2 {
                state.restoreBrightnessAfterMidSleep()
            }
        }
        // External tab-switch requests (e.g. after dismissing the promotion celebration)
        .onChange(of: state.requestedTab) { _, requested in
            if let requested {
                selectedTab = requested
                state.requestedTab = nil
            }
        }
    }
}

struct TabBarButton: View {
    var title: String
    var icon: String
    var selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(selected ? .lullAmber : .lullInk3)
                Text(title)
                    .font(.system(size: 11))
                    .foregroundColor(selected ? .lullAmber : .lullInk3)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }
}
