import SwiftUI
import FamilyControls

struct MyRoutineView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedStepID: UUID? = nil
    @State private var libraryTarget: RoutineSectionKind? = nil
    @State private var addedLibraryID: String? = nil
    @State private var showScience = false
    @State private var showChangeConfirm = false
    @State private var showCandidatePicker = false
    @State private var showHistoryLegend = false
    @State private var showTonightInProgress = false

    private var prepSteps: [RoutineStep] { state.routinePrepSteps }
    private var ritualSteps: [RoutineStep] { state.routineRitualSteps }
    private static let routineTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm"
        return formatter
    }()

    private var routineStepTimes: [UUID: String] {
        let calendar = Calendar.current
        let bedtime = state.typicalBedtime
        var times: [UUID: String] = [:]

        for step in prepSteps {
            let time = calendar.date(byAdding: .minute, value: -step.resolvedLeadTimeMins, to: bedtime) ?? bedtime
            times[step.id] = Self.routineTimeFormatter.string(from: time)
        }

        var ritualSchedule: [(step: RoutineStep, time: Date)] = []
        var sequenceOffset = 0
        for step in ritualSteps.reversed() {
            sequenceOffset += routineDisplayDurationMinutes(for: step)
            let time = calendar.date(byAdding: .minute, value: -sequenceOffset, to: bedtime) ?? bedtime
            ritualSchedule.append((step, time))
        }

        if let firstTime = ritualSchedule.map(\.time).min() {
            let windowStart = calendar.date(byAdding: .minute, value: -state.sleepWindowMinutes, to: bedtime) ?? bedtime
            if firstTime > windowStart {
                let shift = Int(firstTime.timeIntervalSince(windowStart) / 60)
                ritualSchedule = ritualSchedule.map { row in
                    (row.step, calendar.date(byAdding: .minute, value: -shift, to: row.time) ?? row.time)
                }
            }
        }

        for row in ritualSchedule {
            times[row.step.id] = Self.routineTimeFormatter.string(from: row.time)
        }

        return times
    }

    private func routineDisplayDurationMinutes(for step: RoutineStep) -> Int {
        if step.label == R.boringStory {
            let seconds = (step.boringStoryConfig ?? .fresh).storyId.durationSeconds
            return max(1, Int(ceil(Double(seconds) / 60.0)))
        }

        if step.label == R.sleepSounds {
            let config = step.sleepSoundConfig ?? .fresh
            return config.infinite ? 5 : max(1, config.durationMinutes ?? 60)
        }

        if let kind = NightlyStepKind.forLabel(step.label) {
            return max(1, kind.estimatedMinutes)
        }

        return minutesFromDurationLabel(step.durationLabel) ?? 5
    }

    private func minutesFromDurationLabel(_ label: String?) -> Int? {
        guard let label else { return nil }
        let pattern = #"(?:(\d+)\s*hr)?(?:\s*(\d+)\s*m)?(?:\s*(\d+)\s*s)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: label, range: NSRange(label.startIndex..., in: label)),
              match.range.location != NSNotFound
        else { return nil }

        func value(at index: Int) -> Int {
            guard match.range(at: index).location != NSNotFound,
                  let range = Range(match.range(at: index), in: label)
            else { return 0 }
            return Int(label[range]) ?? 0
        }

        let hours = value(at: 1)
        let minutes = value(at: 2)
        let seconds = value(at: 3)
        let totalSeconds = (hours * 60 + minutes) * 60 + seconds
        return totalSeconds > 0 ? max(1, Int(ceil(Double(totalSeconds) / 60.0))) : nil
    }

    private var candidates: [String] {
        let inRoutine = Set(state.coreRoutine.map(\.label))
        var seen: Set<String> = []
        return (allBedroomPrepRemedies + allWindDownRemedies)
            .filter { seen.insert($0).inserted }
            .filter { !inRoutine.contains($0) || $0 == state.tonightVariable }
    }

    private var suggestedVariable: String? {
        if state.experimentStatus != nil {
            return state.tonightVariable
        }

        let routineWithoutExperiment = state.coreRoutine.filter { $0.mode != .experiment }
        return ExperimentEngine.suggestNextVariable(
            logs: state.sleepLogs,
            coreRoutine: routineWithoutExperiment,
            remedyScores: state.remedyScores
        )
    }

    private var avgScoreText: String? {
        let scored = state.sleepLogs.filter { $0.score > 0 }
        guard !scored.isEmpty else { return nil }
        let avg = Double(scored.map(\.score).reduce(0, +)) / Double(scored.count)
        return String(format: "AVG %.1f", avg)
    }

    private var displaySlots: [DotSlot] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        let pastDayCount: Int
        if let earliest = state.sleepLogs.map(\.date).min() {
            let days = cal.dateComponents([.day], from: cal.startOfDay(for: earliest), to: today).day ?? 0
            pastDayCount = min(days, 13)
        } else {
            pastDayCount = 0
        }
        let futureDayCount = 13 - pastDayCount

        var slots: [DotSlot] = []

        for i in stride(from: pastDayCount, through: 1, by: -1) {
            let date = cal.date(byAdding: .day, value: -i, to: today)!
            let entry = state.sleepLogs.first { cal.isDate($0.date, inSameDayAs: date) }
            slots.append(DotSlot(date: date, entry: entry))
        }

        let todayEntry = state.sleepLogs.first { cal.isDateInToday($0.date) }
        slots.append(DotSlot(date: today, entry: todayEntry))

        if futureDayCount > 0 {
            for i in 1...futureDayCount {
                let date = cal.date(byAdding: .day, value: i, to: today)!
                slots.append(DotSlot(date: date, entry: nil))
            }
        }

        return slots
    }

    var body: some View {
        ZStack {
            ZStack(alignment: .bottom) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        Spacer().frame(height: 28)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Rules")
                                .font(.serif(30))
                                .foregroundColor(.lullInk0)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Text("Edit your sleep contract, blocked apps, and replacement plan.")
                                .font(.system(size: 13.5, weight: .regular, design: .default))
                                .foregroundColor(.lullInk3)
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, 22)

                        RulesContractSummaryCard()
                            .environmentObject(state)
                            .padding(.horizontal, 22)

                        RoutineStepSection(
                            number: "01",
                            title: "Prep",
                            suffix: "· before bed",
                            steps: prepSteps,
                            section: .prep,
                            scheduledTimes: routineStepTimes,
                            onSelect: { step in
                                if state.canCustomizeRoutine || step.isScreenBlockingConfigurationStep {
                                    selectedStepID = step.id
                                } else {
                                    state.presentUpgradePaywall()
                                }
                            },
                            onMove: { moving, target in
                                state.moveRoutineStep(moving, before: target, in: .prep)
                            },
                            onMoveToIndex: { moving, targetIndex in
                                state.moveRoutineStep(moving, toIndex: targetIndex, in: .prep)
                            },
                            onDelete: { step in
                                state.removeRoutineStep(step)
                            },
                            onAdd: {
                                libraryTarget = .prep
                            }
                        )
                        .padding(.horizontal, 22)

                        RoutineStepSection(
                            number: "02",
                            title: "Ritual",
                            suffix: "· in bed",
                            steps: ritualSteps,
                            section: .ritual,
                            scheduledTimes: routineStepTimes,
                            onSelect: { step in
                                if state.canCustomizeRoutine || step.isScreenBlockingConfigurationStep {
                                    selectedStepID = step.id
                                } else {
                                    state.presentUpgradePaywall()
                                }
                            },
                            onMove: { moving, target in
                                state.moveRoutineStep(moving, before: target, in: .ritual)
                            },
                            onMoveToIndex: { moving, targetIndex in
                                state.moveRoutineStep(moving, toIndex: targetIndex, in: .ritual)
                            },
                            onDelete: { step in
                                state.removeRoutineStep(step)
                            },
                            onAdd: {
                                libraryTarget = .ritual
                            }
                        )
                        .padding(.horizontal, 22)

                        Spacer().frame(height: 40)
                    }
                    .padding(.bottom, 118)
                }
                .zIndex(1)

                if let target = libraryTarget {
                    StepLibraryOverlay(
                        addedLibraryID: $addedLibraryID,
                        targetSection: target,
                        onClose: { libraryTarget = nil },
                        onAdd: { item in
                            guard item.defaultSection != .morning else { return }
                            addedLibraryID = item.id
                            let newStep = state.addRoutineStep(from: item)
                            let delay = reduceMotion ? 0.2 : 0.25
                            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                libraryTarget = nil
                                selectedStepID = newStep.id
                                addedLibraryID = nil
                            }
                        }
                    )
                    .transition(reduceMotion ? .opacity : .asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .bottom)),
                        removal: .opacity
                    ))
                    .zIndex(2)
                }

                if let step = selectedStep {
                    if step.label == R.sleepSounds {
                        if state.canUseSleepSounds {
                            SleepSoundsStep(
                                initial: step.sleepSoundConfig ?? .fresh,
                                mode: .editStep,
                                onSave: { config in
                                    var updated = step
                                    updated.sleepSoundConfig = config
                                    updated.durationLabel = config.infinite ? "∞" : config.durationSummary
                                    state.updateRoutineStep(updated)
                                    selectedStepID = nil
                                },
                                onDismiss: { selectedStepID = nil }
                            )
                            .id(step.id)
                            .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                            .zIndex(3)
                        } else {
                            Color.clear
                                .onAppear {
                                    selectedStepID = nil
                                    state.presentUpgradePaywall()
                                }
                        }
                    } else if step.label == R.boringStory {
                        BoringStoryStep(
                            initial: step.boringStoryConfig ?? .fresh,
                            onSave: { config in
                                var updated = step
                                updated.boringStoryConfig = config
                                updated.durationLabel = config.durationSummary
                                updated.remedyId = .boringStory
                                state.updateRoutineStep(updated)
                                selectedStepID = nil
                            },
                            onDismiss: { selectedStepID = nil }
                        )
                        .id(step.id)
                        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                        .zIndex(3)
                    } else {
                        EditStepSheet(
                            step: step,
                            section: state.sectionKind(for: step),
                            onClose: { selectedStepID = nil },
                            onRemove: {
                                if state.canCustomizeRoutine {
                                    state.removeRoutineStep(step)
                                } else {
                                    state.presentUpgradePaywall()
                                }
                                selectedStepID = nil
                            },
                            onSave: { updated in
                                if step.isScreenBlockingConfigurationStep || state.canCustomizeRoutine {
                                    if state.canCustomizeRoutine {
                                        state.updateRoutineStep(updated)
                                    }
                                } else {
                                    state.presentUpgradePaywall()
                                }
                                selectedStepID = nil
                            }
                        )
                        .id(step.id)
                        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                        .zIndex(3)
                    }
                }
            }
            .animation(reduceMotion ? .easeInOut(duration: 0.2) : .easeOut(duration: 0.28), value: libraryTarget != nil)
            .animation(reduceMotion ? .easeInOut(duration: 0.2) : .easeOut(duration: 0.28), value: selectedStepID)
        }
        .foregroundColor(.lullInk1)
        .preferredColorScheme(.dark)
        .requestsSolidTabBar(libraryTarget != nil || selectedStepID != nil)
        .alert("Change experiment?", isPresented: $showChangeConfirm) {
            Button("Keep testing") { }
            Button("Yes, change it", role: .destructive) { showCandidatePicker = true }
        } message: {
            Text("You've only tested \"\(state.tonightVariable)\" for \(state.variableNight) night\(state.variableNight == 1 ? "" : "s"). Switching now means losing that data.")
        }
        .sheet(isPresented: $showScience) {
            ScienceSheet(
                remedyName: state.tonightVariable,
                remedyId: state.tonightRemedyId
            )
            .presentationDetents([.fraction(0.45)])
            .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showCandidatePicker) {
            CandidatePickerSheet(
                candidates: candidates,
                suggestedVariable: suggestedVariable,
                currentVariable: state.tonightVariable
            ) { chosen in
                state.changeExperimentVariable(to: chosen)
                showCandidatePicker = false
            }
        }
        .sheet(isPresented: Binding(
            get: { state.selectedDotIndex != nil },
            set: { if !$0 { state.selectedDotIndex = nil } }
        )) {
            if let index = state.selectedDotIndex {
                SleepLogDetailView(entryIndex: index)
            }
        }
        .sheet(isPresented: $showHistoryLegend) {
            SleepHistoryLegendView()
        }
        .sheet(isPresented: $showTonightInProgress) {
            TonightInProgressView()
        }
        .onAppear {
            consumeRequestedRoutineStep()
        }
        .onChange(of: state.requestedRoutineStepIDToEdit) { _, _ in
            consumeRequestedRoutineStep()
        }
    }

    private var selectedStep: RoutineStep? {
        guard let selectedStepID else { return nil }
        return state.coreRoutine.first { $0.id == selectedStepID }
    }

    private func consumeRequestedRoutineStep() {
        guard let id = state.requestedRoutineStepIDToEdit else { return }
        selectedStepID = id
        state.requestedRoutineStepIDToEdit = nil
    }
}

