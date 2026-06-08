import SwiftUI
import AVFoundation

struct SleepLogDetailView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) var dismiss
    var entryIndex: Int

    @State private var draftScore: Int = 0
    @State private var draftNotes: String = ""
    @State private var noteMode: NoteMode = .none
    @State private var isRecording = false
    @State private var recorder: AVAudioRecorder?

    private enum NoteMode { case none, text, voice }

    private var entry: SleepLogEntry { state.sleepLogs[entryIndex] }
    private var isToday: Bool {
        let cal = Calendar.current
        return cal.isDateInToday(entry.date) || cal.isDateInYesterday(entry.date)
    }

    // Entry is for today and hasn't been rated yet — the wind-down flow ran but
    // the user hasn't yet logged a morning score. Renders a non-editable welcome
    // card (the user can't rate "this morning" until they've slept). Now only
    // reachable when an actual wind-down created the entry; the today-empty dot
    // path opens TonightInProgressView instead.
    private var isTonightInProgress: Bool {
        Calendar.current.isDateInToday(entry.date) && entry.score == 0
    }

    // Already has a sleep score logged — show the rated read-only state regardless
    // of whether the entry is from today, yesterday, or further back.
    private var isAlreadyRated: Bool { entry.score > 0 }

    private var isFirstNight: Bool {
        state.sleepLogs.allSatisfy { $0.score == 0 }
    }

    private let dayFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEEE · MMM d"; return f
    }()

    var body: some View {
        LullScreen(glow: false) {
            AmberGlow(x: 0.5, y: -0.05, radius: 240, opacity: 0.55)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    BrandMark()
                    Spacer()
                    Text(dayFmt.string(from: entry.date).uppercased())
                        .font(.mono(10.5))
                        .kerning(1.4)
                        .foregroundColor(.lullInk3)
                }
                .padding(.horizontal, Lull.horizontalPad)
                .padding(.top, 16)
                .padding(.bottom, 8)

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Title
                        VStack(alignment: .leading, spacing: 10) {
                            Kicker(text: isTonightInProgress
                                ? "Tonight in progress"
                                : (isAlreadyRated ? "Sleep log" : (isToday ? "Morning check-in" : "Sleep log")))

                            if isTonightInProgress {
                                Text(isFirstNight
                                    ? "This is your first night with Lull! 🌙"
                                    : "Tonight's routine is in progress 🌙")
                                    .font(.serif(28))
                                    .foregroundColor(.lullInk0)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .lineSpacing(3)

                                Text(isFirstNight
                                    ? "No sleep score logged yet. Finish your routine tonight and rate your sleep tomorrow morning — your first dot with sleep score will appear."
                                    : "No sleep score logged yet. Rate your sleep tomorrow morning and this dot will fill in.")
                                    .font(.system(size: 13.5))
                                    .foregroundColor(.lullInk2)
                                    .lineSpacing(4)
                                    .padding(.top, 4)
                            } else if isAlreadyRated {
                                Group {
                                    Text("How that morning ")
                                        .foregroundColor(.lullInk0)
                                    + Text("felt.")
                                        .foregroundColor(.lullAmber)
                                }
                                .font(.serif(30))
                            } else {
                                Group {
                                    Text(isToday ? "How does this morning " : "How that morning ")
                                        .foregroundColor(.lullInk0)
                                    + Text(isToday ? "feel?" : "felt.")
                                        .foregroundColor(.lullAmber)
                                }
                                .font(.serif(30))

                                if isToday {
                                    Text("One tap. We'll use this to understand how your wind-down is feeling.")
                                        .font(.system(size: 13.5))
                                        .foregroundColor(.lullInk2)
                                        .lineSpacing(3)
                                }
                            }
                        }
                        .padding(.horizontal, 28)
                        .padding(.top, 28)

                        // Score circles (disabled in tonight-in-progress state)
                        Group {
                            if isTonightInProgress {
                                SleepScoreSelector(score: .constant(0), disabled: true)
                                    .opacity(0.35)
                            } else if isAlreadyRated {
                                SleepScoreSelector(score: .constant(entry.score), disabled: true)
                            } else if isToday {
                                SleepScoreSelector(score: $draftScore)
                            } else {
                                SleepScoreSelector(score: .constant(entry.score), disabled: true)
                            }
                        }
                        .padding(.top, 40)

                        // Routine context label
                        HStack(spacing: 8) {
                            Text("BEDTIME ROUTINE")
                                .font(.mono(9.5))
                                .kerning(1.4)
                                .foregroundColor(.lullInk4)
                            Text(entry.completedNightlyFlow ? "COMPLETED" : "NOT COMPLETED")
                                .font(.mono(9.5))
                                .kerning(1)
                                .foregroundColor(.lullAmberSoft)
                        }
                        .padding(.horizontal, 28)
                        .padding(.top, 24)

                        // Notes section (hidden during tonight-in-progress)
                        if isTonightInProgress {
                            EmptyView()
                        } else if isAlreadyRated {
                            if !entry.notes.isEmpty { pastNotesSection }
                        } else if isToday {
                            todayNotesSection
                        } else if !entry.notes.isEmpty {
                            pastNotesSection
                        }
                    }
                }

                // CTAs
                if isTonightInProgress {
                    GhostButton(title: "Got it") { dismiss() }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 22)
                        .padding(.top, 16)
                        .padding(.bottom, 36)
                } else if isAlreadyRated {
                    GhostButton(title: "Done") { dismiss() }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 22)
                        .padding(.top, 16)
                        .padding(.bottom, 36)
                } else if isToday {
                    VStack(spacing: 0) {
                        PrimaryCTA(title: "Log this morning") {
                            let scoreToLog = AppState.clampedSleepScore(draftScore)
                            state.sleepLogs[entryIndex].score = scoreToLog
                            state.sleepLogs[entryIndex].notes = draftNotes
                            state.persist()
                            dismiss()
                            state.presentPendingStreakMilestoneIfEligible()
                        }
                        .disabled(draftScore == 0)
                        .opacity(draftScore == 0 ? 0.45 : 1)

                        GhostButton(title: "Skip for now") { dismiss() }
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 16)
                    .padding(.bottom, 36)
                } else {
                    GhostButton(title: "Done") { dismiss() }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 22)
                        .padding(.top, 16)
                        .padding(.bottom, 36)
                }
            }
        }
        .onAppear {
            draftScore = entry.score
            draftNotes = entry.notes
        }
    }

    // MARK: - Notes UI (today)

    private var todayNotesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ADD A NOTE")
                .font(.mono(9.5))
                .kerning(1.4)
                .foregroundColor(.lullInk4)
                .padding(.horizontal, 28)
                .padding(.top, 28)

            HStack(spacing: 10) {
                noteTypeButton(icon: "text.alignleft", label: "Type", active: noteMode == .text) {
                    noteMode = .text
                }
                noteTypeButton(icon: "mic.fill", label: "Voice", active: noteMode == .voice) {
                    if isRecording { recorder?.stop(); isRecording = false }
                    noteMode = .voice
                }
            }
            .padding(.horizontal, 28)

            if noteMode == .text {
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white.opacity(0.04))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.lullLine, lineWidth: 1))
                    if draftNotes.isEmpty {
                        Text("Did you fall asleep when you planned to?")
                            .font(.system(size: 14))
                            .foregroundColor(.lullInk4)
                            .padding(14)
                    }
                    TextEditor(text: $draftNotes)
                        .font(.system(size: 14))
                        .foregroundColor(.lullInk1)
                        .scrollContentBackground(.hidden)
                        .background(.clear)
                        .padding(10)
                }
                .frame(height: 100)
                .padding(.horizontal, 28)
            }

            if noteMode == .voice {
                HStack(spacing: 14) {
                    Button(action: toggleVoiceRecording) {
                        HStack(spacing: 8) {
                            Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                            Text(isRecording ? "Stop" : "Record")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "#1a0d06"))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(isRecording ? Color.red.opacity(0.8) : Color.lullAmber))
                    }
                    .buttonStyle(.plain)

                    if !draftNotes.isEmpty {
                        Text(draftNotes)
                            .font(.system(size: 13))
                            .foregroundColor(.lullInk2)
                            .lineLimit(2)
                    } else if isRecording {
                        Text("Recording…")
                            .font(.mono(11))
                            .foregroundColor(.lullInk3)
                    }
                }
                .padding(.horizontal, 28)
            }
        }
    }

    // MARK: - Notes UI (past)

    private var pastNotesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NOTES")
                .font(.mono(9.5))
                .kerning(1.4)
                .foregroundColor(.lullInk4)

            Text(entry.notes)
                .font(.system(size: 14))
                .foregroundColor(.lullInk2)
                .lineSpacing(4)
        }
        .padding(.horizontal, 28)
        .padding(.top, 28)
    }

    // MARK: - Helpers

    private func noteTypeButton(icon: String, label: String, active: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                Text(label)
                    .font(.system(size: 14))
            }
            .foregroundColor(active ? Color.lullAmber : .lullInk1)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 14).fill(active ? Color.lullAmber.opacity(0.08) : Color.white.opacity(0.04)))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(active ? Color.lullAmber.opacity(0.4) : Color.lullLine, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func toggleVoiceRecording() {
        if isRecording {
            recorder?.stop()
            isRecording = false
            draftNotes = "Voice note recorded"
        } else {
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.playAndRecord, mode: .default)
            try? session.setActive(true)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("sleep-note.m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 12000,
                AVNumberOfChannelsKey: 1
            ]
            recorder = try? AVAudioRecorder(url: url, settings: settings)
            recorder?.record()
            isRecording = true
        }
    }
}
