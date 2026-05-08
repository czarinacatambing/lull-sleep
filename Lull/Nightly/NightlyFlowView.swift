import SwiftUI
import UIKit

// Nightly walkthrough coordinator — forward-only, no back button.
struct NightlyFlowView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            let steps = state.nightlyFlowSteps
            if state.nightlyStep < steps.count {
                switch steps[state.nightlyStep] {
                case .brightnessCheck:               NightlyBrightnessView()
                case .temperatureLog:                NightlyTemperatureView()
                case .brainDump:                     NightlyBrainDumpView()
                case .boringStory:                   NightlyBoringStoryView()
                case .fourSevenEightBreathing:       NightlyBreathingView()
                case .gratitudeJournal:              NightlyGratitudeJournalView()
                case .gentleStretching:              NightlyGentleStretchingView()
                case .progressiveMuscleRelaxation:   NightlyProgressiveMuscleRelaxationView()
                case .existingHabit(let label):      NightlyGenericStepView(label: label)
                case .avoidReminder:                 EmptyView()
                }
            } else {
                Color.lullBg.ignoresSafeArea()
                    .onAppear {
                        state.updateTodayLog { $0.actualBedtime = Date(); $0.completedNightlyFlow = true }
                        state.scheduleMidSleepNotification()
                        state.nightlyStep = 0
                        dismiss()
                    }
            }
        }
        .animation(.easeInOut(duration: 0.45), value: state.nightlyStep)
    }
}

// MARK: - Step 1: Brightness Check

struct NightlyBrightnessView: View {
    @EnvironmentObject var state: AppState
    @StateObject private var lightService = AmbientLightService()
    @State private var selectedLevel: Int? = nil
    @State private var detectedSource: LightsLevelSource = .selfReported

    private let levels: [(label: String, hint: String, icon: String)] = [
        ("Bright",       "like full overhead lights", "sun.max"),
        ("Half-dim",     "some lamps off",             "sun.min"),
        ("Warm dim",     "just warm bulbs",            "moon"),
        ("Mostly dark",  "nearly lights-out",          "moon.fill"),
    ]