// MARK: - New Routine Surface

enum RoutineSectionKind: String, CaseIterable, Codable {
    case prep
    case ritual
    case morning

    var title: String {
        switch self {
        case .prep: return "Prep"
        case .ritual: return "Ritual"
        case .morning: return "Morning"
        }
    }
}

struct RoutineTopHeader: View {
    var bedtime: Date

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Sleep contract")
                    .font(.system(size: 12, weight: .semibold, design: .default))
                    .foregroundColor(.lullAmberSoft)
                Text("Tonight")
                    .font(.serif(30))
                    .foregroundColor(.lullInk0)
            }

            Spacer()

            HStack(spacing: 7) {
                Image(systemName: "moon.fill")
                    .font(.system(size: 10))
                Text(Self.timeFormatter.string(from: bedtime))
                    .font(.mono(10.5))
            }
            .foregroundColor(.lullInk1)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(
                Capsule()
                    .fill(Color.lullAmber.opacity(0.045))
                    .overlay(Capsule().strokeBorder(Color.lullLine, lineWidth: 1))
            )
        }
    }
}

private struct RulesContractSummaryCard: View {
    @EnvironmentObject private var state: AppState

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    private var sleepWindow: String {
        "\(Self.timeFormatter.string(from: state.typicalBedtime)) - \(Self.timeFormatter.string(from: state.appBlockingEndTime))"
    }

    private var blockedAppSummary: String {
        let appCount = state.appBlockingSelection.applicationTokens.count
        let categoryCount = state.appBlockingSelection.categoryTokens.count

        switch (appCount, categoryCount) {
        case (0, 0):
            return "Choose the apps that steal your sleep."
        case (_, 0):
            return "\(appCount) app\(appCount == 1 ? "" : "s") selected"
        case (0, _):
            return "\(categoryCount) categor\(categoryCount == 1 ? "y" : "ies") selected"
        default:
            return "\(appCount) app\(appCount == 1 ? "" : "s") · \(categoryCount) categor\(categoryCount == 1 ? "y" : "ies")"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            contractHeader

            Divider().overlay(Color.lullLine)

            VStack(spacing: 10) {
                contractRow(
                    icon: "moon.fill",
                    title: "Sleep window",
                    detail: "Apps always lock during this window.",
                    trailing: sleepWindow
                )

                contractRow(
                    icon: "lock.shield.fill",
                    title: "Blocked apps",
                    detail: blockedAppSummary,
                    trailing: "Edit"
                ) {
                    state.startAppBlockingOfferSetup()
                }
            }

            if !state.sleepContractPreviewItems.isEmpty {
                Divider().overlay(Color.lullLine)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Daily rules")
                        .font(.mono(10.5))
                        .kerning(1.4)
                        .foregroundColor(.lullInk4)

                    ForEach(state.sleepContractPreviewItems) { item in
                        contractRow(
                            icon: ruleIcon(item.rule),
                            title: item.rule.title,
                            detail: item.rule.detail,
                            trailing: "\(Self.timeFormatter.string(from: item.dueAt)) · \(item.rule.graceMinutes)m"
                        )
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.lullBg2.opacity(0.56))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.lullLine, lineWidth: 1)
                )
        )
    }

    private var contractHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Sleep contract")
                .font(.mono(10.5))
                .kerning(1.5)
                .foregroundColor(.lullAmberSoft)
            Text("Miss a rule → apps lock. Confirm late → cooldown.")
                .font(.system(size: 13.5, weight: .medium))
                .foregroundColor(.lullInk2)
                .lineSpacing(3)
        }
    }

    @ViewBuilder
    private func contractRow(icon: String,
                             title: String,
                             detail: String,
                             trailing: String,
                             action: (() -> Void)? = nil) -> some View {
        let content = HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.lullAmber)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color.lullAmber.opacity(0.10)))
                .overlay(Circle().strokeBorder(Color.lullAmber.opacity(0.24), lineWidth: 1))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundColor(.lullInk0)
                Text(detail)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundColor(.lullInk3)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Text(trailing)
                .font(.mono(10.5))
                .foregroundColor(action == nil ? .lullInk3 : .lullAmber)
                .multilineTextAlignment(.trailing)
        }
        .contentShape(Rectangle())

        if let action {
            Button(action: action) { content }
                .buttonStyle(.plain)
        } else {
            content
        }
    }

    private func ruleIcon(_ rule: SleepRuleKind) -> String {
        switch rule {
        case .morningSun: return "sun.max.fill"
        case .caffeineCutoff: return "cup.and.saucer.fill"
        case .workoutCutoff: return "figure.strengthtraining.traditional"
        case .warmShower: return "shower.fill"
        case .dimLights: return "lightbulb.fill"
        case .tomorrowsPlan: return "checklist"
        case .gratitudeJournal: return "heart.text.square.fill"
        }
    }
}

struct ExperimentStrip: View {
    @State private var pulse = false
    var title: String
    var night: Int
    var total: Int
    var onViewScience: () -> Void
    var onSwitch: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.lullAmber.opacity(0.10))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.lullAmber.opacity(0.18), lineWidth: 1))
                    Image(systemName: "flask.fill")
                        .font(.system(size: 17))
                        .foregroundColor(.lullAmber)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 7) {
                        Circle()
                            .fill(Color.lullAmber)
                            .frame(width: 5, height: 5)
                            .opacity(pulse ? 1 : 0.45)
                            .shadow(color: .lullAmberGlow, radius: pulse ? 5 : 1)
                        Text("TESTING · NIGHT \(night)/\(total)")
                            .font(.mono(9.5))
                            .kerning(1.35)
                            .foregroundColor(.lullAmberSoft)
                    }

                    Text(title)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(.lullInk0)
                        .lineLimit(1)
                }

                Spacer(minLength: 10)

                HStack(spacing: 4) {
                    ForEach(0..<total, id: \.self) { index in
                        Circle()
                            .fill(index < night ? Color.lullAmber : Color.lullAmber.opacity(0.16))
                            .frame(width: 6, height: 6)
                            .shadow(color: index < night ? .lullAmberGlow : .clear, radius: 3)
                    }
                }
            }

            HStack(spacing: 8) {
                Button(action: onViewScience) {
                    Text("View science")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundColor(.lullInk1)
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background(
                            RoundedRectangle(cornerRadius: 11)
                                .fill(Color.white.opacity(0.035))
                                .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(Color.lullLine, lineWidth: 1))
                        )
                }
                .buttonStyle(.plain)

                Button(action: onSwitch) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Switch")
                            .font(.system(size: 12.5, weight: .medium))
                    }
                    .foregroundColor(.lullAmber)
                    .frame(width: 98, height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 11)
                            .fill(Color.lullAmber.opacity(0.08))
                            .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(Color.lullAmber.opacity(0.28), lineWidth: 1))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: [Color.lullAmber.opacity(0.10), Color.lullAmber.opacity(0.02)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.lullAmber.opacity(0.26), lineWidth: 1))
        )
        .onAppear { pulse = true }
        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulse)
    }
}

struct RoutineStepSection: View {
    var number: String
    var title: String
    var suffix: String
    var steps: [RoutineStep]
    var section: RoutineSectionKind
    var scheduledTimes: [UUID: String]
    var onSelect: (RoutineStep) -> Void
    var onMove: (RoutineStep, RoutineStep) -> Void
    var onMoveToIndex: (RoutineStep, Int) -> Void
    var onDelete: (RoutineStep) -> Void
    var onAdd: () -> Void
    @State private var draggingStepID: UUID? = nil
    @State private var dragTranslation: CGSize = .zero
    @State private var rowFrames: [UUID: CGRect] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(number)
                    .font(.system(size: 11, weight: .semibold, design: .default))
                    .foregroundColor(.lullAmberSoft)
                Text(title)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(.lullInk0)
                Text(suffix)
                    .font(.system(size: 11, weight: .medium, design: .default))
                    .foregroundColor(.lullInk4)
                Spacer()
                Text("\(steps.count) steps")
                    .font(.system(size: 11, weight: .semibold, design: .default))
                    .foregroundColor(.lullInk4)
            }

            VStack(spacing: 6) {
                ForEach(steps) { step in
                    StepRow(
                        step: step,
                        section: section,
                        scheduledTime: scheduledTimes[step.id] ?? "",
                        canDelete: step.mode != .experiment,
                        isReordering: draggingStepID == step.id,
                        reorderOffset: draggingStepID == step.id ? dragTranslation : .zero,
                        onReorderChanged: { translation in
                            draggingStepID = step.id
                            dragTranslation = translation
                        },
                        onReorderEnded: { translation in
                            move(step, by: translation)
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                                draggingStepID = nil
                                dragTranslation = .zero
                            }
                        },
                        onDelete: { onDelete(step) }
                    ) {
                        onSelect(step)
                    }
                    .opacity(draggingStepID == step.id ? 0.92 : 1)
                    .zIndex(draggingStepID == step.id ? 2 : 0)
                    .background(
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: RoutineStepFramePreferenceKey.self,
                                value: [step.id: proxy.frame(in: .global)]
                            )
                        }
                    )
                }
                AddStepRow(action: onAdd)
            }
        }
        .onPreferenceChange(RoutineStepFramePreferenceKey.self) { frames in
            rowFrames.merge(frames) { _, new in new }
        }
    }

    private func move(_ step: RoutineStep, by translation: CGSize) {
        guard steps.count > 1,
              let startFrame = rowFrames[step.id],
              let currentIndex = steps.firstIndex(where: { $0.id == step.id })
        else { return }

        let draggedMidY = startFrame.midY + translation.height
        let orderedFrames = steps.compactMap { rowStep -> (step: RoutineStep, frame: CGRect)? in
            guard let frame = rowFrames[rowStep.id] else { return nil }
            return (rowStep, frame)
        }

        guard orderedFrames.count == steps.count else { return }

        let rawIndex = orderedFrames.filter { row in
            row.step.id != step.id && draggedMidY > row.frame.midY
        }.count
        let targetIndex = min(max(rawIndex, 0), steps.count - 1)
        guard targetIndex != currentIndex else { return }

        onMoveToIndex(step, targetIndex)
    }
}

private struct RoutineStepFramePreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

