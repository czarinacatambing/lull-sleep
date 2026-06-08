import SwiftUI
import UIKit
import AVFoundation

// Nightly walkthrough coordinator — forward-only, no back button.
struct NightlyFlowView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) var dismiss
    @State private var didRecordSessionStart = false
    @State private var recordedStartedStepIndexes: Set<Int> = []

    var body: some View {
        ZStack {
            let steps = state.nightlyFlowSteps
            if state.nightlyStep < steps.count {
                switch steps[state.nightlyStep] {
                case .brightnessCheck:               NightlyBrightnessView()
                case .temperatureLog:                NightlyTemperatureView()
                case .brainDump:                     NightlyBrainDumpView()
                case .boringStory:                   NightlyBoringStoryView()
                case .sleepSounds:                   NightlySleepSoundsView()
                case .fourSevenEightBreathing:       NightlyBreathingView()
                case .gratitudeJournal:              NightlyGratitudeJournalView()
                case .gentleStretching:              NightlyGentleStretchingView()
                case .progressiveMuscleRelaxation:   NightlyProgressiveMuscleRelaxationView()
                case .bodyScan:                      NightlyBodyScanView()
                case .existingHabit(let label):      NightlyGenericStepView(label: label)
                case .avoidReminder:                 EmptyView()
                }
            } else {
                NightlyGoodNightView {
                    state.nightlyStep = 0
                    dismiss()
                }
            }
        }
        .animation(.easeInOut(duration: 0.45), value: state.nightlyStep)
        .onAppear {
            guard !didRecordSessionStart else { return }
            didRecordSessionStart = true
            state.recordNightlySessionStarted()
            recordCurrentStepStartedIfNeeded()
        }
        .onChange(of: state.nightlyStep) { _, _ in
            recordCurrentStepStartedIfNeeded()
        }
    }

    private func recordCurrentStepStartedIfNeeded() {
        guard state.nightlyStep < state.nightlyFlowSteps.count else { return }
        guard !recordedStartedStepIndexes.contains(state.nightlyStep) else { return }
        recordedStartedStepIndexes.insert(state.nightlyStep)
        state.recordCurrentStepStarted()
    }
}

// MARK: - Step 1: Brightness Check

struct NightlyBrightnessView: View {
    @EnvironmentObject var state: AppState
    @StateObject private var lightService = AmbientLightService()
    @State private var selectedLevel: Int? = nil
    @State private var autoDetectedLevel: Int? = nil
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
                                detectedSource = (lightService.confidence == .high && autoDetectedLevel == i)
                                    ? .sensor
                                    : .selfReported
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
            if result.confidence == .high {
                selectedLevel = result.lightsLevel
                autoDetectedLevel = result.lightsLevel
                detectedSource = .sensor
            } else {
                selectedLevel = nil
                autoDetectedLevel = nil
                detectedSource = .selfReported
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
            let savedURL = recorder.stopAndSave(date: Date())
            let relativePath: String? = savedURL.map { url in
                let docsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].path
                return String(url.path.dropFirst(docsPath.count + 1))
            }
            state.updateTodayLog {
                $0.brainDumpDurationSec = finalDuration
                $0.brainDumpFilePath = relativePath
            }
            state.recordCurrentStepAttempt(status: .completed, durationSeconds: finalDuration)
            state.recordBrainDumpSession(durationSeconds: finalDuration, hasRecording: relativePath != nil)
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
    @StateObject private var playback = AudioPlaybackService()
    @State private var glowPulse = false
    @State private var hasFinished = false
    @State private var isActive = false
    @State private var activeStoryId: String?

    private var elapsedSeconds: Int { Int(playback.elapsed.rounded(.down)) }
    private var durationSeconds: Int {
        playback.duration > 0 ? Int(playback.duration.rounded(.up)) : 1200
    }

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
                    Text("\(elapsedSeconds.lullTimeString) / \(durationSeconds.lullTimeString)")
                        .font(.mono(11))
                        .kerning(1.6)
                        .foregroundColor(.lullInk3)