    var body: some View {
        LullScreen(glow: false) {
            AmberGlow(x: 0.5, y: 0.3, radius: 210, opacity: 0.45)
                .ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer().frame(height: 16)
                NightlyStepHeader(
                    step: state.nightlyStep + 1,
                    total: state.nightlyStepTotal,
                    label: "Brightness",
                    time: state.scheduledTime(for: "Brightness check")
                )

                VStack(spacing: 12) {
                    Kicker(text: lightService.isReading ? "Detecting..." : (lightService.confidence == .high ? "Auto-detected" : "Quick check"))

                    if lightService.isReading {
                        Text("Reading the room...")
                            .font(.serifItalic(28))
                            .foregroundColor(.lullInk2)
                            .multilineTextAlignment(.center)
                    } else if lightService.confidence == .high, let level = selectedLevel {
                        VStack(alignment: .center, spacing: 0) {
                            Text("We detected:")
                                .font(.serif(28))
                                .foregroundColor(.lullInk0)
                            Text(levels[level].label)
                                .font(.serifItalic(28))
                                .foregroundColor(.lullAmber)
                        }
                    } else {
                        (Text("How bright is it ")
                            .foregroundColor(.lullInk0)
                        + Text("in here?")
                            .foregroundColor(.lullAmber))
                        .font(.serif(28))
                        .multilineTextAlignment(.center)
                    }

                    if !lightService.isReading {
                        Text("This helps us understand how your environment affects your sleep.")
                            .font(.system(size: 13.5))
                            .foregroundColor(.lullInk2)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                            .frame(maxWidth: 290)
                    }
                }
                .padding(.horizontal, 28)
                .multilineTextAlignment(.center)
                .animation(.easeInOut, value: lightService.isReading)

                Spacer()

                if !lightService.isReading {
                    VStack(spacing: 10) {
                        ForEach(Array(levels.enumerated()), id: \.offset) { i, level in
                            Button(action: {
                                selectedLevel = i
                                if lightService.confidence != .high { detectedSource = .selfReported }
                            }) {
                                HStack(spacing: 16) {
                                    Image(systemName: level.icon)
                                        .font(.system(size: 18))
                                        .foregroundColor(selectedLevel == i ? .lullAmber : .lullInk3)
                                        .frame(width: 28)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(level.label)
                                            .font(.system(size: 15.5))
                                            .foregroundColor(selectedLevel == i ? .lullInk0 : .lullInk1)
                                        Text(level.hint)
                                            .font(.system(size: 12))
                                            .foregroundColor(.lullInk3)
                                    }
                                    Spacer()
                                    if selectedLevel == i { Ember(size: 6) }
                                }
                                .padding(.horizontal, 22).padding(.vertical, 16)
                                .background(RoundedRectangle(cornerRadius: 18)
                                    .fill(selectedLevel == i
                                        ? LinearGradient(colors: [Color.lullAmber.opacity(0.10), Color.lullAmber.opacity(0.02)], startPoint: .top, endPoint: .bottom)
                                        : LinearGradient(colors: [Color.white.opacity(0.025), Color.white.opacity(0.025)], startPoint: .top, endPoint: .bottom)))
                                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(
                                    selectedLevel == i ? Color.lullAmber.opacity(0.5) : Color.lullLine, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 22)
                    .transition(.opacity)
                }

                Spacer()

                VStack(spacing: 0) {
                    PrimaryCTA(title: "Continue", disabled: selectedLevel == nil) {
                        if let level = selectedLevel {
                            state.updateTodayLog {
                                $0.lightsLevel = level
                                $0.lightsLevelSource = detectedSource
                            }
                        }
                        state.recordCurrentStepAttempt(status: .completed)
                        state.nightlyStep += 1
                    }
                    .opacity(selectedLevel == nil ? 0.45 : 1)
                    GhostButton(title: "Skip") {
                        state.recordCurrentStepAttempt(status: .skipped)
                        state.nightlyStep += 1
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 36)
            }
        }
        .task {
            let result = await lightService.read()
            if result.confidence != .fallback {
                selectedLevel = result.lightsLevel
                detectedSource = result.confidence == .high ? .sensor : .selfReported
            }
        }
    }
}

// MARK: - Step 2: Temperature Log

struct NightlyTemperatureView: View {
    @EnvironmentObject var state: AppState

    private let options: [(label: String, colorHex: String)] = [
        ("Cool — could use a layer",   "#7ba2c7"),
        ("Just right",                  "#f0b96b"),
        ("Warm — slightly stuffy",      "#d99a4a"),
        ("Hot — kicking covers off",    "#c66f4a"),
    ]

    var body: some View {
        LullScreen(glow: false) {
            AmberGlow(x: 0.2, y: 0.8, radius: 210, opacity: 0.4)
                .ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer().frame(height: 16)
                NightlyStepHeader(
                    step: state.nightlyStep + 1,
                    total: state.nightlyStepTotal,
                    label: "Temperature",
                    time: state.scheduledTime(for: "Temperature check")
                )

                VStack(alignment: .leading, spacing: 10) {
                    Kicker(text: "Quick log")
                    Group {
                        Text("How does the room ")
                            .foregroundColor(.lullInk0)
                        + Text("feel?")
                            .foregroundColor(.lullAmber)
                    }
                    .font(.serif(26))

                    Text("Just gut-feel. We'll correlate with your sleep score later.")
                        .font(.system(size: 13.5))
                        .foregroundColor(.lullInk2)
                        .lineSpacing(3)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 34)

                VStack(spacing: 10) {
                    ForEach(Array(options.enumerated()), id: \.offset) { i, opt in
                        Button(action: { state.selectedTemp = i }) {
                            HStack(spacing: 16) {
                                Circle()
                                    .fill(RadialGradient(
                                        colors: [Color(hex: opt.colorHex), .clear],
                                        center: .center, startRadius: 0, endRadius: 16))
                                    .frame(width: 32, height: 32)
                                    .opacity(0.9)
                                Text(opt.label)
                                    .font(.system(size: 15.5))
                                    .foregroundColor(state.selectedTemp == i ? .lullInk0 : .lullInk1)
                                Spacer()
                                if state.selectedTemp == i { Ember(size: 6) }
                            }
                            .padding(.horizontal, 22)
                            .padding(.vertical, 20)
                            .background(
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(state.selectedTemp == i
                                        ? LinearGradient(colors: [Color.lullAmber.opacity(0.10), Color.lullAmber.opacity(0.02)],
                                                         startPoint: .top, endPoint: .bottom)
                                        : LinearGradient(colors: [Color.white.opacity(0.025), Color.white.opacity(0.025)],
                                                         startPoint: .top, endPoint: .bottom))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .strokeBorder(state.selectedTemp == i
                                                  ? Color.lullAmber.opacity(0.5)
                                                  : Color.lullLine, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 22)

                Spacer()

                PrimaryCTA(title: "Continue") {
                    state.updateTodayLog { $0.perceivedTemp = state.selectedTemp }
                    state.recordCurrentStepAttempt(status: .completed)
                    state.nightlyStep += 1
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 36)
            }
        }
    }
}

// MARK: - Step 3: Brain Dump

struct NightlyBrainDumpView: View {
    @EnvironmentObject var state: AppState
    @StateObject private var recorder = AudioRecordingService()
    @State private var showDoneMessage = false
    @State private var pulsePhase: CGFloat = 0
    @State private var pulseTimer: Timer?

    var body: some View {
        LullScreen(glow: false) {
            AmberGlow(x: 0.5, y: 0.5, radius: 260, opacity: 0.55)
                .ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer().frame(height: 16)
                NightlyStepHeader(
                    step: state.nightlyStep + 1,
                    total: state.nightlyStepTotal,
                    label: "Brain Dump",
                    time: state.scheduledTime(for: R.brainDump)
                )

                // Permission denied state
                if recorder.permission == .denied {
                    MicPermissionDeniedView()
                    Spacer()
                } else {
                    VStack(spacing: 12) {
                        Kicker(text: showDoneMessage ? "It's recorded." : "Voice-only · 2 min")
                        (Text("Get it out of ")
                            .foregroundColor(.lullInk0)
                        + Text("your head.")
                            .foregroundColor(.lullAmber))
                        .font(.serif(28))
                        .multilineTextAlignment(.center)

                        Text(showDoneMessage
                             ? "It's saved. You can come back to it."
                             : "Talk through anything still on your mind. Lull saves it so you don't have to hold onto it.")
                            .font(.system(size: 14))
                            .foregroundColor(.lullInk2)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                            .frame(maxWidth: 280)
                            .animation(.easeInOut, value: showDoneMessage)
                    }
                    .padding(.horizontal, 28)
                    .multilineTextAlignment(.center)

                    Spacer()

                    // Mic visualiser
                    ZStack {
                        ForEach(Array(0..<3), id: \.self) { r in
                            let base: CGFloat = 130 + CGFloat(r) * 28
                            let scale: CGFloat = recorder.recordingState == .recording ? 1 + 0.06 * CGFloat(r + 1) * sin(pulsePhase + CGFloat(r) * 0.9) : 1
                            Circle()
                                .stroke(Color.lullAmber.opacity(0.25 - Double(r) * 0.06), lineWidth: 1)
                                .frame(width: base * scale, height: base * scale)
                                .animation(.easeInOut(duration: 0.6), value: scale)
                        }

                        RadialGradient(colors: [Color.lullAmber.opacity(0.18), .clear],
                                       center: .center, startRadius: 0, endRadius: 100)
                            .clipShape(Circle())
                            .frame(width: 200, height: 200)

                        ZStack {
                            Circle()
                                .fill(showDoneMessage
                                      ? AnyShapeStyle(Color.lullAmberDeep.opacity(0.6))
                                      : AnyShapeStyle(RadialGradient(colors: [.lullAmber, .lullAmberDeep],
                                                                     center: .center, startRadius: 0, endRadius: 44)))
                                .frame(width: 88, height: 88)
                                .shadow(color: .lullAmberGlow, radius: showDoneMessage ? 8 : 20)
                                .overlay(Circle().strokeBorder(Color.lullBg.opacity(0.5), lineWidth: 6))
                                .animation(.easeInOut(duration: 0.4), value: showDoneMessage)

                            Image(systemName: showDoneMessage ? "checkmark" : (recorder.recordingState == .recording ? "stop.fill" : "mic.fill"))
                                .font(.system(size: 28, weight: .regular))
                                .foregroundColor(.lullBgDeep)
                                .animation(.easeInOut(duration: 0.2), value: showDoneMessage)
                        }
                        .onTapGesture {
                            guard !showDoneMessage else { return }
                            if recorder.recordingState == .recording {
                                handleDone()
                            } else {
                                recorder.start()
                            }
                        }
                    }
                    .frame(width: 200, height: 200)

                    VStack(spacing: 6) {
                        Text(recorder.duration.lullTimeString)
                            .font(.serif(38))
                            .foregroundColor(.lullInk0)
                            .kerning(-1)
                        Text(showDoneMessage ? "DONE" : (recorder.recordingState == .recording ? "LISTENING" : "TAP TO START"))
                            .font(.mono(11))
                            .kerning(1)
                            .foregroundColor(.lullInk3)
                            .animation(.easeInOut, value: showDoneMessage)
                    }
                    .padding(.top, 26)

                    Spacer()

                    HStack(spacing: 10) {
                        if !showDoneMessage {
                            Button(action: {
                                if recorder.recordingState == .recording { recorder.pause() } else { recorder.resume() }
                            }) {
                                Text(recorder.recordingState == .recording ? "Pause" : "Resume")
                                    .font(.system(size: 14))
                                    .foregroundColor(.lullInk2)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                                    .background(Capsule().strokeBorder(Color.lullLine, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }

                        Button(action: handleDone) {
                            Text(showDoneMessage ? "Continue →" : "I'm done")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.lullBgDeep)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(Capsule().fill(Color.lullAmber))
                                .shadow(color: .lullAmberGlow, radius: 12)
                        }
                        .buttonStyle(.plain)
                        .layoutPriority(2)
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 36)
                    .animation(.easeInOut, value: showDoneMessage)
                }
            }
        }
        .task { await recorder.checkPermission() }
        .onAppear {
            pulseTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                pulsePhase += 0.08
            }
        }
        .onDisappear {
            pulseTimer?.invalidate()
            pulseTimer = nil
        }
    }

    private func handleDone() {
        if showDoneMessage {
            state.nightlyStep += 1
        } else {
            let finalDuration = Int(recorder.duration)
            recorder.stopAndDiscard()
            state.updateTodayLog { $0.brainDumpDurationSec = finalDuration }
            state.recordCurrentStepAttempt(status: .completed, durationSeconds: finalDuration)
            withAnimation { showDoneMessage = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                state.nightlyStep += 1
            }
        }
    }
}

// Shown when mic permission is denied
private struct MicPermissionDeniedView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "mic.slash")
                .font(.system(size: 40))
                .foregroundColor(.lullInk3)
                .padding(.top, 60)

            Text("Microphone access needed")
                .font(.serif(22))
                .foregroundColor(.lullInk0)
                .multilineTextAlignment(.center)

            Text("Go to Settings → Lull → Microphone to enable it.")
                .font(.system(size: 14))
                .foregroundColor(.lullInk2)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .frame(maxWidth: 260)

            Button(action: {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }) {
                Text("Open Settings")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color(hex: "#1a0d06"))
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(Color.lullAmber))
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .padding(.horizontal, 28)
    }
}

// MARK: - Step 4: Boring Story

struct NightlyBoringStoryView: View {
    @EnvironmentObject var state: AppState
    @StateObject private var tts = TTSService()
    @State private var glowPulse = false
    @State private var elapsedSeconds = 0
    @State private var clockTimer: Timer?
    @State private var story = ""
    @State private var hasFinished = false
    @State private var isActive = false