struct StepRow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var step: RoutineStep
    var section: RoutineSectionKind
    var scheduledTime: String
    var canDelete: Bool
    var isReordering: Bool = false
    var reorderOffset: CGSize = .zero
    var onReorderChanged: (CGSize) -> Void = { _ in }
    var onReorderEnded: (CGSize) -> Void = { _ in }
    var onDelete: () -> Void
    var action: () -> Void
    @State private var rowOffset: CGFloat = 0

    private var isExperiment: Bool { step.mode == .experiment }
    private let deleteWidth: CGFloat = 52
    private var deleteRevealOpacity: Double {
        let reveal = max(0, -rowOffset - 10) / max(1, deleteWidth - 10)
        return min(1, Double(reveal))
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            if canDelete {
                Button(action: deleteStep) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(hex: "#e89189"))
                        .frame(width: 34, height: 34)
                        .background(
                            Circle()
                                .fill(Color(hex: "#e89189").opacity(0.075))
                                .overlay(Circle().strokeBorder(Color(hex: "#e89189").opacity(0.26), lineWidth: 1))
                        )
                }
                .frame(width: deleteWidth, height: 52, alignment: .center)
                .opacity(deleteRevealOpacity)
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                DragHandle()
                    .frame(width: 16)
                    .highPriorityGesture(reorderGesture)

                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(step.label)
                        .font(.system(size: 15.5, weight: .regular))
                        .foregroundColor(.lullInk0)
                        .lineLimit(1)
                    if isExperiment {
                        Text("Test")
                            .font(.system(size: 9.5, weight: .semibold, design: .default))
                            .foregroundColor(.lullAmber)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(metadata)
                    .font(.system(size: 11, weight: .medium, design: .default))
                    .foregroundColor(isExperiment ? .lullAmberSoft : .lullInk3)
                    .lineLimit(1)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isExperiment ? Color.lullAmber.opacity(0.06) : Color.white.opacity(0.025))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(isExperiment ? Color.lullAmber.opacity(0.35) : Color.lullLine, lineWidth: 1)
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 14))
            .onTapGesture {
                if rowOffset < 0 {
                    closeSwipe()
                } else {
                    action()
                }
            }
            .accessibilityAddTraits(.isButton)
            .offset(
                x: (canDelete ? rowOffset : 0) + (isReordering ? reorderOffset.width : 0),
                y: isReordering ? reorderOffset.height : 0
            )
            .scaleEffect(isReordering ? 1.015 : 1)
            .shadow(color: Color.black.opacity(isReordering ? 0.26 : 0), radius: isReordering ? 18 : 0, x: 0, y: 10)
            .animation(reduceMotion ? .easeInOut(duration: 0.18) : .spring(response: 0.24, dampingFraction: 0.86), value: isReordering)
            .simultaneousGesture(
                DragGesture(minimumDistance: 18)
                    .onChanged { value in
                        guard canDelete, abs(value.translation.width) > abs(value.translation.height) else { return }
                        if value.translation.width < 0 {
                            rowOffset = max(-deleteWidth, value.translation.width)
                        } else if rowOffset < 0 {
                            rowOffset = min(0, -deleteWidth + value.translation.width)
                        }
                    }
                    .onEnded { value in
                        guard canDelete, abs(value.translation.width) > abs(value.translation.height) else { return }
                        withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .easeOut(duration: 0.16)) {
                            if value.translation.width < -30 {
                                rowOffset = -deleteWidth
                            } else {
                                rowOffset = 0
                            }
                        }
                    }
            )
        }
    }

    private var reorderGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                guard abs(value.translation.height) > abs(value.translation.width) else { return }
                closeSwipe()
                onReorderChanged(value.translation)
            }
            .onEnded { value in
                guard abs(value.translation.height) > abs(value.translation.width) else {
                    onReorderEnded(.zero)
                    return
                }
                onReorderEnded(value.translation)
            }
    }

    private func closeSwipe() {
        withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .easeOut(duration: 0.16)) {
            rowOffset = 0
        }
    }

    private func deleteStep() {
        withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .easeOut(duration: 0.16)) {
            rowOffset = 0
        }
        onDelete()
    }

    private var metadata: String {
        scheduledTime
    }
}

struct RoutineRowButtonStyle: ButtonStyle {
    var reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.995 : 1)
            .brightness(configuration.isPressed ? 0.03 : 0)
            .animation(reduceMotion ? .easeInOut(duration: 0.2) : .easeOut(duration: configuration.isPressed ? 0.12 : 0.16), value: configuration.isPressed)
    }
}

struct DragHandle: View {
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<2, id: \.self) { _ in
                VStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { _ in
                        Circle()
                            .fill(Color.lullInk4)
                            .frame(width: 3, height: 3)
                    }
                }
            }
        }
        .frame(width: 18, height: 24)
        .contentShape(Rectangle())
    }
}

struct AddStepRow: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .semibold))
                Text("Add step")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(.lullAmberSoft)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.lullAmber.opacity(0.025))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                            .foregroundColor(Color.lullAmber.opacity(0.34))
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

struct RoutineProgressSection: View {
    var avgScoreText: String?
    var slots: [DotSlot]
    var sleepLogs: [SleepLogEntry]
    var onInfo: () -> Void
    var onTap: (Int) -> Void
    var onTodayEmptyTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("03")
                    .font(.mono(10))
                    .kerning(1.7)
                    .foregroundColor(.lullAmberSoft)
                Text("Progress")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(.lullInk0)
                Text("· last 14 nights")
                    .font(.mono(10))
                    .kerning(1.1)
                    .foregroundColor(.lullInk4)
                Spacer()
                if let avgScoreText {
                    Text(avgScoreText)
                        .font(.mono(9.5))
                        .kerning(1.1)
                        .foregroundColor(.lullInk4)
                }
                Button(action: onInfo) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.lullInk4)
                        .frame(width: 28, height: 28)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
            }

            ProgressDotsCard(
                slots: slots,
                sleepLogs: sleepLogs,
                onTap: onTap,
                onTodayEmptyTap: onTodayEmptyTap
            )
        }
    }
}

struct EditStepSheet: View {
    @EnvironmentObject var state: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var step: RoutineStep
    var section: RoutineSectionKind
    var onClose: () -> Void
    var onRemove: () -> Void
    var onSave: (RoutineStep) -> Void

    @State private var label: String
    @State private var leadTime: Double
    @State private var notes: String
    @State private var notifyEnabled: Bool
    @State private var sheetDragOffset: CGFloat = 0
    @State private var appBlockingSelection = FamilyActivitySelection()
    @State private var appBlockingEnabled = false
    @State private var appBlockingStartTime = Date()
    @State private var appBlockingEndTime = Date()
    @State private var appBlockingGraceMinutes = 5
    @State private var showFamilyActivityPicker = false

    init(step: RoutineStep,
         section: RoutineSectionKind,
         onClose: @escaping () -> Void,
         onRemove: @escaping () -> Void,
         onSave: @escaping (RoutineStep) -> Void) {
        self.step = step
        self.section = section
        self.onClose = onClose
        self.onRemove = onRemove
        self.onSave = onSave
        _label = State(initialValue: step.label)
        _leadTime = State(initialValue: Double(step.resolvedLeadTimeMins))
        _notes = State(initialValue: step.notes ?? "")
        _notifyEnabled = State(initialValue: step.notifyEnabled ?? true)
    }

    private var isAppBlockingStep: Bool {
        step.isScreenBlockingConfigurationStep
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ZStack {
                LinearGradient(colors: [.lullBg, .lullBg1], startPoint: .top, endPoint: .bottom)
                Color.black.opacity(backdropOpacity)
            }
                .ignoresSafeArea()
                .onTapGesture { onClose() }

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    Capsule()
                        .fill(Color.lullLineStrong)
                        .frame(width: 36, height: 4)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 6)
                        .padding(.bottom, 2)

                    HStack {
                        Text("Edit step · \(section.title.capitalized)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.lullAmberSoft)
                        Spacer()
                        Button(action: onClose) {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.lullInk2)
                                .frame(width: 36, height: 36)
                                .background(
                                    Circle()
                                        .fill(Color.white.opacity(0.04))
                                        .overlay(Circle().strokeBorder(Color.lullLine, lineWidth: 1))
                                )
                                .frame(width: 44, height: 44)
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }

                    if isAppBlockingStep {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Step · \(step.label)")
                                .font(.system(size: 12, weight: .semibold, design: .default))
                                .foregroundColor(.lullInk3)
                            Text("Your lock window")
                                .font(.system(size: 28, weight: .regular))
                                .foregroundColor(.lullInk0)
                        }
                    } else {
                        TextField("", text: $label)
                            .font(.system(size: 28, weight: .regular))
                            .foregroundColor(.lullInk0)
                            .tint(.lullAmber)
                            .padding(.bottom, 8)
                            .overlay(alignment: .bottom) {
                                Rectangle()
                                    .fill(Color.lullLineStrong)
                                    .frame(height: 1)
                            }
                    }