                    GeometryReader { geo in
                        let pct = min(1, CGFloat(elapsedSeconds) / CGFloat(max(1, durationSeconds)))
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

                HStack(spacing: 12) {
                    controlButton(icon: playback.isPlaying ? "pause.fill" : "play.fill", size: 18) {
                        if playback.isPlaying { playback.pause() }
                        else { playback.play() }
                    }

                    Spacer().frame(width: 18)

                    HStack(spacing: 8) {
                        controlButton(icon: "minus", size: 18, disabled: !playback.canSlowDown) {
                            playback.speedDown()
                        }
                        Text(rateText(playback.playbackRate))
                            .font(.mono(11))
                            .kerning(1.2)
                            .foregroundColor(.lullInk3)
                            .frame(width: 38)
                        controlButton(icon: "plus", size: 18, disabled: !playback.canSpeedUp) {
                            playback.speedUp()
                        }
                    }

                    Spacer().frame(width: 6)

                    controlButton(icon: "xmark", size: 14) {
                        finish(status: .skipped)
                    }
                }
                .padding(.bottom, 16)

                GhostButton(title: "Skip") { finish(status: .skipped) }
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

    private func rateText(_ rate: Float) -> String {
        switch rate {
        case 0.75: return ".75x"
        case 0.9: return ".9x"
        case 1.0: return "1x"
        case 1.5: return "1.5x"
        default: return "\(rate)x"
        }
    }

    private func controlButton(icon: String, size: CGFloat, disabled: Bool = false, action: @escaping () -> Void) -> some View {
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
        .disabled(disabled)
        .opacity(disabled ? 0.35 : 1)
    }

    private func startStory() {
        guard !hasFinished else { return }
        guard let url = BoringStoryAudioLibrary.nextStoryURL() else { return }
        activeStoryId = url.deletingPathExtension().lastPathComponent
        playback.load(url: url)
        playback.onFinish = { finish(status: .completed) }
        playback.play()
    }

    private func cleanupStory() {
        playback.onFinish = nil
        playback.stop()
    }

    private func finish(status: StepStatus) {
        guard !hasFinished else { return }
        hasFinished = true
        let listenedSeconds = elapsedSeconds
        let totalSeconds = durationSeconds
        cleanupStory()
        state.recordBoringStorySession(
            contentId: activeStoryId,
            listenedSeconds: listenedSeconds,
            totalDurationSeconds: totalSeconds,
            status: status
        )
        state.nightlyStep += 1
    }
}

// MARK: - Alt: 4-7-8 Breathing

private enum AudioBreathPhase: Equatable {
    case intro, inhale, hold, exhale, rest, windDown

    var label: String {
        switch self {
        case .intro:               return "Listen and breathe"
        case .inhale:              return "Breathe in"
        case .hold:                return "Hold"
        case .exhale:              return "Breathe out"
        case .rest:                return "Rest"
        case .windDown:            return "Let go"
        }
    }

    var orbTarget: CGFloat {
        switch self {
        case .inhale:              return 1.18
        case .hold:                return 1.18
        case .exhale:              return 0.82
        case .intro, .rest, .windDown: return 1.0
        }
    }
}

private struct BreathCue {
    let time: Double
    let phase: AudioBreathPhase
    let cycle: Int  // 0 = between cycles

    // Derived from Whisper word-level transcription of 478-breathing-revised.mp3
    static let all: [BreathCue] = [
        // Cycle 1 — intro breath, voice counts 1–8 across inhale + hold
        .init(time:  92.2, phase: .inhale,   cycle: 1),
        .init(time:  97.0, phase: .hold,     cycle: 1),
        .init(time: 104.2, phase: .exhale,   cycle: 1),
        .init(time: 108.5, phase: .rest,     cycle: 0),
        // Cycle 2
        .init(time: 112.8, phase: .inhale,   cycle: 2),
        .init(time: 117.6, phase: .hold,     cycle: 2),
        .init(time: 128.6, phase: .exhale,   cycle: 2),
        .init(time: 143.9, phase: .rest,     cycle: 0),
        // Cycle 3
        .init(time: 157.1, phase: .inhale,   cycle: 3),
        .init(time: 160.9, phase: .hold,     cycle: 3),
        .init(time: 172.4, phase: .exhale,   cycle: 3),
        .init(time: 186.2, phase: .rest,     cycle: 0),
        // Cycle 4
        .init(time: 208.2, phase: .inhale,   cycle: 4),
        .init(time: 214.1, phase: .hold,     cycle: 4),
        .init(time: 225.9, phase: .exhale,   cycle: 4),
        .init(time: 239.2, phase: .rest,     cycle: 0),
        // Cycle 5
        .init(time: 257.9, phase: .inhale,   cycle: 5),
        .init(time: 261.9, phase: .hold,     cycle: 5),
        .init(time: 271.1, phase: .exhale,   cycle: 5),
        .init(time: 282.0, phase: .rest,     cycle: 0),
        // Cycle 6
        .init(time: 285.5, phase: .inhale,   cycle: 6),
        .init(time: 289.7, phase: .hold,     cycle: 6),
        .init(time: 300.5, phase: .exhale,   cycle: 6),
        .init(time: 315.6, phase: .windDown, cycle: 0),
    ]