    var body: some View {
        LullScreen(glow: false) {
            RadialGradient(
                colors: [Color.lullAmber.opacity(0.10), .clear],
                center: UnitPoint(x: 0.5, y: 0.38),
                startRadius: 0, endRadius: 210)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 16)
                NightlyStepHeader(
                    step: state.nightlyStep + 1,
                    total: state.nightlyStepTotal,
                    label: "Boring Story",
                    time: state.scheduledTime(for: R.boringStory)
                )

                VStack(spacing: 14) {
                    Kicker(text: "Eyes closed · audio only")
                    (Text("A slow drift through ")
                        .foregroundColor(.lullInk0)
                    + Text("somewhere ordinary.")
                        .foregroundColor(.lullAmber))
                    .font(.serif(22))
                    .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 28)
                .multilineTextAlignment(.center)

                Spacer()

                Circle()
                    .fill(Color.lullAmber)
                    .frame(width: 16, height: 16)
                    .shadow(color: .lullAmber,     radius: glowPulse ? 30 : 12)
                    .shadow(color: .lullAmberGlow,  radius: glowPulse ? 60 : 24)
                    .scaleEffect(glowPulse ? 1.3 : 1.0)
                    .animation(Animation.easeInOut(duration: 3.5).repeatForever(autoreverses: true), value: glowPulse)
                    .onAppear { glowPulse = true }

                Spacer()

                VStack(spacing: 12) {
                    Text("\(elapsedSeconds.lullTimeString) / ~20:00")
                        .font(.mono(11))
                        .kerning(1.6)
                        .foregroundColor(.lullInk3)

                    GeometryReader { geo in
                        let pct = min(1, CGFloat(elapsedSeconds) / 1200)
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.08))
                            Capsule().fill(Color.lullAmber.opacity(0.7))
                                .frame(width: geo.size.width * pct)
                        }
                    }
                    .frame(height: 2)
                    .animation(.linear(duration: 1), value: elapsedSeconds)
                }
                .padding(.horizontal, 28)

                Spacer()

                HStack(spacing: 22) {
                    controlButton(icon: tts.isPaused ? "play.fill" : "pause.fill", size: 18) {
                        tts.togglePause()
                    }
                    controlButton(icon: "xmark", size: 14) {
                        finish()
                    }
                }
                .padding(.bottom, 16)

                GhostButton(title: "Skip") { finish() }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 22)
                    .padding(.bottom, 36)
            }
        }
        .onAppear {
            isActive = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                guard isActive, !hasFinished else { return }
                startStory()
            }
        }
        .onDisappear {
            isActive = false
            cleanupStory()
        }
    }

    private func controlButton(icon: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .strokeBorder(Color.lullLine, lineWidth: 1)
                    .background(Circle().fill(Color.white.opacity(0.02)))
                    .frame(width: 56, height: 56)
                Image(systemName: icon)
                    .font(.system(size: size))
                    .foregroundColor(.lullInk2)
            }
        }
        .buttonStyle(.plain)
    }

    private func startStory() {
        guard !hasFinished else { return }
        var indices = Array(0..<BundledStories.all.count).shuffled()
        story = (0..<4).map { _ in BundledStories.all[indices.removeFirst()] }.joined(separator: "\n\n")
        tts.append(story)
        tts.flushRemaining()
        clockTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in elapsedSeconds += 1 }
        }
    }

    private func cleanupStory() {
        tts.stop()
        clockTimer?.invalidate()
        clockTimer = nil
    }

    private func finish() {
        guard !hasFinished else { return }
        hasFinished = true
        cleanupStory()
        state.recordCurrentStepAttempt(status: .completed, durationSeconds: elapsedSeconds)
        state.nightlyStep += 1
    }
}