                    if section == .prep && !isAppBlockingStep {
                        WhenSlider(value: $leadTime)
                    } else if isAppBlockingStep && !state.canUseHardAppBlocking {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Gentle blocking")
                                .font(.system(size: 12, weight: .semibold, design: .default))
                                .foregroundColor(.lullInk3)
                            Text("Free blocking only runs during your sleep window and can be bypassed for the night.")
                                .font(.system(size: 12.5))
                                .foregroundColor(.lullInk3)
                                .lineSpacing(3)
                        }
                    }

                    if isAppBlockingStep {
                        InlineAppBlockingSection(
                            selection: $appBlockingSelection,
                            enabled: $appBlockingEnabled,
                            startTime: $appBlockingStartTime,
                            endTime: $appBlockingEndTime,
                            graceMinutes: $appBlockingGraceMinutes,
                            showPicker: $showFamilyActivityPicker,
                            bedtime: state.typicalBedtime,
                            wakeTime: state.typicalWakeTime,
                            isHardMode: state.canUseHardAppBlocking
                        )
                    } else {
                        StepScienceInline(step: step)

                        ToggleRow(isOn: $notifyEnabled, title: "NOTIFY")

                        VStack(alignment: .leading, spacing: 9) {
                            Text("NOTES · optional")
                                .font(.mono(10))
                                .kerning(1.5)
                                .foregroundColor(.lullInk3)
                            TextEditor(text: $notes)
                                .font(.system(size: 14))
                                .foregroundColor(.lullInk1)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 56)
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.black.opacity(0.28))
                                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.lullLine, lineWidth: 1))
                                )
                                .overlay(alignment: .topLeading) {
                                    if notes.isEmpty {
                                        Text("Add a note for yourself...")
                                            .font(.system(size: 14))
                                            .foregroundColor(.lullInk3)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 16)
                                            .allowsHitTesting(false)
                                    }
                                }
                        }
                    }

                    HStack(spacing: 10) {
                        if step.mode != .experiment {
                            Button(action: onRemove) {
                                HStack(spacing: 8) {
                                    Image(systemName: "trash")
                                    Text("Remove")
                                }
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(Color(hex: "#e89189"))
                                .frame(height: 48)
                                .padding(.horizontal, 18)
                                .background(
                                    Capsule()
                                        .fill(Color(hex: "#e89189").opacity(0.05))
                                        .overlay(Capsule().strokeBorder(Color(hex: "#e89189").opacity(0.35), lineWidth: 1))
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        Button(action: save) {
                            Text("Save")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.lullBgDeep)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(Capsule().fill(Color.lullAmber))
                                .shadow(color: .lullAmberGlow, radius: 14, y: 4)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 22)
                }
                .padding(.horizontal, 22)
            }
            .frame(maxHeight: UIScreen.main.bounds.height * 0.88)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(
                        LinearGradient(
                            colors: [Color.lullBg2, Color.lullBg1],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .strokeBorder(Color.lullLineStrong, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.55), radius: 34, y: -8)
            )
            .offset(y: sheetDragOffset)
            .optionalSimultaneousGesture(dismissDragGesture, isEnabled: !isAppBlockingStep)
        }
        .familyActivityPicker(isPresented: $showFamilyActivityPicker, selection: $appBlockingSelection)
        .onAppear(perform: hydrateAppBlockingState)
    }

    private var backdropOpacity: Double {
        let progress = min(1, sheetDragOffset / 260)
        return 0.55 - (0.18 * Double(progress))
    }

    private var dismissDragGesture: some Gesture {
        DragGesture(minimumDistance: 14, coordinateSpace: .global)
            .onChanged { value in
                guard isDismissDrag(value) else { return }
                sheetDragOffset = max(0, value.translation.height)
            }
            .onEnded { value in
                guard isDismissDrag(value) else {
                    settleSheet()
                    return
                }

                let shouldDismiss = value.translation.height > 110 || value.predictedEndTranslation.height > 220
                if shouldDismiss {
                    dismissWithDrag()
                } else {
                    settleSheet()
                }
            }
    }

    private func isDismissDrag(_ value: DragGesture.Value) -> Bool {
        return value.translation.height > 0 && abs(value.translation.height) > abs(value.translation.width) * 1.15
    }

    private func settleSheet() {
        withAnimation(reduceMotion ? .easeInOut(duration: 0.18) : .spring(response: 0.28, dampingFraction: 0.86)) {
            sheetDragOffset = 0
        }
    }

    private func dismissWithDrag() {
        withAnimation(reduceMotion ? .easeInOut(duration: 0.16) : .easeOut(duration: 0.18)) {
            sheetDragOffset = UIScreen.main.bounds.height
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.08 : 0.12)) {
            onClose()
        }
    }

    private func save() {
        var updated = step
        if !isAppBlockingStep {
            updated.label = label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? step.label : label.trimmingCharacters(in: .whitespacesAndNewlines)
            updated.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes
            updated.notifyEnabled = notifyEnabled
        }
        if section == .prep && !isAppBlockingStep {
            updated.leadTimeMins = Int((leadTime / 5).rounded() * 5)
        }
        if isAppBlockingStep {
            state.configureAppBlocking(
                selection: appBlockingSelection,
                enabled: appBlockingEnabled,
                startTime: appBlockingStartTime,
                endTime: appBlockingEndTime,
                graceMinutes: appBlockingGraceMinutes
            )
        }
        onSave(updated)
    }

    private func hydrateAppBlockingState() {
        guard isAppBlockingStep else { return }
        appBlockingSelection = state.appBlockingSelection
        appBlockingEnabled = state.appBlockingEnabled
        appBlockingStartTime = state.appBlockingStartTime
        appBlockingEndTime = state.appBlockingEndTime
        appBlockingGraceMinutes = state.appBlockingGraceMinutes

        let defaultStart = Calendar.current.date(
            byAdding: .minute,
            value: -30,
            to: state.typicalBedtime
        ) ?? state.typicalBedtime

        if appBlockingSelection.applicationTokens.isEmpty &&
            appBlockingSelection.categoryTokens.isEmpty &&
            !state.appBlockingEnabled {
            appBlockingEnabled = true
            appBlockingStartTime = defaultStart
            appBlockingEndTime = state.typicalWakeTime
        }
    }
}

struct WhenSlider: View {
    @Binding var value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("When")
                    .font(.system(size: 12, weight: .semibold, design: .default))
                    .foregroundColor(.lullInk3)
                Spacer()
                Text("\(Int(value)) min before bed")
                    .font(.system(size: 11, weight: .semibold, design: .default))
                    .foregroundColor(.lullAmber)
            }

            Slider(value: Binding(
                get: { value },
                set: { value = ($0 / 5).rounded() * 5 }
            ), in: 30...120, step: 5)
            .tint(.lullAmber)

            HStack {
                ForEach(["30m", "60m", "90m", "120m"], id: \.self) { tick in
                    Text(tick)
                        .font(.mono(9))
                        .foregroundColor(.lullInk4)
                    if tick != "120m" { Spacer() }
                }
            }
        }
    }
}

struct StepScienceInline: View {
    var step: RoutineStep

    private var impact: RemedyImpact? {
        (step.remedyId ?? RemedyID.fromLabel(step.label))?.impact
    }

    var body: some View {
        if let impact {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("Science")
                        .font(.system(size: 12, weight: .semibold, design: .default))
                        .foregroundColor(.lullInk3)
                    Spacer()
                    Text(impact.highlight)
                        .font(.system(size: 11, weight: .semibold, design: .default))
                        .foregroundColor(.lullAmber)
                }

                Text(impact.science)
                    .font(.system(size: 12.5))
                    .foregroundColor(.lullInk2)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.lullAmber.opacity(0.035))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.lullAmber.opacity(0.16), lineWidth: 1))
            )
        }
    }
}

@MainActor
final class AppBlockingAccessProbe: ObservableObject {
    static let shared = AppBlockingAccessProbe()

    @Published private(set) var statusText = "Not checked"
    @Published private(set) var detailText = "Allow Screen Time access so TenThirty can help reduce distracting apps during your bedtime window."
    @Published private(set) var isChecking = false
    @Published private(set) var isApproved = false

    private init() {
        refresh()
    }

    func refresh() {
        switch AuthorizationCenter.shared.authorizationStatus {
        case .approved, .approvedWithDataAccess:
            isApproved = true
            statusText = "Access approved"
            detailText = "Screen Time access is enabled. TenThirty can apply your selected app limits during bedtime."
        case .denied:
            isApproved = false
            statusText = "Access denied"
            detailText = "Screen Time access is off for TenThirty. You can enable it from iOS Settings when you want app blocking."
        case .notDetermined:
            isApproved = false
            statusText = "Not requested"
            detailText = "Tap Check access to let iOS ask for Screen Time permission."
        @unknown default:
            isApproved = false
            statusText = "Unknown status"
            detailText = "TenThirty could not read the current Screen Time permission. Check Settings and try again."
        }
        #if DEBUG
        print("[AppBlocking] authorizationStatus=\(statusText)")
        #endif
    }

    func requestAccess() async {
        isChecking = true
        defer { isChecking = false }

        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            refresh()
        } catch {
            isApproved = false
            statusText = "Request failed"
            detailText = error.localizedDescription
            #if DEBUG
            print("[AppBlocking] requestAuthorization failed: \(error)")
            #endif
        }
    }
}

struct InlineAppBlockingSection: View {
    @EnvironmentObject var state: AppState
    @ObservedObject private var probe = AppBlockingAccessProbe.shared
    @Binding var selection: FamilyActivitySelection
    @Binding var enabled: Bool
    @Binding var startTime: Date
    @Binding var endTime: Date
    @Binding var graceMinutes: Int
    @Binding var showPicker: Bool
    var bedtime: Date
    var wakeTime: Date
    var isHardMode: Bool

    private let graceOptions = [0, 5, 10, 15]

    private var appCount: Int { selection.applicationTokens.count }
    private var categoryCount: Int { selection.categoryTokens.count }
    private var totalCount: Int { appCount + categoryCount }

    private var statusColor: Color {
        probe.isApproved ? .lullAmber : Color(hex: "#e89189")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 8) {
                Text("App blocking")
                    .font(.system(size: 12, weight: .semibold, design: .default))
                    .foregroundColor(.lullInk3)
                Spacer()
                Text(probe.statusText)
                    .font(.system(size: 10.5, weight: .semibold, design: .default))
                    .foregroundColor(statusColor)
            }

            Text(probe.detailText)
                .font(.system(size: 12.5))
                .foregroundColor(.lullInk2)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            if probe.isApproved {
                if isHardMode {
                    AppBlockingLeadTimeCard(
                        startTime: $startTime,
                        endTime: $endTime,
                        bedtime: bedtime,
                        wakeTime: wakeTime
                    )

                    HStack(spacing: 10) {
                        AppBlockingTimeTile(
                            title: "LOCK AT",
                            value: timeFormatter.string(from: startTime),
                            detail: ""
                        )
                        AppBlockingTimeTile(
                            title: "UNLOCK AT",
                            value: timeFormatter.string(from: endTime),
                            detail: ""
                        )
                    }

                    BedtimeHintCard(
                        bedtime: bedtime,
                        lockTime: startTime
                    )
                } else {
                    HStack(spacing: 10) {
                        AppBlockingTimeTile(
                            title: "LOCK AT",
                            value: timeFormatter.string(from: bedtime),
                            detail: "Sleep window"
                        )
                        AppBlockingTimeTile(
                            title: "UNLOCK AT",
                            value: timeFormatter.string(from: wakeTime),
                            detail: ""
                        )
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("BLOCKING · \(totalCount) \(totalCount == 1 ? "app" : "apps")")
                            .font(.mono(10))
                            .kerning(1.5)
                            .foregroundColor(.lullInk3)
                        Spacer()
                        if categoryCount > 0 {
                            Text("\(categoryCount) categories")
                                .font(.mono(9.5))
                                .foregroundColor(.lullAmber)
                        }
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(displayBadges, id: \.self) { badge in
                                AppBlockingBadge(title: badge)
                            }

                            Button(action: {
                                guard !state.isContractEditingLocked() else { return }
                                showPicker = true
                            }) {
                                VStack(spacing: 6) {
                                    RoundedRectangle(cornerRadius: 14)
                                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                                        .foregroundColor(Color.lullAmber.opacity(0.45))
                                        .frame(width: 54, height: 54)
                                        .overlay(
                                            Image(systemName: "plus")
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(.lullAmber)
                                        )
                                    Text(totalCount == 0 ? "Add" : "Edit")
                                        .font(.system(size: 12.5, weight: .medium))
                                        .foregroundColor(.lullAmberSoft)
                                }
                            }
                            .buttonStyle(.plain)
                            .disabled(state.isContractEditingLocked())
                            .opacity(state.isContractEditingLocked() ? 0.55 : 1)
                        }
                    }
                }

                if isHardMode {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("GRACE WARNING")
                                .font(.mono(10))
                                .kerning(1.5)
                                .foregroundColor(.lullInk3)
                            Spacer()
                            Text(graceMinutes == 0 ? "Off" : "\(graceMinutes) min")
                                .font(.mono(9.5))
                                .foregroundColor(.lullAmber)
                        }

                        HStack(spacing: 8) {
                            ForEach(graceOptions, id: \.self) { option in
                                Button(action: { graceMinutes = option }) {
                                    Text(option == 0 ? "Off" : "\(option)m")
                                        .font(.mono(10))
                                        .foregroundColor(graceMinutes == option ? .lullBgDeep : .lullInk3)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 34)
                                        .background(
                                            Capsule()
                                                .fill(graceMinutes == option ? Color.lullAmber : Color.white.opacity(0.03))
                                                .overlay(Capsule().strokeBorder(graceMinutes == option ? Color.lullAmber : Color.lullLine, lineWidth: 1))
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                HStack {
                    Text("ENABLE")
                        .font(.mono(10))
                        .kerning(1.5)
                        .foregroundColor(.lullInk3)
                    Spacer()
                    Toggle("", isOn: $enabled)
                        .labelsHidden()
                        .tint(.lullAmber)
                }

                if !isHardMode {
                    Button {
                        state.bypassGentleAppBlockingUntilTomorrow()
                    } label: {
                        Text("Bypass tonight")
                            .font(.system(size: 13.5, weight: .medium))
                            .foregroundColor(.lullAmber)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(
                                Capsule()
                                    .fill(Color.lullAmber.opacity(0.06))
                                    .overlay(Capsule().strokeBorder(Color.lullAmber.opacity(0.28), lineWidth: 1))
                            )
                    }
                    .buttonStyle(.plain)
                }

                Text("Always allowed: TenThirty, Messages, Phone, Clock.")
                    .font(.mono(9.5))
                    .foregroundColor(.lullInk4)
            } else {
                Button {
                    state.trackHardAppBlockingPermissionRequested()
                    Task { await probe.requestAccess() }
                } label: {
                    HStack(spacing: 8) {
                        if probe.isChecking {
                            ProgressView()
                                .tint(.lullBgDeep)
                        } else {
                            Image(systemName: "lock.shield")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        Text("Check access")
                            .font(.system(size: 13.5, weight: .medium))
                    }
                    .foregroundColor(.lullBgDeep)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(Capsule().fill(Color.lullAmber))
                }
                .buttonStyle(.plain)
                .disabled(probe.isChecking)
                .opacity(probe.isChecking ? 0.75 : 1)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.lullAmber.opacity(0.035))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.lullAmber.opacity(0.16), lineWidth: 1))
        )
        .onAppear { probe.refresh() }
    }

    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }

    private var displayBadges: [String] {
        var badges: [String] = []
        if appCount > 0 {
            for index in 1...min(appCount, 5) {
                badges.append("App \(index)")
            }
        }
        if badges.isEmpty && categoryCount > 0 {
            for index in 1...min(categoryCount, 3) {
                badges.append("Category \(index)")
            }
        }
        return badges
    }
}