    // Derived from Whisper word-level transcription of 4-7-3-breathing-v2.m4a (366s).
    // Despite the filename, the narration is a 4-7-8 exercise over 6 cycles.
    static let session: [BreathCue] = [
        .init(time:   0.0, phase: .intro,    cycle: 0),
        // Cycle 1 (unnumbered intro breath)
        .init(time:  92.5, phase: .inhale,   cycle: 1),
        .init(time:  96.8, phase: .hold,     cycle: 1),
        .init(time: 107.2, phase: .exhale,   cycle: 1),
        .init(time: 122.6, phase: .rest,     cycle: 0),
        // Cycle 2
        .init(time: 128.7, phase: .inhale,   cycle: 2),
        .init(time: 135.1, phase: .hold,     cycle: 2),
        .init(time: 144.3, phase: .exhale,   cycle: 2),
        .init(time: 155.3, phase: .rest,     cycle: 0),
        // Cycle 3
        .init(time: 166.3, phase: .inhale,   cycle: 3),
        .init(time: 172.9, phase: .hold,     cycle: 3),
        .init(time: 183.0, phase: .exhale,   cycle: 3),
        .init(time: 197.1, phase: .rest,     cycle: 0),
        // Cycle 4
        .init(time: 217.4, phase: .inhale,   cycle: 4),
        .init(time: 223.5, phase: .hold,     cycle: 4),
        .init(time: 232.5, phase: .exhale,   cycle: 4),
        .init(time: 243.6, phase: .rest,     cycle: 0),
        // Cycle 5
        .init(time: 259.1, phase: .inhale,   cycle: 5),
        .init(time: 264.9, phase: .hold,     cycle: 5),
        .init(time: 274.2, phase: .exhale,   cycle: 5),
        .init(time: 285.2, phase: .rest,     cycle: 0),
        // Cycle 6 ("one more cycle")
        .init(time: 286.6, phase: .inhale,   cycle: 6),
        .init(time: 292.8, phase: .hold,     cycle: 6),
        .init(time: 303.2, phase: .exhale,   cycle: 6),
        .init(time: 318.7, phase: .windDown, cycle: 0),
    ]
}

// Top-of-screen breathing progress: one segment per cycle, each filling 0…1.
private struct SegmentedCycleBar: View {
    let fills: [Double]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(fills.indices, id: \.self) { i in
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.08))
                        Capsule()
                            .fill(Color.lullAmber.opacity(0.7))
                            .frame(width: geo.size.width * min(1, max(0, fills[i])))
                    }
                }
                .frame(height: 3)
            }
        }
        .animation(.linear(duration: 0.1), value: fills)
    }
}