// MARK: - Alt: 4-7-8 Breathing

struct NightlyBreathingView: View {
    @EnvironmentObject var state: AppState
    @State private var orbScale: CGFloat = 1.0
    @State private var timer: Timer? = nil

    var body: some View {
        LullScreen(glow: false) {
            AmberGlow(x: 0.5, y: 0.4, radius: 260, opacity: 0.5)
                .ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer().frame(height: 16)
                NightlyStepHeader(step: state.nightlyStep + 1, total: state.nightlyStepTotal, label: "4 · 7 · 8 Breathing")

                VStack(spacing: 16) {
                    Kicker(text: "Cycle \(state.breathingCycle) of 4")
                    Text(state.breathingPhase.label)
                        .font(.serifItalic(32))
                        .foregroundColor(.lullAmber)
                }
                .padding(.horizontal, 28)
                .multilineTextAlignment(.center)
                .padding(.bottom, 36)

                Spacer()

                ZStack {
                    Circle()
                        .fill(RadialGradient(colors: [Color.lullAmber.opacity(0.15), .clear],
                                             center: .center, startRadius: 0, endRadius: 140))
                        .frame(width: 280, height: 280)

                    ZStack {
                        Circle()
                            .fill(RadialGradient(
                                stops: [
                                    .init(color: Color.lullAmber.opacity(0.7), location: 0),
                                    .init(color: .lullAmberDeep, location: 0.6),
                                    .init(color: Color(hex: "#50280f").opacity(0.6), location: 1),
                                ],
                                center: UnitPoint(x: 0.5, y: 0.35),
                                startRadius: 0, endRadius: 110))
                            .frame(width: 220, height: 220)
                            .shadow(color: .lullAmberGlow, radius: 40)
                            .scaleEffect(orbScale)
                            .animation(Animation.easeInOut(duration: Double(state.breathingPhase.seconds)).repeatForever(autoreverses: true), value: orbScale)
                            .onAppear { orbScale = 1.08 }

                        Text("\(state.breathingSecondsRemaining)")
                            .font(.serif(80))
                            .foregroundColor(.lullInk0)
                            .kerning(-3)
                            .shadow(color: Color.black.opacity(0.3), radius: 4, y: 2)

                        Text("SECONDS")
                            .font(.mono(11))
                            .kerning(1.8)
                            .foregroundColor(.lullBgDeep.opacity(0.7))
                            .offset(y: 48)
                    }
                }

                Spacer()

                HStack(spacing: 10) {
                    ForEach([BreathingPhase.inhale, .hold, .exhale], id: \.label) { phase in
                        let active = state.breathingPhase == phase
                        HStack(spacing: 8) {
                            Text(phase.label)
                                .font(.system(size: 13))
                                .foregroundColor(active ? .lullInk0 : .lullInk2)
                            Text("\(phase.seconds)s")
                                .font(.mono(10))
                                .foregroundColor(active ? .lullAmberSoft : .lullInk4)
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(active ? Color.lullAmber.opacity(0.10) : Color.clear))
                        .overlay(Capsule().strokeBorder(active ? Color.lullAmber.opacity(0.5) : Color.lullLine, lineWidth: 1))
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 40)

                GhostButton(title: "End early · I'm calm") {
                    state.recordCurrentStepAttempt(status: .completed)
                    state.nightlyStep += 1
                }
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .padding(.top, 50)
                .padding(.bottom, 36)
            }
        }
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 2) { startTimer() } }
        .onDisappear { timer?.invalidate() }
    }

    private func startTimer() {
        state.breathingPhase = .inhale
        state.breathingSecondsRemaining = BreathingPhase.inhale.seconds
        state.breathingCycle = 1

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in tick() }
        }
    }

    private func tick() {
        if state.breathingSecondsRemaining > 1 {
            state.breathingSecondsRemaining -= 1
            return
        }
        switch state.breathingPhase {
        case .inhale:
            state.breathingPhase = .hold
            state.breathingSecondsRemaining = BreathingPhase.hold.seconds
        case .hold:
            state.breathingPhase = .exhale
            state.breathingSecondsRemaining = BreathingPhase.exhale.seconds
        case .exhale:
            if state.breathingCycle >= 4 {
                timer?.invalidate()
                state.recordCurrentStepAttempt(status: .completed)
                state.nightlyStep += 1
            } else {
                state.breathingCycle += 1
                state.breathingPhase = .inhale
                state.breathingSecondsRemaining = BreathingPhase.inhale.seconds
            }
        }
    }
}

// MARK: - Generic Step (existing habits from generated routine)

struct NightlyGenericStepView: View {
    @EnvironmentObject var state: AppState
    var label: String

    var body: some View {
        LullScreen(glow: false) {
            AmberGlow(x: 0.5, y: 0.3, radius: 220, opacity: 0.4)
                .ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer().frame(height: 16)
                NightlyStepHeader(step: state.nightlyStep + 1, total: state.nightlyStepTotal, label: label)

                VStack(spacing: 14) {
                    Kicker(text: "Your habit")
                    Text(label)
                        .font(.serif(32))
                        .foregroundColor(.lullAmber)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 28)
                .padding(.top, 36)

                Spacer()

                ZStack {
                    Circle().stroke(Color.lullLine, lineWidth: 1).frame(width: 160, height: 160)
                    Ember(size: 8)
                }

                Spacer()

                VStack(spacing: 0) {
                    PrimaryCTA(title: "Done") {
                        state.recordCurrentStepAttempt(status: .completed)
                        state.nightlyStep += 1
                    }
                    GhostButton(title: "Skip") {
                        state.recordCurrentStepAttempt(status: .skipped)
                        state.nightlyStep += 1
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 36)
            }
        }
    }
}