struct AppBlockingBadge: View {
    var title: String

    private var initials: String {
        String(title.prefix(1)).uppercased()
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.lullAmber.opacity(0.14))
                    .frame(width: 54, height: 54)
                Text(initials)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.lullInk0)
                Image(systemName: "lock.circle.fill")
                    .font(.system(size: 15))
                    .foregroundColor(.lullAmber)
                    .offset(x: 5, y: -5)
            }
            Text(title)
                .font(.system(size: 11.5))
                .foregroundColor(.lullInk2)
                .lineLimit(1)
        }
        .frame(width: 54)
    }
}

struct BedtimeHintCard: View {
    var bedtime: Date
    var lockTime: Date

    private var message: String {
        let diff = Int(bedtime.timeIntervalSince(lockTime) / 60)
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let bedtimeText = formatter.string(from: bedtime)
        if diff > 0 {
            return "Bedtime is \(bedtimeText) — locking \(diff) min earlier helps you wind down."
        }
        if diff < 0 {
            return "Bedtime is \(bedtimeText) — this starts \(abs(diff)) min after lights-out."
        }
        return "Bedtime is \(bedtimeText) — locking right at bedtime keeps the handoff clean."
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.lullAmber)
            Text(message)
                .font(.system(size: 12.5))
                .foregroundColor(.lullInk1)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.lullAmber.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.lullAmber.opacity(0.2), lineWidth: 1))
        )
    }
}

struct AppBlockingLeadTimeCard: View {
    @Binding var startTime: Date
    @Binding var endTime: Date
    var bedtime: Date
    var wakeTime: Date

    private let leadOptions = [0, 15, 30, 60, 90, 120]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("START BLOCKING")
                        .font(.mono(9.5))
                        .kerning(1.4)
                        .foregroundColor(.lullInk3)
                    Text(leadSummary)
                        .font(.system(size: 24, weight: .regular))
                        .foregroundColor(.lullInk0)
                }
                Spacer()
                Image(systemName: "lock.shield")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.lullAmber)
                    .frame(width: 34, height: 34)
                    .background(
                        Circle()
                            .fill(Color.lullAmber.opacity(0.10))
                            .overlay(Circle().strokeBorder(Color.lullAmber.opacity(0.25), lineWidth: 1))
                    )
            }

            Slider(
                value: Binding(
                    get: { Double(selectedLeadIndex) },
                    set: { value in
                        let index = max(0, min(leadOptions.count - 1, Int(value.rounded())))
                        applyLead(leadOptions[index], feedback: true)
                    }
                ),
                in: 0...Double(leadOptions.count - 1),
                step: 1
            )
            .tint(.lullAmber)

            HStack {
                ForEach(leadOptions, id: \.self) { minutes in
                    Text(tickLabel(minutes))
                        .font(.mono(8.5))
                        .foregroundColor(minutes == selectedLeadMinutes ? .lullAmber : .lullInk4)
                        .frame(maxWidth: .infinity)
                }
            }

            HStack(spacing: 8) {
                Label(timeFormatter.string(from: bedtime), systemImage: "moon.fill")
                Spacer()
                Label(timeFormatter.string(from: wakeTime), systemImage: "sun.horizon.fill")
            }
            .font(.mono(9.5))
            .foregroundColor(.lullInk3)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.025))
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.lullLine, lineWidth: 1))
        )
        .onAppear {
            applyLead(selectedLeadMinutes, feedback: false)
        }
        .onChange(of: bedtime) { _, _ in
            applyLead(selectedLeadMinutes, feedback: false)
        }
        .onChange(of: wakeTime) { _, newValue in
            endTime = newValue
        }
    }

    private var selectedLeadMinutes: Int {
        let current = minutesBeforeBed(startTime, bedtime: bedtime)
        return leadOptions.min(by: { abs($0 - current) < abs($1 - current) }) ?? 30
    }

    private var selectedLeadIndex: Int {
        leadOptions.firstIndex(of: selectedLeadMinutes) ?? 2
    }

    private var leadSummary: String {
        selectedLeadMinutes == 0 ? "At bedtime" : "\(selectedLeadMinutes) min before bed"
    }

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }

    private func tickLabel(_ minutes: Int) -> String {
        minutes == 0 ? "0" : "\(minutes)m"
    }

    private func applyLead(_ minutes: Int, feedback: Bool) {
        let nextStart = Calendar.current.date(byAdding: .minute, value: -minutes, to: bedtime) ?? bedtime
        if feedback && selectedLeadMinutes != minutes {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        startTime = nextStart
        endTime = wakeTime
    }

    private func minutesBeforeBed(_ start: Date, bedtime: Date) -> Int {
        let diff = (minutesOfDay(bedtime) - minutesOfDay(start) + 1440) % 1440
        return diff <= 720 ? diff : 0
    }

    private func minutesOfDay(_ date: Date) -> Int {
        let cal = Calendar.current
        return cal.component(.hour, from: date) * 60 + cal.component(.minute, from: date)
    }
}

struct AppBlockingTimeTile: View {
    var title: String
    var value: String
    var detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.mono(9.5))
                .kerning(1.5)
                .foregroundColor(.lullInk3)
            Text(value)
                .font(.system(size: 20, weight: .regular))
                .foregroundColor(.lullInk0)
            Text(detail)
                .font(.system(size: 11.5))
                .foregroundColor(.lullInk3)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.03))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.lullLine, lineWidth: 1))
        )
    }
}

struct Segmented: View {
    @Binding var selected: String
    var options: [String]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.self) { option in
                Button(action: { selected = option }) {
                    Text(option.uppercased())
                        .font(.mono(9.5))
                        .kerning(1)
                        .foregroundColor(selected == option ? .lullBgDeep : .lullInk3)
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                        .background(
                            Capsule()
                                .fill(selected == option ? Color.lullAmber : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.20))
                .overlay(Capsule().strokeBorder(Color.lullLine, lineWidth: 1))
        )
    }
}

struct ToggleRow: View {
    @Binding var isOn: Bool
    var title: String

    var body: some View {
        HStack {
            Text(title)
                .font(.mono(10))
                .kerning(1.5)
                .foregroundColor(.lullInk3)
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(.lullAmber)
        }
    }
}

private extension View {
    @ViewBuilder
    func optionalSimultaneousGesture<G: Gesture>(_ gesture: G, isEnabled: Bool) -> some View {
        if isEnabled {
            simultaneousGesture(gesture)
        } else {
            self
        }
    }
}

struct RoutineLibraryStep: Identifiable {
    let id: String
    let label: String
    let icon: String
    let blurb: String
    let effect: String
    let defaultSection: RoutineSectionKind
    let category: String
    let defaultWhen: Int?
    let defaultDur: String?
    let isPremium: Bool

    init(id: String,
         label: String,
         icon: String,
         blurb: String,
         effect: String,
         defaultSection: RoutineSectionKind,
         category: String,
         defaultWhen: Int?,
         defaultDur: String?,
         isPremium: Bool = false) {
        self.id = id
        self.label = label
        self.icon = icon
        self.blurb = blurb
        self.effect = effect
        self.defaultSection = defaultSection
        self.category = category
        self.defaultWhen = defaultWhen
        self.defaultDur = defaultDur
        self.isPremium = isPremium
    }
}

let STEP_LIBRARY: [RoutineLibraryStep] = [
    .init(id: "lights", label: "Dim the lights", icon: "lightbulb", blurb: "Drop ambient lighting", effect: "-6 min", defaultSection: .prep, category: "Wind down", defaultWhen: 75, defaultDur: nil),
    .init(id: "screens", label: "No screens", icon: "iphone.slash", blurb: "Phone & laptop off", effect: "-9 min", defaultSection: .prep, category: "Wind down", defaultWhen: 75, defaultDur: nil),
    .init(id: "app-blocking", label: R.appBlocking, icon: "lock.shield", blurb: "Block time-sink apps", effect: "locks", defaultSection: .prep, category: "Wind down", defaultWhen: 75, defaultDur: nil, isPremium: true),
    .init(id: "shower", label: "Warm shower", icon: "shower", blurb: "Drops core temp on exit", effect: "-7 min", defaultSection: .prep, category: "Wind down", defaultWhen: 90, defaultDur: nil),
    .init(id: "mag", label: "Magnesium glycinate", icon: "pills", blurb: "200-400 mg, 30m before bed", effect: "-4 min", defaultSection: .prep, category: "Wind down", defaultWhen: 45, defaultDur: nil),
    .init(id: "caffeine", label: "Caffeine cutoff", icon: "drop", blurb: "No coffee after 2 PM", effect: "+0.6/5", defaultSection: .prep, category: "Wind down", defaultWhen: 120, defaultDur: nil),
    .init(id: "cool", label: "Cool the room", icon: "thermometer.snowflake", blurb: "Set thermostat to 65°F", effect: "+0.4/5", defaultSection: .prep, category: "Environment", defaultWhen: 90, defaultDur: nil),
    .init(id: "curtain", label: "Blackout curtains", icon: "curtains.closed", blurb: "Block ambient morning light", effect: "+0.5/5", defaultSection: .prep, category: "Environment", defaultWhen: 60, defaultDur: nil),
    .init(id: "blanket", label: "Weighted blanket", icon: "sparkles", blurb: "10% of bodyweight", effect: "-11 min", defaultSection: .ritual, category: "In bed", defaultWhen: nil, defaultDur: "night"),
    .init(id: "bright", label: "Brightness check", icon: "sun.max", blurb: "Phone to lowest brightness", effect: "-2 min", defaultSection: .ritual, category: "In bed", defaultWhen: nil, defaultDur: "10s"),
    .init(id: "temp", label: "Temperature check", icon: "thermometer", blurb: "Log the room temp", effect: "logs", defaultSection: .ritual, category: "In bed", defaultWhen: nil, defaultDur: "10s"),
    .init(id: "dump", label: "Brain dump", icon: "mic", blurb: "Voice memo, 2 min", effect: "-4 min", defaultSection: .ritual, category: "In bed", defaultWhen: nil, defaultDur: "2m · voice"),
    .init(id: "story", label: "Boring story", icon: "book.closed", blurb: "Slow audio story", effect: "-12 min", defaultSection: .ritual, category: "In bed", defaultWhen: nil, defaultDur: BoringStoryStepConfig.fresh.durationSummary, isPremium: true),
    .init(id: "guided-meditation", label: "Guided meditation", icon: "figure.mind.and.body", blurb: "Coming soon", effect: "", defaultSection: .ritual, category: "In bed", defaultWhen: nil, defaultDur: nil),
    .init(id: "sleep-sounds", label: R.sleepSounds, icon: "water.waves", blurb: "Ambient audio loop", effect: "masks", defaultSection: .ritual, category: "In bed", defaultWhen: nil, defaultDur: "1 hr", isPremium: true),
    .init(id: "breath", label: "4·7·8 breathing", icon: "wind", blurb: "Slow exhale protocol", effect: "-5 min", defaultSection: .ritual, category: "In bed", defaultWhen: nil, defaultDur: "5m"),
    .init(id: "scan", label: "Body scan", icon: "sparkles", blurb: "Guided, 5 min", effect: "-3 min", defaultSection: .ritual, category: "In bed", defaultWhen: nil, defaultDur: "5m", isPremium: true),
    .init(id: "sunlight", label: "Sunlight, 10 min", icon: "sun.max", blurb: "Outside within 30m of waking", effect: "+0.7/5", defaultSection: .morning, category: "Mornings", defaultWhen: nil, defaultDur: nil),
    .init(id: "cold", label: "Cold water", icon: "drop", blurb: "Cold rinse, 30 sec", effect: "+0.5/5", defaultSection: .morning, category: "Mornings", defaultWhen: nil, defaultDur: nil),
    .init(id: "no-phone", label: "No phone, 30 min", icon: "iphone.slash", blurb: "Delay first screen", effect: "+0.4/5", defaultSection: .morning, category: "Mornings", defaultWhen: nil, defaultDur: nil),
]