struct NightlyBreathingView: View {
    var isMidSleep: Bool = false
    var onboardingCopy: String? = nil
    var onOnboardingNext: (() -> Void)? = nil
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) var dismiss
    @State private var player: AVAudioPlayer?
    @State private var pollTimer: Timer?
    @State private var currentPhase: AudioBreathPhase = .intro
    @State private var currentCycle = 0
    @State private var orbScale: CGFloat = 1.0
    @State private var secondsRemaining = 0
    @State private var elapsed: Double = 0
    @State private var totalDuration: Double = 360
    @State private var audioFinished = false
    @State private var viewActive = false
    @State private var audioStarted = false
    @State private var isAudioPlaying = false
    @State private var isFallbackSession = false
    @State private var playbackRate: Float = 1.0
    @State private var showOnboardingLine1 = false
    @State private var showOnboardingLine2 = false

    private var isOnboarding: Bool { onOnboardingNext != nil }
    private let playbackRates: [Float] = [0.75, 0.9, 1.0, 1.5]
    private var currentRateIndex: Int {
        playbackRates.enumerated().min(by: {
            abs($0.element - playbackRate) < abs($1.element - playbackRate)
        })?.offset ?? 2
    }
    private var canSlowDown: Bool { currentRateIndex > playbackRates.startIndex }
    private var canSpeedUp: Bool { currentRateIndex < playbackRates.index(before: playbackRates.endIndex) }

    private var progress: Double { min(1, elapsed / totalDuration) }
    private var timeRemainingString: String {
        let secs = max(0, Int(totalDuration - elapsed))
        let m = secs / 60; let s = secs % 60
        return m > 0 ? "\(m):\(String(format: "%02d", s))" : "0:\(String(format: "%02d", s))"
    }

    // Cue track for the current context (onboarding vs nightly/mid-sleep session).
    private var activeCues: [BreathCue] { isOnboarding ? BreathCue.all : BreathCue.session }
    private var totalCycles: Int { activeCues.map(\.cycle).max() ?? 0 }

    // Per-cycle fill (0…1) for the segmented top bar. A cycle spans from its
    // inhale cue to the next cycle's inhale (or the wind-down for the last cycle).
    private var cycleFills: [Double] {
        guard totalCycles > 0 else { return [] }
        let starts = (1...totalCycles).map { c in
            activeCues.first(where: { $0.cycle == c && $0.phase == .inhale })?.time ?? 0
        }
        let windDownTime = activeCues.first(where: { $0.phase == .windDown })?.time ?? totalDuration
        return (0..<totalCycles).map { i in
            let start = starts[i]
            let end = i + 1 < totalCycles ? starts[i + 1] : windDownTime
            guard end > start else { return elapsed >= end ? 1 : 0 }
            return min(1, max(0, (elapsed - start) / (end - start)))
        }
    }

    var body: some View {
        LullScreen(glow: false) {
            AmberGlow(x: 0.5, y: 0.4, radius: 260, opacity: 0.5)
                .ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer().frame(height: 16)
                if isMidSleep || isOnboarding {
                    HStack {
                        if isMidSleep {
                            Text("4 · 7 · 8 BREATHING")
                                .font(.mono(10.5))
                                .kerning(1.2)
                                .foregroundColor(.lullInk3)
                            Spacer()
                            MidSleepExitButton {
                                complete()
                            }
                        } else {
                            BrandMark()
                            Spacer()
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, isMidSleep ? 14 : 18)
                } else {
                    NightlyStepHeader(step: state.nightlyStep + 1, total: state.nightlyStepTotal, label: "4 · 7 · 8 Breathing")
                }

                if !isOnboarding {
                    SegmentedCycleBar(fills: cycleFills)
                        .padding(.horizontal, 28)
                        .padding(.top, isMidSleep ? 0 : 14)
                        .padding(.bottom, isMidSleep ? 16 : 4)
                }

                VStack(spacing: 16) {
                    if isOnboarding {
                        VStack(spacing: 10) {
                            Text("Let's try the first tool from your routine right now.")
                                .opacity(showOnboardingLine1 ? 1 : 0)
                                .offset(y: showOnboardingLine1 ? 0 : 10)
                            Text("60 seconds to help your brain start downshifting.")
                                .opacity(showOnboardingLine2 ? 1 : 0)
                                .offset(y: showOnboardingLine2 ? 0 : 10)
                        }
                        .font(.system(size: 16))
                        .foregroundColor(.lullInk1)
                        .lineSpacing(5)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 300)
                    } else {
                        Kicker(text: currentPhase == .windDown ? "Winding down" : "Follow along")
                        Text(currentPhase.label)
                            .font(.serifItalic(32))
                            .foregroundColor(.lullAmber)
                            .animation(.easeInOut(duration: 0.4), value: currentPhase.label)
                    }
                }
                .padding(.horizontal, 28)
                .multilineTextAlignment(.center)
                .padding(.bottom, isOnboarding ? 24 : 36)

                Spacer()

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

                Spacer()

                if !isOnboarding || audioStarted {
                    VStack(spacing: 8) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.08))
                            Capsule()
                                .fill(Color.lullAmber.opacity(0.6))
                                .frame(width: geo.size.width * progress)
                        }
                    }
                    .frame(height: 2)
                    .animation(.linear(duration: 0.1), value: progress)

                    Text(timeRemainingString)
                        .font(.mono(11))
                        .kerning(1.4)
                        .foregroundColor(.lullInk4)
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 8)
                }

                if isOnboarding {
                    VStack(spacing: 0) {
                        PrimaryCTA(title: "Next", disabled: !audioFinished) {
                            onOnboardingNext?()
                        }
                        GhostButton(title: "Skip") {
                            stopSession()
                            onOnboardingNext?()
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 36)
                } else {
                    VStack(spacing: 16) {
                        HStack(spacing: 12) {
                            controlButton(icon: isAudioPlaying ? "pause.fill" : "play.fill", size: 18) {
                                if isAudioPlaying { pauseBreathing() }
                                else { playBreathing() }
                            }

                            Spacer().frame(width: 18)

                            HStack(spacing: 8) {
                                controlButton(icon: "minus", size: 18, disabled: !canSlowDown) {
                                    stepPlaybackRate(-1)
                                }
                                Text(rateText(playbackRate))
                                    .font(.mono(11))
                                    .kerning(1.2)
                                    .foregroundColor(.lullInk3)
                                    .frame(width: 38)
                                controlButton(icon: "plus", size: 18, disabled: !canSpeedUp) {
                                    stepPlaybackRate(1)
                                }
                            }
                        }

                        GhostButton(title: "End early · I'm calm") {
                            complete()
                        }
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 24)
                    .padding(.bottom, 36)
                }
            }
        }
        .onAppear {
            viewActive = true
            if isOnboarding {
                startOnboardingIntro()
            } else {
                startSession()
            }
        }
        .onDisappear { stopSession() }
    }

    private func complete() {
        stopSession()
        if isOnboarding {
            audioFinished = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            return
        }
        if isMidSleep {
            dismiss()
        } else {
            state.recordCurrentStepAttempt(status: .completed)
            state.nightlyStep += 1
        }
    }

    private func rateText(_ rate: Float) -> String {
        switch rate {
        case 0.75: return ".75x"
        case 0.9: return ".9x"
        case 1.0: return "1x"
        case 1.5: return "1.5x"
        default: return "\(rate)x"
        }
    }

    private func controlButton(icon: String, size: CGFloat, disabled: Bool = false, action: @escaping () -> Void) -> some View {
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
        .disabled(disabled)
        .opacity(disabled ? 0.35 : 1)
    }

    private func startSession() {
        audioFinished = false
        audioStarted = true
        isFallbackSession = false
        playbackRate = 1.0
        let usesShortOnboardingAudio = isOnboarding
        let audioName = usesShortOnboardingAudio ? "478-breathing-revised" : "4-7-3-breathing-v2"
        let audioExtension = usesShortOnboardingAudio ? "mp3" : "m4a"
        guard let url = Bundle.main.url(forResource: audioName, withExtension: audioExtension) else {
            startFallbackTimer(); return
        }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            player = try AVAudioPlayer(contentsOf: url)
            player?.enableRate = true
            player?.rate = playbackRate
            totalDuration = player?.duration ?? 360
            player?.play()
            isAudioPlaying = true
        } catch {
            startFallbackTimer(); return
        }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            Task { @MainActor in poll() }
        }
    }

    private func stopSession() {
        viewActive = false
        audioStarted = false
        isAudioPlaying = false
        isFallbackSession = false
        pollTimer?.invalidate(); pollTimer = nil
        player?.stop(); player = nil
    }

    private func pauseBreathing() {
        if isFallbackSession {
            pollTimer?.invalidate()
            pollTimer = nil
        } else {
            player?.pause()
        }
        isAudioPlaying = false
    }

    private func playBreathing() {
        if isFallbackSession {
            scheduleFallbackTimer()
        } else {
            player?.enableRate = true
            player?.rate = playbackRate
            player?.play()
        }
        isAudioPlaying = true
    }

    private func stepPlaybackRate(_ direction: Int) {
        let nextIndex = min(max(currentRateIndex + direction, playbackRates.startIndex), playbackRates.index(before: playbackRates.endIndex))
        playbackRate = playbackRates[nextIndex]
        player?.enableRate = true
        player?.rate = playbackRate
        if isFallbackSession, isAudioPlaying {
            scheduleFallbackTimer()
        }
    }

    private func animationDuration(for mediaDuration: Double) -> Double {
        max(0.1, mediaDuration / Double(playbackRate))
    }

    private func startOnboardingIntro() {
        audioFinished = false
        showOnboardingLine1 = false
        showOnboardingLine2 = false
        elapsed = 0
        currentPhase = .intro
        currentCycle = 0
        orbScale = 1.0

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            guard viewActive else { return }
            withAnimation(.easeOut(duration: 0.9)) {
                showOnboardingLine1 = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.45) {
            guard viewActive else { return }
            withAnimation(.easeOut(duration: 0.9)) {
                showOnboardingLine2 = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 5.35) {
            guard viewActive else { return }
            startSession()
        }
    }

    @MainActor
    private func poll() {
        guard let player else { return }
        let t = player.currentTime
        elapsed = t

        let cues = activeCues
        let activeCue = cues.last(where: { $0.time <= t })
        let nextCue   = cues.first(where: { $0.time > t })

        let newPhase = activeCue?.phase ?? .intro
        let newCycle = activeCue?.cycle ?? 0

        if newPhase == .inhale || newPhase == .hold || newPhase == .exhale, let next = nextCue {
            secondsRemaining = max(1, Int(ceil(next.time - t)))
        } else {
            secondsRemaining = 0
        }

        if newPhase != currentPhase {
            let phaseDuration = nextCue.map { $0.time - t } ?? 4.0
            currentPhase = newPhase
            if newCycle > 0 { currentCycle = newCycle }  // hold cycle # through rests / wind-down
            withAnimation(.easeInOut(duration: animationDuration(for: phaseDuration))) {
                orbScale = newPhase.orbTarget
            }
        } else if newCycle > 0 && currentCycle != newCycle {
            currentCycle = newCycle
        }

        if !player.isPlaying && t >= max(0, totalDuration - 0.5) {
            complete()
        }
    }

    // Fallback: original 4-cycle timer-based version if audio file is missing
    private func startFallbackTimer() {
        audioStarted = true
        isAudioPlaying = true
        isFallbackSession = true
        let cycleSecs = Double(BreathingPhase.inhale.seconds + BreathingPhase.hold.seconds + BreathingPhase.exhale.seconds)
        totalDuration = cycleSecs * 4
        state.breathingPhase = .inhale
        state.breathingSecondsRemaining = BreathingPhase.inhale.seconds
        state.breathingCycle = 1
        currentPhase = .inhale; currentCycle = 1
        secondsRemaining = BreathingPhase.inhale.seconds

        scheduleFallbackTimer()
    }

    private func scheduleFallbackTimer() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1 / Double(playbackRate), repeats: true) { _ in
            Task { @MainActor in tickFallback() }
        }
    }

    @MainActor
    private func tickFallback() {
        elapsed += 1
        if state.breathingSecondsRemaining > 1 {
            state.breathingSecondsRemaining -= 1
            secondsRemaining = state.breathingSecondsRemaining
            return
        }
        switch state.breathingPhase {
        case .inhale:
            state.breathingPhase = .hold
            state.breathingSecondsRemaining = BreathingPhase.hold.seconds
            currentPhase = .hold
            withAnimation(.easeInOut(duration: animationDuration(for: Double(BreathingPhase.hold.seconds)))) { orbScale = 1.18 }
        case .hold:
            state.breathingPhase = .exhale
            state.breathingSecondsRemaining = BreathingPhase.exhale.seconds
            currentPhase = .exhale
            withAnimation(.easeInOut(duration: animationDuration(for: Double(BreathingPhase.exhale.seconds)))) { orbScale = 0.82 }
        case .exhale:
            if state.breathingCycle >= 4 {
                pollTimer?.invalidate()
                complete(); return
            }
            state.breathingCycle += 1
            state.breathingPhase = .inhale
            state.breathingSecondsRemaining = BreathingPhase.inhale.seconds
            currentCycle = state.breathingCycle; currentPhase = .inhale
            withAnimation(.easeInOut(duration: animationDuration(for: Double(BreathingPhase.inhale.seconds)))) { orbScale = 1.18 }
        }
        secondsRemaining = state.breathingSecondsRemaining
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

// MARK: - Good Night Outro

struct NightlyGoodNightView: View {
    var onDismiss: () -> Void

    @EnvironmentObject var state: AppState
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    @State private var heroOpacity: Double = 0
    @State private var tipOpacity: Double = 0
    @State private var dimOpacity: Double = 0
    @State private var glowOpacity: Double = 0.55
    @State private var heroFade: Double = 1
    @State private var tipFade: Double = 1
    @State private var emberScale: CGFloat = 1.0
    @State private var canDismiss = false
    @State private var didStartSleepCompanion = false
    @State private var didRecordCompletion = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.lullBg, Color(hex: "#120b09")],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            RadialGradient(
                colors: [Color.lullAmber.opacity(glowOpacity), .clear],
                center: UnitPoint(x: 0.5, y: 0.48),
                startRadius: 0,
                endRadius: 280
            )
            .ignoresSafeArea()

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let heroY = min(280, max(210, h * 0.37))
                let emberY = min(470, max(heroY + 150, h * 0.66))
                let tipY = min(600, max(emberY + 104, h - 86))

                // Hero title
                VStack(alignment: .center, spacing: 0) {
                    Text("ROUTINE COMPLETE")
                        .font(.mono(10))
                        .kerning(10 * 0.18)
                        .foregroundColor(Color.lullAmber.opacity(0.75))

                    Text("Good night.")
                        .font(.serif(52))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .foregroundColor(Color.lullInk0)
                    .shadow(color: Color.lullAmber.opacity(0.4), radius: 16)
                    .padding(.top, 22)
                }
                .opacity(heroOpacity * heroFade)
                .frame(width: w - 64)
                .position(x: w / 2, y: heroY)

                // Breathing ember
                Circle()
                    .fill(Color.lullAmber)
                    .frame(width: 14, height: 14)
                    .shadow(color: Color.lullAmber.opacity(0.9), radius: 7)
                    .shadow(color: Color.lullAmber.opacity(0.5), radius: 24)
                    .scaleEffect(emberScale)
                    .position(x: w / 2, y: emberY)
                    .zIndex(10)

                // Mid-sleep tip
                VStack(spacing: 14) {
                    HStack(spacing: 6) {
                        Image(systemName: "moon.fill")
                            .font(.system(size: 9))
                            .foregroundColor(Color(hex: "#b9aedc"))
                        Text("IF YOU WAKE TONIGHT")
                            .font(.mono(9.5))
                            .kerning(9.5 * 0.14)
                            .foregroundColor(Color(hex: "#b9aedc"))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(hex: "#b4a0dc").opacity(0.08))
                    .overlay(Capsule().strokeBorder(Color(hex: "#b4a0dc").opacity(0.20), lineWidth: 1))
                    .clipShape(Capsule())

                    (Text("Swipe to the ")
                     + Text("Mid-sleep tab")
                        .italic()
                        .foregroundColor(Color.lullAmber)
                     + Text(" to fall back asleep."))
                        .font(.serif(16))
                        .foregroundColor(Color.lullInk1)
                        .multilineTextAlignment(.center)
                        .lineSpacing(8)
                        .frame(maxWidth: 290)
                }
                .opacity(tipOpacity * tipFade)
                .frame(width: w - 64)
                .position(x: w / 2, y: tipY)

                // Dim overlay — above content but below ember (zIndex 5 < 10)
                Color(red: 12/255, green: 8/255, blue: 7/255)
                    .opacity(dimOpacity * 0.86)
                    .ignoresSafeArea()
                    .zIndex(5)
                    .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            if !didRecordCompletion {
                didRecordCompletion = true
                state.updateTodayLog {
                    $0.completedNightlyFlow = true
                    $0.actualBedtime = Date()
                }
                state.markAllRitualDone()
                state.persist()
                state.recordNightlySessionCompleted()
            }
            startSleepCompanionIfNeeded()

            if reduceMotion {
                heroOpacity = 1
                tipOpacity = 1
            } else {
                runAnimation()
                withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                    emberScale = 1.18
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                canDismiss = true
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard canDismiss else { return }
            onDismiss()
        }
    }

    private func startSleepCompanionIfNeeded() {
        guard !didStartSleepCompanion else { return }
        didStartSleepCompanion = true

        // End the prep-checklist Live Activity, then start the sleep companion
        // as soon as the ritual reaches the final screen. The user may lock
        // the phone here instead of tapping to dismiss.
        LiveActivityService.shared.end(dismissalPolicy: .immediate)
        LiveActivityService.shared.startSleepActivity(
            bedtime: Date(),
            wakeTime: state.nextWakeTime()
        )
    }

    private func runAnimation() {
        withAnimation(.easeOut(duration: 3.0)) {
            heroOpacity = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            withAnimation(.easeOut(duration: 0.8)) {
                tipOpacity = 1
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.9) {
            withAnimation(.easeIn(duration: 3.1)) {
                dimOpacity = 1
                glowOpacity = 0.18
                heroFade = 0.04
                tipFade = 0.06
            }
        }
    }
}
