import SwiftUI

struct HomeTabView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject private var sleepSoundsAudio: SleepSoundsAudioStore
    @State private var selectedTab: Int

    init() { _selectedTab = State(initialValue: 0) }
    init(initialTab: Int) { _selectedTab = State(initialValue: initialTab) }

    private var miniPlayerVisible: Bool {
        sleepSoundsAudio.isPlaying
    }

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
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear
                    .frame(height: miniPlayerVisible ? SleepSoundsMiniPlayerLayout.reservedHeight : 0)
            }

            // Custom tab bar
            HStack(spacing: 0) {
                TabBarButton(title: "Today", icon: "moon.fill", selected: selectedTab == 0) {
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

            if miniPlayerVisible {
                SleepSoundsMiniPlayer {
                    state.showSleepSounds = true
                }
                .padding(.horizontal, 16)
                .padding(.bottom, SleepSoundsMiniPlayerLayout.bottomAboveTabBar)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(2)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .animation(.easeInOut(duration: 0.22), value: miniPlayerVisible)
        // Shake / programmatic activation → jump to tab 2
        .onChange(of: state.showMidSleepMode) { _, active in
            if active {
                sleepSoundsAudio.stop()
                selectedTab = 2
                state.showMidSleepMode = false
            }
        }
        // Catch the cold-launch race: if the Live Activity / URL handler set
        // showMidSleepMode = true before this view mounted (welcome splash up),
        // onChange never fired. Pick it up on first appear.
        .onAppear {
            if state.showMidSleepMode {
                sleepSoundsAudio.stop()
                selectedTab = 2
                state.showMidSleepMode = false
            }
            if let requested = state.requestedTab {
                selectedTab = requested
                state.requestedTab = nil
            }
        }
        // Restore brightness when navigating away from Mid-sleep
        .onChange(of: selectedTab) { oldTab, newTab in
            if newTab == 2 {
                sleepSoundsAudio.stop()
            }
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