struct StepLibraryOverlay: View {
    @EnvironmentObject var state: AppState
    @Binding var addedLibraryID: String?
    var targetSection: RoutineSectionKind
    var onClose: () -> Void
    var onAdd: (RoutineLibraryStep) -> Void

    @State private var query = ""
    @State private var selectedCategory: String

    init(addedLibraryID: Binding<String?>,
         targetSection: RoutineSectionKind,
         onClose: @escaping () -> Void,
         onAdd: @escaping (RoutineLibraryStep) -> Void) {
        _addedLibraryID = addedLibraryID
        self.targetSection = targetSection
        self.onClose = onClose
        self.onAdd = onAdd
        _selectedCategory = State(initialValue: targetSection == .ritual ? "In Bed" : "Before Bed")
    }

    private var categories: [String] {
        [targetSection == .ritual ? "In Bed" : "Before Bed"]
    }

    private var availableLibraryItems: [RoutineLibraryStep] {
        let baseItems = STEP_LIBRARY.filter {
            switch targetSection {
            case .prep:
                return $0.defaultSection == .prep
            case .ritual:
                return $0.defaultSection == .ritual
            case .morning:
                return false
            }
        }

        guard let appBlocking = STEP_LIBRARY.first(where: { $0.id == "app-blocking" }) else {
            return baseItems
        }

        switch targetSection {
        case .prep:
            return baseItems
        case .ritual:
            let ritualScopedAppBlocking = RoutineLibraryStep(
                id: "app-blocking-ritual",
                label: appBlocking.label,
                icon: appBlocking.icon,
                blurb: appBlocking.blurb,
                effect: appBlocking.effect,
                defaultSection: .ritual,
                category: "In bed",
                defaultWhen: nil,
                defaultDur: "night",
                isPremium: appBlocking.isPremium
            )
            return [ritualScopedAppBlocking] + baseItems
        case .morning:
            return baseItems
        }
    }

    private var filteredGroups: [(String, [RoutineLibraryStep])] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let visible = availableLibraryItems.filter { item in
            let group = groupName(for: item)
            let categoryMatch = group == selectedCategory
            let queryMatch = normalizedQuery.isEmpty || item.label.lowercased().contains(normalizedQuery)
            return categoryMatch && queryMatch
        }
        return categories.compactMap { group in
            let rows = visible.filter { groupName(for: $0) == group }
            return rows.isEmpty ? nil : (group, rows)
        }
    }

    private func groupName(for item: RoutineLibraryStep) -> String {
        item.defaultSection == .ritual ? "In Bed" : "Before Bed"
    }

    private var isLibraryLocked: Bool {
        !state.canCustomizeRoutine
    }

    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(colors: [.lullBg, .lullBg1], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            AmberGlow(x: 0.5, y: -0.04, radius: 260, opacity: 0.60)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Button(action: onClose) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.lullInk2)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.04))
                                    .overlay(Circle().strokeBorder(Color.lullLine, lineWidth: 1))
                            )
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Text("Step library")
                        .font(.system(size: 12, weight: .semibold, design: .default))
                        .foregroundColor(.lullInk3)
                    Spacer()
                    Color.clear.frame(width: 36, height: 36)
                }
                .padding(.horizontal, 22)
                .padding(.top, 16)
                .padding(.bottom, 18)

                Text("Add a step")
                    .font(.system(size: 28, weight: .regular))
                    .foregroundColor(.lullInk0)
                    .padding(.horizontal, 22)
                    .padding(.bottom, 16)

                ZStack {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 14))
                                .foregroundColor(.lullInk3)
                            TextField("Search \(availableLibraryItems.count) sleep tactics...", text: $query)
                                .font(.system(size: 14))
                                .foregroundColor(.lullInk0)
                                .tint(.lullAmber)
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 46)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.black.opacity(0.24))
                                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.lullLine, lineWidth: 1))
                        )
                        .padding(.horizontal, 22)
                        .padding(.bottom, 12)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(categories, id: \.self) { category in
                                    Button(action: { selectedCategory = category }) {
                                        Text(category)
                                            .font(.system(size: 11, weight: .semibold, design: .default))
                                            .foregroundColor(selectedCategory == category ? .lullAmber : .lullInk3)
                                            .padding(.horizontal, 12)
                                            .frame(height: 32)
                                            .background(
                                                Capsule()
                                                    .fill(selectedCategory == category ? Color.lullAmber.opacity(0.10) : Color.clear)
                                                    .overlay(Capsule().strokeBorder(selectedCategory == category ? Color.lullAmber.opacity(0.35) : Color.lullLine, lineWidth: 1))
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 22)
                        }
                        .padding(.bottom, 18)

                        ScrollView(showsIndicators: false) {
                            if filteredGroups.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("No matches")
                                        .font(.system(size: 12, weight: .semibold, design: .default))
                                        .foregroundColor(.lullInk3)
                                    Text("Try a different word - you can also describe what you want to do.")
                                        .font(.system(size: 13))
                                        .foregroundColor(.lullInk3)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 22)
                                .padding(.top, 16)
                            } else {
                                VStack(alignment: .leading, spacing: 18) {
                                    ForEach(filteredGroups, id: \.0) { group, rows in
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text(group)
                                                .font(.system(size: 11, weight: .semibold, design: .default))
                                                .foregroundColor(.lullInk3)
                                            VStack(spacing: 6) {
                                                ForEach(rows) { item in
                                                    LibraryRow(
                                                        item: item,
                                                        isActive: state.hasRoutineStep(label: item.label),
                                                        isExperiment: state.tonightVariable == item.label,
                                                        isAdding: addedLibraryID == item.id,
                                                        onAdd: { onAdd(item) }
                                                    )
                                                }
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, 22)
                                .padding(.bottom, 34)
                            }
                        }
                    }
                    .blur(radius: isLibraryLocked ? 7 : 0)
                    .opacity(isLibraryLocked ? 0.56 : 1)
                    .allowsHitTesting(!isLibraryLocked)

                    if isLibraryLocked {
                        StepLibraryUpgradeCard(
                            onUpgrade: {
                                state.presentUpgradePaywall()
                            },
                            onDismiss: onClose
                        )
                        .padding(.horizontal, 22)
                        .transition(.opacity)
                    }
                }
            }
        }
        .foregroundColor(.lullInk1)
        .preferredColorScheme(.dark)
    }
}

private struct StepLibraryUpgradeCard: View {
    var onUpgrade: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.lullAmber.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: "lock.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.lullAmber)
            }

            VStack(spacing: 8) {
                Text("Upgrade to Premium to Access These Features")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundColor(.lullInk0)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Customize your routine after the free trial ends, including premium tools for late-night wakeups.")
                    .font(.system(size: 13.5))
                    .foregroundColor(.lullInk2)
                    .lineSpacing(4)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }

            VStack(spacing: 11) {
                StepLibraryUpgradeBenefit(
                    title: "A routine built for your brain",
                    detail: "Personalized to what actually keeps you up"
                )
                StepLibraryUpgradeBenefit(
                    title: "Block the 1am scroll",
                    detail: "Lock distracting apps through your sleep window"
                )
                StepLibraryUpgradeBenefit(
                    title: "Quiet the overthinking",
                    detail: "Brain dump + guided breathing, step by step"
                )
                StepLibraryUpgradeBenefit(
                    title: "A nudge when it's time",
                    detail: "Gentle reminders that keep you on track"
                )
                StepLibraryUpgradeBenefit(
                    title: "Drift off, then silence",
                    detail: "Sleep sounds that fade out on their own"
                )
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.035))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.lullAmber.opacity(0.16), lineWidth: 1)
            )

            Button(action: onUpgrade) {
                Text("Subscribe")
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundColor(Color(hex: "#1a0d06"))
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Capsule().fill(Color.lullAmber))
                    .shadow(color: .lullAmberGlow, radius: 12, y: 4)
            }
            .buttonStyle(.plain)

            Button(action: onDismiss) {
                Text("No thanks, not now")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundColor(.lullInk3)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .fill(Color.lullBg.opacity(0.78))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(Color.lullAmber.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.45), radius: 24, y: 18)
    }
}

private struct StepLibraryUpgradeBenefit: View {
    var title: String
    var detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.lullAmber.opacity(0.12))
                    .frame(width: 22, height: 22)
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.lullAmber)
            }
            .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundColor(.lullInk0)
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundColor(.lullInk2)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct LibraryRow: View {
    var item: RoutineLibraryStep
    var isActive: Bool
    var isExperiment: Bool
    var isAdding: Bool
    var onAdd: () -> Void

    private var isComingSoon: Bool { item.id == "guided-meditation" }
    private var disabled: Bool { isActive || isComingSoon }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 11)
                    .fill(Color.black.opacity(0.18))
                    .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(Color.lullLine, lineWidth: 1))
                Image(systemName: item.icon)
                    .font(.system(size: 16))
                    .foregroundColor(isActive ? .lullAmber : .lullInk2)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(item.label)
                        .font(.system(size: 15.5, weight: .medium))
                        .foregroundColor(isComingSoon ? .lullInk2 : .lullInk0)
                        .lineLimit(1)
                        .layoutPriority(1)
                    if isExperiment {
                        Text("TESTING")
                            .font(.mono(8.5))
                            .kerning(1.2)
                            .foregroundColor(.lullAmber)
                    }
                    LibraryAccessChip(isPremium: item.isPremium)
                }
                Text(item.blurb)
                    .font(.system(size: 11.5))
                    .foregroundColor(isComingSoon ? .lullAmberSoft : .lullInk3)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if isComingSoon {
                Text("Coming soon")
                    .font(.mono(9.5))
                    .foregroundColor(.lullInk4)
            } else {
                Text(item.effect)
                    .font(.mono(9.5))
                    .foregroundColor(.lullAmberSoft)
                    .padding(.horizontal, 8)
                    .frame(height: 24)
                    .background(
                        Capsule()
                            .fill(Color.lullAmber.opacity(0.055))
                            .overlay(Capsule().strokeBorder(Color.lullAmber.opacity(0.25), lineWidth: 1))
                    )
            }

            Button(action: onAdd) {
                ZStack {
                    Circle()
                        .fill((isActive || isAdding) ? Color.lullAmber.opacity(0.14) : Color.white.opacity(0.035))
                        .overlay(Circle().strokeBorder((isActive || isAdding) ? Color.lullAmber.opacity(0.42) : Color.lullLineStrong, lineWidth: 1))
                    Image(systemName: (isActive || isAdding) ? "checkmark" : "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor((isActive || isAdding) ? .lullAmber : .lullInk2)
                }
                .frame(width: 28, height: 28)
                .scaleEffect(isAdding ? 1.1 : 1)
            }
            .buttonStyle(.plain)
            .disabled(disabled)
            .opacity(isComingSoon ? 0.55 : 1)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isExperiment ? Color.lullAmber.opacity(0.06) : Color.white.opacity(0.025))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(isExperiment ? Color.lullAmber.opacity(0.35) : Color.lullLine, lineWidth: 1)
                )
        )
        .animation(.easeOut(duration: 0.18), value: isAdding)
    }
}

private struct LibraryAccessChip: View {
    var isPremium: Bool

    var body: some View {
        Text(isPremium ? "Premium" : "Free")
            .font(.system(size: 9, weight: .semibold, design: .default))
            .foregroundColor(isPremium ? .lullAmber : .lullInk4)
            .padding(.horizontal, 6)
            .frame(height: 18)
            .background(
                Capsule()
                    .fill(isPremium ? Color.lullAmber.opacity(0.09) : Color.white.opacity(0.035))
                    .overlay(
                        Capsule().strokeBorder(
                            isPremium ? Color.lullAmber.opacity(0.28) : Color.white.opacity(0.08),
                            lineWidth: 1
                        )
                    )
            )
    }
}

// MARK: - Coach Mark

struct RoutineCoachMark: View {
    var onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.lullAmber.opacity(0.14))
                    .frame(width: 28, height: 28)
                Image(systemName: "flask.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.lullAmber)
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text("This is your sleep lab.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.lullInk0)
                Text("Test changes and build habits that actually work for you.")
                    .font(.system(size: 12))
                    .foregroundColor(.lullInk2)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11))
                    .foregroundColor(.lullInk3)
                    .frame(width: 32, height: 32)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.lullAmber.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            style: StrokeStyle(lineWidth: 1, dash: [5, 4])
                        )
                        .foregroundColor(Color.lullAmber.opacity(0.32))
                )
        )
    }
}

// MARK: - Experiment Hero Card

struct ExperimentHeroCard: View {
    @EnvironmentObject var state: AppState
    @Binding var showCandidatePicker: Bool
    @Binding var showChangeConfirm: Bool
    @State private var glowPulse = false
    @State private var showScience = false

    var insightLine: String {
        state.experimentStatus?.insightLine ?? "We're tracking if this moves the needle on your sleep."
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Pulsing glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.lullAmberGlow, .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 120
                    )
                )
                .frame(width: 240, height: 240)
                .offset(x: 40, y: -60)
                .scaleEffect(glowPulse ? 1.08 : 1.0)
                .opacity(glowPulse ? 0.95 : 0.55)
                .animation(.easeInOut(duration: 4.5).repeatForever(autoreverses: true), value: glowPulse)
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 0) {
                // Science sheet — attached here so it doesn't block button taps
                Color.clear.frame(width: 0, height: 0)
                    .sheet(isPresented: $showScience) {
                        ScienceSheet(
                            remedyName: state.tonightVariable,
                            remedyId: state.tonightRemedyId
                        )
                        .presentationDetents([.fraction(0.45)])
                        .presentationDragIndicator(.hidden)
                    }

                // Top row: kicker + badge
                HStack(alignment: .center) {
                    Kicker(text: "Tonight's experiment", color: .lullAmberSoft)
                    Spacer()
                    ActiveTestBadge()
                }
                .padding(.bottom, 10)

                // Variable name
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(state.tonightVariable)
                        .font(.system(size: 26, weight: .regular))
                        .foregroundColor(.lullInk0)
                    if state.variableIsOverridden {
                        Text("EDITED")
                            .font(.mono(9))
                            .kerning(1.4)
                            .foregroundColor(.lullInk3)
                    }
                }
                .padding(.bottom, 14)

                // Night progress bar
                NightProgressBar(current: state.variableNight, total: 5)
                    .padding(.bottom, 16)

                // Insight line
                Text(insightLine)
                    .font(.system(size: 13))
                    .foregroundColor(.lullInk1)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 14)

                // Expected impact
                ExpectedImpactBox(remedyId: state.tonightRemedyId)
                    .padding(.bottom, 16)

                // Action row
                HStack(spacing: 8) {
                    // Edit button
                    ExperimentIconBtn(systemImage: "pencil") {
                        if state.variableNight > 0 {
                            showChangeConfirm = true
                        } else {
                            showCandidatePicker = true
                        }
                    }

                    // Reset button
                    ExperimentIconBtn(systemImage: "arrow.counterclockwise", disabled: !state.variableIsOverridden) {
                        state.resetToSuggestedVariable()
                    }

                    Button(action: { showScience = true }) {
                        Text("View science · why this might work")
                            .font(.system(size: 12.5))
                            .foregroundColor(.lullInk1)
                            .frame(maxWidth: .infinity)
                    }
                    .frame(height: 38)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.04))
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.lullLine, lineWidth: 1))
                    )
                    .buttonStyle(.plain)
                }

                // Override note
                if state.variableIsOverridden {
                    HStack {
                        Text("You overrode TenThirty's suggestion.")
                            .font(.system(size: 11.5))
                            .foregroundColor(.lullInk2)
                        Spacer()
                        Button("Reset") {
                            state.resetToSuggestedVariable()
                        }
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(.lullAmber)
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.lullAmber.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                                    .foregroundColor(Color.lullAmber.opacity(0.28))
                            )
                    )
                    .padding(.top, 10)
                }
            }
            .padding(22)
        }
        .background(
            RoundedRectangle(cornerRadius: 26)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.lullAmber.opacity(0.12),
                            Color.lullAmber.opacity(0.03),
                            Color.lullAmber.opacity(0.02),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 26)
                        .strokeBorder(Color.lullAmber.opacity(0.32), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.45), radius: 24, y: 12)
        )
        .clipped()
        .onAppear { glowPulse = true }
    }
}

struct ActiveTestBadge: View {
    @State private var dotPulse = false

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.lullAmber)
                .frame(width: 6, height: 6)
                .shadow(color: .lullAmberGlow, radius: 4)
                .opacity(dotPulse ? 1.0 : 0.55)
                .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: dotPulse)
            Text("Active test")
                .font(.mono(9.5))
                .kerning(1.4)
                .foregroundColor(.lullAmber)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.lullAmber.opacity(0.14))
                .overlay(Capsule().strokeBorder(Color.lullAmber.opacity(0.4), lineWidth: 1))
        )
        .onAppear { dotPulse = true }
    }
}

struct NightProgressBar: View {
    var current: Int
    var total: Int

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                HStack(spacing: 0) {
                    Text("Night ")
                        .font(.mono(11))
                        .foregroundColor(.lullInk2)
                    Text("\(current)")
                        .font(.mono(11))
                        .foregroundColor(.lullAmber)
                    Text(" of \(total)")
                        .font(.mono(11))
                        .foregroundColor(.lullInk2)
                }
                Spacer()
                Text("\(total - current) testing nights left")
                    .font(.mono(10.5))
                    .foregroundColor(.lullInk3)
            }
            HStack(spacing: 4) {
                ForEach(0..<total, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 99)
                        .fill(i < current ? Color.lullAmber : Color.lullAmber.opacity(0.14))
                        .frame(height: 4)
                        .shadow(color: i < current ? .lullAmberGlow : .clear, radius: 4)
                }
            }
        }
    }
}

struct ExpectedImpactBox: View {
    var remedyId: RemedyID?

    private var impactData: RemedyImpact {
        remedyId?.impact ?? RemedyImpact(
            prefix: "Users like you fell asleep ",
            highlight: "−11 min",
            suffix: " faster.",
            science: ""
        )
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 14))
                .foregroundColor(.lullAmber)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text("EXPECTED IMPACT")
                    .font(.mono(9.5))
                    .kerning(1.4)
                    .foregroundColor(.lullAmberSoft)
                (Text(impactData.prefix)
                    .font(.system(size: 12.5))
                    .foregroundColor(.lullInk1)
                + Text(impactData.highlight)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundColor(.lullAmber)
                + Text(impactData.suffix)
                    .font(.system(size: 12.5))
                    .foregroundColor(.lullInk1))
                    .lineSpacing(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.45))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.lullLine, lineWidth: 1))
        )
    }
}

struct ScienceSheet: View {
    var remedyName: String
    var remedyId: RemedyID?
    @Environment(\.dismiss) private var dismiss

    private var scienceText: String {
        remedyId?.impact.science ?? ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Handle
            Capsule()
                .fill(Color.lullLine)
                .frame(width: 36, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
                .padding(.bottom, 24)

            // Icon + title
            HStack(spacing: 10) {
                Image(systemName: "flask")
                    .font(.system(size: 15))
                    .foregroundColor(.lullAmber)
                Text("Why this might work")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(.lullInk0)
            }
            .padding(.bottom, 6)

            Text(remedyName)
                .font(.mono(11))
                .kerning(1.2)
                .foregroundColor(.lullAmberSoft)
                .padding(.bottom, 20)

            Text(scienceText)
                .font(.system(size: 14.5))
                .foregroundColor(.lullInk1)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(.horizontal, 26)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.lullBg.ignoresSafeArea())
    }
}

struct ExperimentIconBtn: View {
    var systemImage: String
    var disabled: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13))
                .foregroundColor(disabled ? .lullInk4 : .lullInk1)
                .frame(width: 38, height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.04))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.lullLine, lineWidth: 1))
                )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1)
    }
}

// MARK: - Section Head

struct RoutineSectionHead: View {
    var title: String
    var eyebrow: String? = nil
    var sub: String? = nil
    var right: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(title)
                        .font(.system(size: 18, weight: .regular))
                        .fontWeight(.regular)
                        .foregroundColor(.lullInk0)
                    if let eyebrow {
                        Text("· \(eyebrow)")
                            .font(.mono(10))
                            .kerning(1.4)
                            .foregroundColor(.lullAmberSoft)
                    }
                }
                Spacer()
                if let right, !right.isEmpty {
                    Text(right)
                        .font(.mono(9.5))
                        .kerning(1.4)
                        .foregroundColor(.lullInk4)
                }
            }
            if let sub {
                Text(sub)
                    .font(.system(size: 12))
                    .foregroundColor(.lullInk3)
                    .lineSpacing(2)
            }
        }
    }
}

// MARK: - Drag Hint

struct DragHintLabel: View {
    var body: some View {
        HStack(spacing: 5) {
            Spacer()
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 9))
                .foregroundColor(.lullInk4)
            Text("DRAG TO REORDER")
                .font(.mono(9.5))
                .kerning(1.4)
                .foregroundColor(.lullInk4)
        }
    }
}

// MARK: - Prep List Row

struct PrepListRow: View {
    var step: RoutineStep
    var isExperiment: Bool
    var chip: String

    var body: some View {
        HStack(spacing: 12) {
            // Drag handle (shown by editMode)
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 13))
                .foregroundColor(.lullInk3)
                .frame(width: 20)

            Text(step.label)
                .font(.system(size: 14.5))
                .foregroundColor(.lullInk0)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(chip)
                .font(.mono(9.5))
                .kerning(0.8)
                .foregroundColor(isExperiment ? .lullAmber : .lullInk3)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(isExperiment ? Color.lullAmber.opacity(0.06) : Color.clear)
                        .overlay(
                            Capsule().strokeBorder(
                                isExperiment ? Color.lullAmber.opacity(0.35) : Color.lullLine,
                                lineWidth: 1
                            )
                        )
                )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isExperiment ? Color.lullAmber.opacity(0.06) : Color.white.opacity(0.025))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(
                            isExperiment ? Color.lullAmber.opacity(0.32) : Color.lullLine,
                            lineWidth: 1
                        )
                )
        )
    }
}

// MARK: - Ritual List Row

struct RitualListRow: View {
    @EnvironmentObject var state: AppState
    var number: Int
    var step: RoutineStep

    @State private var pulse = false

    private var isRecentlyPromoted: Bool {
        guard let id = state.recentlyPromotedRemedyId,
              let at = state.recentlyPromotedAt,
              step.remedyId == id else { return false }
        return Date().timeIntervalSince(at) < 7 * 24 * 60 * 60   // 7-day window
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 13))
                .foregroundColor(.lullInk3)
                .frame(width: 20)

            Text(step.label)
                .font(.system(size: 14.5))
                .foregroundColor(.lullInk0)
                .frame(maxWidth: .infinity, alignment: .leading)

            if isRecentlyPromoted {
                HStack(spacing: 4) {
                    Text("★")
                        .font(.system(size: 9))
                        .foregroundColor(.lullAmber)
                    Text("RECENTLY PROMOTED")
                        .font(.mono(9))
                        .kerning(1)
                        .foregroundColor(.lullAmber)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.lullAmber.opacity(0.12))
                        .overlay(Capsule().strokeBorder(Color.lullAmber.opacity(0.4), lineWidth: 1))
                )
            } else {
                Text("IN SEQUENCE")
                    .font(.mono(9))
                    .kerning(1)
                    .foregroundColor(.lullInk3)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .strokeBorder(Color.lullLine, lineWidth: 1)
                    )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isRecentlyPromoted ? Color.lullAmber.opacity(0.06) : Color.white.opacity(0.025))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(
                            isRecentlyPromoted ? Color.lullAmber.opacity(0.32) : Color.lullLine,
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: pulse ? .lullAmberGlow : .clear, radius: pulse ? 24 : 0)
        .onChange(of: state.routinePulseRemedyId) { _, newValue in
            if let id = newValue, step.remedyId == id {
                withAnimation(.easeInOut(duration: 0.4)) { pulse = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    withAnimation(.easeInOut(duration: 0.4)) { pulse = false }
                }
            }
        }
    }
}

// MARK: - Progress Dots Card

// MARK: - DotSlot

struct DotSlot {
    let date: Date
    let entry: SleepLogEntry?

    var isToday: Bool { Calendar.current.isDateInToday(date) }

    enum DotState { case inProgress, rated, unratedLocked, skipped, todayEmpty, future }

    var dotState: DotState {
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())
        if date > todayStart { return .future }
        if cal.isDateInToday(date) && entry == nil { return .todayEmpty }
        guard let entry else { return .skipped }
        if entry.score > 0 { return .rated }
        // An entry with no completed wind-down is effectively a skipped night
        // (often a ghost from older builds, or a partial flow that bailed).
        if !entry.completedNightlyFlow { return .skipped }
        // Today's completed-but-unrated routine = "Tonight" (amber ring).
        // Anything older — including yesterday — = "Awaiting rating" (half moon),
        // matching the SleepHistoryLegendView legend exactly.
        return cal.isDateInToday(date) ? .inProgress : .unratedLocked
    }
}

// MARK: - Progress Dots Card

struct ProgressDotsCard: View {
    var slots: [DotSlot]
    var sleepLogs: [SleepLogEntry]
    var onTap: (Int) -> Void
    var onTodayEmptyTap: () -> Void = {}
    var showsFrame: Bool = true
    var compact: Bool = false

    private var completedCount: Int {
        slots.filter { slot in
            switch slot.dotState {
            case .rated, .unratedLocked, .inProgress:
                return true
            case .skipped, .todayEmpty, .future:
                return false
            }
        }.count
    }

    private var pastSlotCount: Int {
        let todayStart = Calendar.current.startOfDay(for: Date())
        return slots.filter { $0.date <= todayStart }.count
    }

    private var activeDotLabel: String? {
        let cal = Calendar.current
        // Yesterday-completed-no-rating is now .unratedLocked (half moon) but
        // it's still ratable — surface the "rate now" prompt for it.
        if slots.contains(where: { $0.dotState == .unratedLocked && cal.isDateInYesterday($0.date) }) {
            return "last night · rate now"
        }
        if slots.contains(where: { $0.dotState == .inProgress && cal.isDateInToday($0.date) }) {
            return "tonight · live"
        }
        return nil
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 5) {
                ForEach(Array(slots.enumerated()), id: \.offset) { _, slot in
                    let state = slot.dotState
                    let realIdx = slot.entry.flatMap { e in sleepLogs.firstIndex(where: { $0.id == e.id }) }
                    let showsAmberGlow = state == .inProgress || (slot.isToday && state != .todayEmpty)

                    VStack(spacing: compact ? 3 : 5) {
                        dotVisual(for: slot)
                            .shadow(color: showsAmberGlow ? .lullAmberGlow : .clear, radius: 6)
                        dotLabel(for: slot)
                    }
                    .onTapGesture {
                        if let idx = realIdx {
                            onTap(idx)
                        } else if state == .todayEmpty {
                            onTodayEmptyTap()
                        }
                    }
                    .allowsHitTesting(state != .skipped && state != .future)
                }
            }
            .padding(.horizontal, compact ? 0 : 18)
            .padding(.top, compact ? 8 : 20)
            .padding(.bottom, compact ? 8 : 14)

            Divider()
                .background(Color.lullLine)
                .padding(.horizontal, compact ? 0 : 18)

            HStack {
                if let label = activeDotLabel {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(Color.lullAmber)
                            .frame(width: 6, height: 6)
                            .shadow(color: .lullAmberGlow, radius: 3)
                        Text(label)
                            .font(.mono(10.5))
                            .kerning(0.8)
                            .foregroundColor(.lullInk3)
                    }
                } else {
                    Spacer()
                }
                Spacer()
                Text("\(completedCount) / \(pastSlotCount) completed")
                    .font(.mono(10.5))
                    .kerning(0.8)
                    .foregroundColor(.lullInk3)
            }
            .padding(.horizontal, compact ? 0 : 18)
            .padding(.vertical, compact ? 8 : 14)
        }
        .background {
            if showsFrame {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white.opacity(0.025))
                    .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.lullLine, lineWidth: 1))
            }
        }
    }

    @ViewBuilder
    private func dotVisual(for slot: DotSlot) -> some View {
        let state = slot.dotState
        let showAmberRing = state == .inProgress || (slot.isToday && state != .todayEmpty)
        ZStack {
            // Fill layer
            switch state {
            case .inProgress:
                Circle()
                    .fill(Color.lullAmber.opacity(0.65))
                    .scaleEffect(0.45)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
            case .rated:
                Circle()
                    .fill(Color.lullAmber)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
            case .unratedLocked:
                Image(systemName: "circle.lefthalf.filled")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(.lullInk3)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
            case .skipped, .todayEmpty:
                Circle()
                    .fill(Color.white.opacity(0.10))
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
            case .future:
                EmptyView()
            }

            // Ring layer
            if showAmberRing {
                Circle()
                    .strokeBorder(Color.lullAmber, lineWidth: 1.5)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
            } else if state == .todayEmpty {
                Circle()
                    .strokeBorder(Color.lullInk3.opacity(0.5), lineWidth: 1.5)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
            } else if state == .future {
                Circle()
                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
            }
        }
    }

    @ViewBuilder
    private func dotLabel(for slot: DotSlot) -> some View {
        switch slot.dotState {
        case .rated:
            Text("\(slot.entry!.score)")
                .font(.mono(8))
                .foregroundColor(.lullInk3)
        case .inProgress, .unratedLocked, .todayEmpty:
            Text("·")
                .font(.mono(8))
                .foregroundColor(.lullInk3)
        case .skipped:
            Text("—")
                .font(.mono(8))
                .foregroundColor(.lullInk4)
        case .future:
            Text("–")
                .font(.mono(8))
                .foregroundColor(.lullInk4.opacity(0.4))
        }
    }
}

// MARK: - Section Header (legacy, kept for compatibility)

struct RoutineSectionHeader: View {
    var title: String
    var subtitle: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.lullInk1)
            if let subtitle {
                Text("· \(subtitle)")
                    .font(.system(size: 13, weight: .regular).italic())
                    .foregroundColor(.lullInk3)
            }
            Spacer()
        }
    }
}

// MARK: - Candidate Picker Sheet

struct CandidatePickerSheet: View {
    var candidates: [String]
    var suggestedVariable: String? = nil
    var currentVariable: String = ""
    var onSelect: (String) -> Void
    @Environment(\.dismiss) var dismiss

    private var surfacedSuggestion: String? {
        guard let s = suggestedVariable,
              !s.isEmpty,
              s != "No experiment running" else { return nil }
        return s
    }

    private var otherCandidates: [String] {
        candidates.filter { $0 != surfacedSuggestion && $0 != currentVariable }
    }

    var body: some View {
        LullScreen(glow: false) {
            VStack(spacing: 0) {
                HStack {
                    Text("PICK NEXT VARIABLE")
                        .font(.mono(10.5)).kerning(1.4).foregroundColor(.lullInk4)
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14)).foregroundColor(.lullInk3)
                            .frame(width: 44, height: 44)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24).padding(.top, 24).padding(.bottom, 20)

                Text("Choose what to test next. TenThirty will track it for 5 nights and tell you if it moves the needle.")
                    .font(.system(size: 13.5))
                    .foregroundColor(.lullInk3)
                    .lineSpacing(3)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        if let suggestion = surfacedSuggestion {
                            Text("TENTHIRTY'S PICK")
                                .font(.mono(9)).kerning(1.4)
                                .foregroundColor(.lullAmberSoft)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 22)
                                .padding(.bottom, 10)

                            Button(action: {
                                if suggestion == currentVariable {
                                    dismiss()
                                } else {
                                    onSelect(suggestion)
                                }
                            }) {
                                HStack(spacing: 14) {
                                    Ember(size: 5)
                                    Text(suggestion)
                                        .font(.system(size: 15))
                                        .foregroundColor(.lullInk0)
                                        .multilineTextAlignment(.leading)
                                    Spacer()
                                    Text("›")
                                        .font(.system(size: 20, weight: .light))
                                        .foregroundColor(.lullAmber)
                                }
                                .padding(.horizontal, 20).padding(.vertical, 18)
                                .background(RoundedRectangle(cornerRadius: 16).fill(Color.lullAmber.opacity(0.06)))
                                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.lullAmber.opacity(0.3), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 22)
                            .padding(.bottom, 24)

                            if !otherCandidates.isEmpty {
                                Text("ALL OPTIONS")
                                    .font(.mono(9)).kerning(1.4)
                                    .foregroundColor(.lullInk4)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 22)
                                    .padding(.bottom, 10)
                            }
                        }

                        VStack(spacing: 10) {
                            ForEach(otherCandidates, id: \.self) { candidate in
                                Button(action: { onSelect(candidate) }) {
                                    HStack(spacing: 14) {
                                        Ember(size: 5)
                                        Text(candidate)
                                            .font(.system(size: 15))
                                            .foregroundColor(.lullInk0)
                                            .multilineTextAlignment(.leading)
                                        Spacer()
                                        Text("›")
                                            .font(.system(size: 20, weight: .light))
                                            .foregroundColor(.lullInk3)
                                    }
                                    .padding(.horizontal, 20).padding(.vertical, 18)
                                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.025)))
                                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.lullLine, lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 22)
                    }
                }
            }
        }
    }
}
