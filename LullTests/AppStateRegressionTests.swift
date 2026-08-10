import XCTest
import DeviceActivity
import FamilyControls
@testable import TenThirty

@MainActor
final class AppStateRegressionTests: XCTestCase {
    override func setUp() {
        super.setUp()
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("lull_state.json")
        try? FileManager.default.removeItem(at: url)
        UserDefaults.standard.removeObject(forKey: "tenthirtyFirstNightReviewRequestQueued")
        UserDefaults.standard.removeObject(forKey: "tenthirtyFirstNightReviewRequestAttempted")
    }

    func testBedtimeDateForOvernightWindowBeforeWakeUsesPreviousDay() {
        let state = AppState()
        state.typicalBedtime = date(2026, 6, 28, 22, 30)
        state.typicalWakeTime = date(2026, 6, 28, 7, 0)

        let result = state.bedtimeDate(for: date(2026, 6, 28, 6, 30), calendar: calendar)

        XCTAssertEqual(result, calendar.startOfDay(for: date(2026, 6, 27, 12, 0)))
    }

    func testBedtimeDateForSameDayWindowUsesCurrentDay() {
        let state = AppState()
        state.typicalBedtime = date(2026, 6, 28, 14, 0)
        state.typicalWakeTime = date(2026, 6, 28, 16, 0)

        let result = state.bedtimeDate(for: date(2026, 6, 28, 15, 0), calendar: calendar)

        XCTAssertEqual(result, calendar.startOfDay(for: date(2026, 6, 28, 12, 0)))
    }

    func testBedtimeDateForSameDayWindowRollsForwardAfterWake() {
        let state = AppState()
        state.typicalBedtime = date(2026, 6, 28, 17, 30)
        state.typicalWakeTime = date(2026, 6, 28, 17, 40)

        let beforeBed = state.bedtimeDate(for: date(2026, 6, 28, 17, 20), calendar: calendar)
        let afterWake = state.bedtimeDate(for: date(2026, 6, 28, 17, 45), calendar: calendar)

        XCTAssertEqual(beforeBed, calendar.startOfDay(for: date(2026, 6, 28, 12, 0)))
        XCTAssertEqual(afterWake, calendar.startOfDay(for: date(2026, 6, 29, 12, 0)))
    }

    func testSameDaySleepWindowShowsNextCycleRulesAfterWake() {
        let state = AppState()
        state.typicalBedtime = localDate(2026, 6, 28, 17, 30)
        state.typicalWakeTime = localDate(2026, 6, 28, 17, 40)
        state.appBlockingEndTime = state.typicalWakeTime
        state.sleepContractActivatedAt = localDate(2026, 6, 28, 17, 20)
        state.selectedSleepRules = [.morningSun, .dimLights]
        state.sleepRuleCompletions = []
        state.sleepRuleSlips = []

        let afterWake = localDate(2026, 6, 28, 17, 45)
        let items = state.todaysContractItems(now: afterWake)
        let pending = SleepContractPresentation.visiblePendingItems(state.sleepContractSnapshot(now: afterWake))

        XCTAssertEqual(Set(items.map(\.rule)), [.morningSun, .dimLights, .inBed])
        XCTAssertFalse(items.contains(where: \.startsTomorrow))
        XCTAssertFalse(state.hasClearedContractDay(now: afterWake))
        XCTAssertFalse(pending.isEmpty)
        XCTAssertTrue(pending.contains(where: { $0.rule == .dimLights || $0.rule == .morningSun }))
    }

    func testScheduledRoutineUsesPrepLeadTimesAndFillsSleepWindow() {
        let state = AppState()
        state.typicalBedtime = date(2026, 6, 28, 22, 30)
        state.sleepWindowMinutes = 30
        state.coreRoutine = [
            step(order: 1, label: R.noScreens, mode: .reminderOnly, lead: 75, remedy: .noScreens),
            step(order: 2, label: R.brainDump, mode: .inSequence, remedy: .brainDump),
            step(order: 3, label: R.breathing478, mode: .inSequence, remedy: .breathing478),
        ]

        let rows = state.scheduledRoutine

        XCTAssertEqual(rows.map(\.step.label), [R.noScreens, R.brainDump, R.breathing478])
        XCTAssertEqual(hourMinute(rows[0].time), "21:15")
        XCTAssertEqual(hourMinute(rows[1].time), "22:00")
        XCTAssertEqual(hourMinute(rows[2].time), "22:02")
    }

    func testAppBlockingOfferStaysEligibleAfterAddingStepUntilTargetsConfigured() {
        let state = AppState()
        state.coreRoutine = [
            step(order: 1, label: R.noScreens, mode: .reminderOnly, lead: 75, remedy: .noScreens),
            step(order: 2, label: R.appBlocking, mode: .reminderOnly, lead: 75, remedy: .appBlocking),
        ]
        var completed = SleepLogEntry(date: date(2026, 6, 27, 12, 0), variable: R.noScreens, score: 0)
        completed.completedNightlyFlow = true
        state.sleepLogs = [completed]
        state.appBlockingSelection = FamilyActivitySelection()

        XCTAssertTrue(state.shouldOfferAppBlockingAfterFirstNight)
    }

    func testFirstMorningScoreQueuesNativeReviewRequestOnce() {
        let state = AppState()
        state.morningScore = 5

        state.logMorningScore()

        XCTAssertTrue(state.shouldRequestReviewAfterFirstNight)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "tenthirtyFirstNightReviewRequestQueued"))
    }

    func testLaterMorningScoresDoNotQueueNativeReviewRequestAgain() {
        let state = AppState()
        state.sleepLogs = [
            SleepLogEntry(date: date(2026, 6, 27, 12, 0), variable: R.noScreens, score: 4)
        ]
        state.morningScore = 5

        state.logMorningScore()

        XCTAssertFalse(state.shouldRequestReviewAfterFirstNight)
    }

    func testConsumedNativeReviewRequestDoesNotQueueAgain() {
        let state = AppState()
        state.morningScore = 5
        state.logMorningScore()

        state.consumeFirstNightReviewRequest()
        state.morningScore = 4
        state.logMorningScore()

        XCTAssertFalse(state.shouldRequestReviewAfterFirstNight)
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "tenthirtyFirstNightReviewRequestQueued"))
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "tenthirtyFirstNightReviewRequestAttempted"))
    }

    func testAppBlockingWindowHandlesOvernightAndSameDayRanges() {
        let state = AppState()

        state.typicalBedtime = date(2026, 6, 28, 22, 0)
        state.appBlockingStartTime = date(2026, 6, 28, 22, 0)
        state.appBlockingEndTime = date(2026, 6, 28, 7, 0)
        XCTAssertTrue(state.isWithinAppBlockingWindow(now: date(2026, 6, 28, 23, 0)))
        XCTAssertTrue(state.isWithinAppBlockingWindow(now: date(2026, 6, 28, 6, 30)))
        XCTAssertFalse(state.isWithinAppBlockingWindow(now: date(2026, 6, 28, 12, 0)))

        state.typicalBedtime = date(2026, 6, 28, 14, 0)
        state.appBlockingStartTime = date(2026, 6, 28, 14, 0)
        state.appBlockingEndTime = date(2026, 6, 28, 16, 0)
        XCTAssertTrue(state.isWithinAppBlockingWindow(now: date(2026, 6, 28, 15, 0)))
        XCTAssertFalse(state.isWithinAppBlockingWindow(now: date(2026, 6, 28, 17, 0)))
    }

    func testMorningSunUsesFixedMorningRangeAndCanCompleteDuringMorning() {
        let state = AppState()
        state.typicalWakeTime = localDate(2026, 6, 28, 7, 15)
        state.selectedSleepRules = [.morningSun]

        let sampleTime = localDate(2026, 6, 28, MorningSunWindowDefaults.startHour + 1, 30)
        let item = state.todaysContractItems(now: sampleTime).first!
        let start = Calendar.current.dateComponents([.hour, .minute], from: item.availableAt)
        let end = Calendar.current.dateComponents([.hour, .minute], from: item.dueAt)

        XCTAssertEqual(start.hour, MorningSunWindowDefaults.startHour)
        XCTAssertEqual(start.minute, MorningSunWindowDefaults.startMinute)
        XCTAssertEqual(end.hour, MorningSunWindowDefaults.endHour)
        XCTAssertEqual(end.minute, MorningSunWindowDefaults.endMinute)
        XCTAssertTrue(item.isRange)
        XCTAssertTrue(state.canCompleteSleepRule(item, now: sampleTime))
        let beforeWindow = Calendar.current.date(
            bySettingHour: MorningSunWindowDefaults.startHour,
            minute: MorningSunWindowDefaults.startMinute,
            second: 0,
            of: sampleTime
        )!.addingTimeInterval(-60)
        XCTAssertFalse(state.canCompleteSleepRule(item, now: beforeWindow))
    }

    func testMorningSunWindowCanBeConfiguredByUser() {
        let state = AppState()
        state.selectedSleepRules = [.morningSun]
        state.setSleepRuleAvailableTime(.morningSun, to: localDate(2026, 7, 24, 12, 0))
        state.setSleepRuleTime(.morningSun, to: localDate(2026, 7, 24, 20, 0))

        let sampleTime = localDate(2026, 7, 24, 18, 11)
        let item = state.todaysContractItems(now: sampleTime).first!
        let start = Calendar.current.dateComponents([.hour, .minute], from: item.availableAt)
        let end = Calendar.current.dateComponents([.hour, .minute], from: item.dueAt)

        XCTAssertEqual(start.hour, 12)
        XCTAssertEqual(end.hour, 20)
        XCTAssertTrue(state.canCompleteSleepRule(item, now: sampleTime))
        XCTAssertTrue(
            SleepContractPresentation.visiblePendingItems(state.sleepContractSnapshot(now: sampleTime))
                .contains { $0.rule == .morningSun }
        )
    }

    func testActionableMorningSunStaysVisibleWhileReadyForSleepIsForTonight() {
        let state = AppState()
        state.typicalBedtime = localDate(2026, 6, 28, 22, 0)
        state.typicalWakeTime = localDate(2026, 6, 28, 7, 0)
        state.appBlockingEndTime = state.typicalWakeTime
        state.sleepContractActivatedAt = localDate(2026, 6, 27, 22, 30)
        state.selectedSleepRules = [.morningSun, .dimLights]
        state.sleepRuleCompletions = []
        state.sleepRuleSlips = []

        let morning = localDate(2026, 6, 28, MorningSunWindowDefaults.startHour + 1, 30)
        let snapshot = state.sleepContractSnapshot(now: morning)

        XCTAssertEqual(snapshot.actionableItems.map(\.rule), [.morningSun])
        XCTAssertTrue(
            SleepContractPresentation.visiblePendingItems(snapshot).contains { $0.rule == .morningSun }
        )
        XCTAssertFalse(
            SleepContractPresentation.visiblePendingItems(snapshot).contains { $0.rule == .inBed }
        )
        XCTAssertEqual(
            SleepContractPresentation.heroItem(in: snapshot, sort: { $0.dueAt < $1.dueAt })?.rule,
            .morningSun
        )
    }

    func testMorningSunDoesNotMoveToAfternoonWakeTime() {
        let state = AppState()
        state.typicalBedtime = localDate(2026, 6, 28, 17, 30)
        state.typicalWakeTime = localDate(2026, 6, 28, 17, 40)
        state.selectedSleepRules = [.morningSun]
        state.sleepContractActivatedAt = localDate(2026, 6, 28, 17, 20)

        let item = state.todaysContractItems(now: localDate(2026, 6, 28, 17, 20)).first!
        let start = Calendar.current.dateComponents([.hour, .minute], from: item.availableAt)
        let end = Calendar.current.dateComponents([.hour, .minute], from: item.dueAt)

        XCTAssertEqual(start.hour, MorningSunWindowDefaults.startHour)
        XCTAssertEqual(start.minute, MorningSunWindowDefaults.startMinute)
        XCTAssertEqual(end.hour, MorningSunWindowDefaults.endHour)
        XCTAssertEqual(end.minute, MorningSunWindowDefaults.endMinute)
        XCTAssertTrue(item.startsTomorrow)
        XCTAssertFalse(state.sleepContractSnapshot(now: localDate(2026, 6, 28, 17, 20)).actionableItems.contains { $0.rule == .morningSun })
    }

    func testPastRuleAfterOnboardingActivationStartsTomorrow() {
        let state = AppState()
        state.typicalBedtime = localDate(2026, 6, 28, 22, 0)
        state.selectedSleepRules = [.caffeineCutoff]
        state.sleepContractActivatedAt = localDate(2026, 6, 28, 17, 0)

        let item = state.todaysContractItems(now: localDate(2026, 6, 28, 17, 1)).first!

        XCTAssertTrue(item.startsTomorrow)
        XCTAssertTrue(state.sleepContractSnapshot(now: localDate(2026, 6, 28, 17, 1)).actionableItems.isEmpty)
    }

    func testOnboardingActivationAfterMorningSunWindowDoesNotLockImmediately() {
        let state = AppState()
        state.typicalBedtime = localDate(2026, 6, 28, 22, 0)
        state.typicalWakeTime = localDate(2026, 6, 28, 7, 0)
        state.selectedSleepRules = [.morningSun, .dimLights]
        state.sleepContractActivatedAt = localDate(2026, 6, 28, 20, 40)

        let sameDayItems = state.todaysContractItems(now: localDate(2026, 6, 28, 20, 41))

        XCTAssertEqual(Set(sameDayItems.map(\.rule)), [.morningSun, .dimLights, .inBed])
        XCTAssertTrue(sameDayItems.first { $0.rule == .morningSun }?.startsTomorrow == true)
        XCTAssertTrue(sameDayItems.first { $0.rule == .dimLights }?.startsTomorrow == false)
        XCTAssertTrue(sameDayItems.first { $0.rule == .inBed }?.startsTomorrow == false)
        XCTAssertFalse(state.sleepContractSnapshot(now: localDate(2026, 6, 28, 20, 41)).actionableItems.contains { $0.rule == .morningSun })
    }

    func testSleepContractPreviewShowsOnlySelectedRules() {
        let state = AppState()
        state.typicalBedtime = localDate(2026, 6, 28, 22, 0)
        state.selectedSleepRules = [.morningSun, .dimLights, .tomorrowsPlan]

        let previewRules = state.sleepContractPreviewItems.map(\.rule)

        XCTAssertEqual(previewRules.count, 3)
        XCTAssertEqual(Set(previewRules), [.morningSun, .dimLights, .tomorrowsPlan])
        XCTAssertFalse(previewRules.contains(.caffeineCutoff))
        XCTAssertEqual(state.sleepContractPreviewItem(for: .caffeineCutoff).rule, .caffeineCutoff)
    }

    func testMultipleOverdueRulesRemainActionableAndEarliestLocks() {
        let state = AppState()
        state.typicalBedtime = localDate(2026, 6, 28, 22, 0)
        state.sleepContractActivatedAt = localDate(2026, 6, 28, 8, 0)
        state.selectedSleepRules = [.caffeineCutoff, .workoutCutoff]

        let snapshot = state.sleepContractSnapshot(now: localDate(2026, 6, 28, 20, 0))

        XCTAssertEqual(snapshot.actionableItems.map(\.rule), [.caffeineCutoff, .workoutCutoff])
        if case .lockedByRule(let item) = snapshot.lockState {
            XCTAssertEqual(item.rule, .caffeineCutoff)
        } else {
            XCTFail("Expected earliest overdue rule to lock apps")
        }
    }

    func testLateCompletionUnlocksWithoutCooldown() {
        let state = AppState()
        state.typicalBedtime = localDate(2026, 6, 28, 22, 0)
        state.sleepContractActivatedAt = localDate(2026, 6, 28, 8, 0)
        state.selectedSleepRules = [.dimLights]

        state.completeSleepRule(.dimLights, at: localDate(2026, 6, 28, 21, 0))

        if case .unlocked = state.sleepContractSnapshot(now: localDate(2026, 6, 28, 21, 5)).lockState {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected late completion to unlock without cooldown")
        }
    }

    func testSlippedRuleCreatesTenMinuteCooldownWithoutEarlySleepWindow() {
        let state = AppState()
        state.typicalBedtime = localDate(2026, 6, 28, 22, 0)
        state.typicalWakeTime = localDate(2026, 6, 28, 7, 0)
        state.appBlockingEndTime = state.typicalWakeTime
        state.sleepContractActivatedAt = localDate(2026, 6, 28, 8, 0)
        state.selectedSleepRules = [.dimLights]
        state.sleepRuleCompletions = []
        state.sleepRuleSlips = []
        state.contractAllClearEvents = []

        let slipTime = localDate(2026, 6, 28, 21, 15)
        let item = state.todaysContractItems(now: slipTime).first!
        state.recordSleepRuleSlip(item, at: slipTime)

        XCTAssertFalse(state.hasClearedContractDay(now: localDate(2026, 6, 28, 21, 16)))
        XCTAssertEqual(localHourMinute(state.effectiveSleepWindowStart(now: localDate(2026, 6, 28, 21, 16))), "22:00")

        if case .coolingDown(let item, let until) = state.sleepContractSnapshot(now: localDate(2026, 6, 28, 21, 16)).lockState {
            XCTAssertEqual(item.rule, .dimLights)
            XCTAssertEqual(until, slipTime.addingTimeInterval(10 * 60))
        } else {
            XCTFail("Expected missed habit cooldown")
        }

        if case .unlocked = state.sleepContractSnapshot(now: localDate(2026, 6, 28, 21, 26)).lockState {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected missed habit cooldown to expire after 10 minutes")
        }

        if case .unlocked = state.sleepContractSnapshot(now: localDate(2026, 6, 28, 21, 55)).lockState {
            XCTAssertTrue(state.sleepContractSnapshot(now: localDate(2026, 6, 28, 21, 55)).allItems.first?.isSlipped == true)
        } else {
            XCTFail("Expected missed habit not to start the sleep-window lock early")
        }
    }

    func testPostMidnightSleepWindowUsesPreviousContractDayItems() {
        let state = AppState()
        state.typicalBedtime = localDate(2026, 6, 28, 22, 0)
        state.typicalWakeTime = localDate(2026, 6, 28, 7, 0)
        state.appBlockingEndTime = state.typicalWakeTime
        state.sleepContractActivatedAt = localDate(2026, 6, 28, 8, 0)
        state.selectedSleepRules = [.dimLights]

        let item = state.todaysContractItems(now: localDate(2026, 6, 29, 1, 0)).first!

        XCTAssertTrue(Calendar.current.isDate(item.dueAt, inSameDayAs: localDate(2026, 6, 28, 12, 0)))
        if case .sleepWindow = state.sleepContractSnapshot(now: localDate(2026, 6, 29, 1, 0)).lockState {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected sleep window to own the post-midnight state")
        }
    }

    func testPostMidnightOnboardingSuppressesPriorEveningRules() {
        let state = AppState()
        state.typicalBedtime = localDate(2026, 6, 28, 22, 0)
        state.typicalWakeTime = localDate(2026, 6, 28, 7, 0)
        state.appBlockingEndTime = state.typicalWakeTime
        state.sleepContractActivatedAt = localDate(2026, 6, 29, 1, 0)
        state.selectedSleepRules = [.dimLights]

        let snapshot = state.sleepContractSnapshot(now: localDate(2026, 6, 29, 1, 5))

        XCTAssertEqual(snapshot.allItems.map(\.rule), [.dimLights, .inBed])
        XCTAssertEqual(snapshot.allItems.map(\.startsTomorrow), [true, false])
        XCTAssertEqual(snapshot.actionableItems.map(\.rule), [.inBed])
        XCTAssertEqual(
            SleepContractPresentation.visiblePendingItems(snapshot).map(\.rule),
            [.inBed]
        )
        if case .sleepWindow = snapshot.lockState {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected sleep window lock while exposing ready-for-sleep")
        }
    }

    func testSameDaySleepWindowShowsReadyForSleepInsteadOfWakeSideHabit() {
        let state = AppState()
        state.typicalBedtime = localDate(2026, 6, 28, 16, 0)
        state.typicalWakeTime = localDate(2026, 6, 28, 16, 40)
        state.appBlockingEndTime = state.typicalWakeTime
        state.sleepContractActivatedAt = localDate(2026, 6, 28, 15, 58)
        state.selectedSleepRules = [.morningSun]
        state.sleepRuleCompletions = []
        state.sleepRuleSlips = []

        let duringSleepWindow = localDate(2026, 6, 28, 16, 32)
        let snapshot = state.sleepContractSnapshot(now: duringSleepWindow)
        let hero = SleepContractPresentation.heroItem(in: snapshot, sort: { $0.dueAt < $1.dueAt })

        if case .sleepWindow = snapshot.lockState {
            XCTAssertEqual(snapshot.actionableItems.map(\.rule), [.inBed])
            XCTAssertEqual(
                SleepContractPresentation.visiblePendingItems(snapshot).map(\.rule),
                [.inBed]
            )
            XCTAssertFalse(state.hasClearedContractDay(now: duringSleepWindow))
            XCTAssertEqual(SleepContractPresentation.deferredCommitments(in: snapshot).map(\.rule), [.morningSun])
            XCTAssertEqual(hero?.rule, .inBed)
        } else {
            XCTFail("Expected the afternoon same-day setup to be in the sleep window")
        }

        state.completeSleepRule(.inBed, at: duringSleepWindow)

        XCTAssertTrue(state.hasClearedContractDay(now: duringSleepWindow))
        XCTAssertTrue(
            SleepContractPresentation.visiblePendingItems(state.sleepContractSnapshot(now: duringSleepWindow)).isEmpty
        )
    }

    func testReadyForSleepCanBeCompletedBeforeSleepWindowWhenVisible() {
        let state = AppState()
        state.typicalBedtime = localDate(2026, 6, 28, 17, 30)
        state.typicalWakeTime = localDate(2026, 6, 28, 17, 40)
        state.appBlockingEndTime = state.typicalWakeTime
        state.sleepContractActivatedAt = localDate(2026, 6, 28, 17, 20)
        state.selectedSleepRules = [.morningSun]
        state.sleepRuleCompletions = []
        state.sleepRuleSlips = []

        let earlySleepTime = localDate(2026, 6, 28, 17, 20)
        let inBedItem = state.todaysContractItems(now: earlySleepTime)
            .first { $0.rule == .inBed }!

        XCTAssertEqual(
            SleepContractPresentation.visiblePendingItems(state.sleepContractSnapshot(now: earlySleepTime)).map(\.rule),
            [.inBed]
        )
        XCTAssertTrue(state.canCompleteSleepRule(inBedItem, now: earlySleepTime))

        state.completeSleepRule(inBedItem, at: earlySleepTime)

        XCTAssertTrue(state.hasClearedContractDay(now: earlySleepTime))
    }

    func testSleepWindowAppliesAfterLateCompletion() {
        let state = AppState()
        state.typicalBedtime = localDate(2026, 6, 28, 22, 0)
        state.typicalWakeTime = localDate(2026, 6, 28, 7, 0)
        state.appBlockingEndTime = state.typicalWakeTime
        state.sleepContractActivatedAt = localDate(2026, 6, 28, 8, 0)
        state.selectedSleepRules = [.dimLights]

        state.completeSleepRule(.dimLights, at: localDate(2026, 6, 28, 22, 1))

        if case .sleepWindow = state.sleepContractSnapshot(now: localDate(2026, 6, 28, 22, 5)).lockState {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected sleep window lock after late completion")
        }
    }

    func testSleepWindowAppliesAfterAllCommitmentsCleared() {
        let state = AppState()
        state.typicalBedtime = localDate(2026, 6, 28, 21, 50)
        state.typicalWakeTime = localDate(2026, 6, 28, 7, 0)
        state.appBlockingEndTime = state.typicalWakeTime
        state.sleepContractActivatedAt = localDate(2026, 6, 28, 8, 0)
        state.selectedSleepRules = [.dimLights]

        state.completeSleepRule(.dimLights, at: localDate(2026, 6, 28, 21, 30))
        state.completeSleepRule(.inBed, at: localDate(2026, 6, 28, 21, 50))

        XCTAssertTrue(state.hasClearedContractDay(now: localDate(2026, 6, 28, 22, 30)))
        if case .sleepWindow = state.sleepContractSnapshot(now: localDate(2026, 6, 28, 22, 30)).lockState {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected sleep window to lock even after all commitments are cleared")
        }
    }

    func testContractFireflyRequiresInBedConfirmationAfterRulesAreCleared() {
        let state = AppState()
        state.typicalBedtime = localDate(2026, 6, 28, 22, 0)
        state.typicalWakeTime = localDate(2026, 6, 28, 7, 0)
        state.appBlockingEndTime = state.typicalWakeTime
        state.sleepContractActivatedAt = localDate(2026, 6, 28, 8, 0)
        state.selectedSleepRules = [.dimLights]
        state.sleepRuleCompletions = []
        state.sleepRuleSlips = []
        state.contractAllClearEvents = []

        state.completeSleepRule(.dimLights, at: localDate(2026, 6, 28, 21, 30))
        let inBedItem = state.todaysContractItems(now: localDate(2026, 6, 28, 21, 31))
            .first { $0.rule == .inBed }!

        XCTAssertEqual(
            state.todaysContractItems(now: localDate(2026, 6, 28, 21, 31)).map(\.rule),
            [.dimLights, .inBed]
        )
        XCTAssertTrue(state.canCompleteSleepRule(inBedItem, now: localDate(2026, 6, 28, 21, 31)))
        XCTAssertFalse(state.hasClearedContractDay(now: localDate(2026, 6, 28, 21, 31)))

        state.completeSleepRule(.inBed, at: localDate(2026, 6, 28, 21, 31))

        XCTAssertTrue(state.hasClearedContractDay(now: localDate(2026, 6, 28, 21, 31)))
    }

    func testReadyForSleepRemainsActionableDuringSleepWindowAfterRulesAreCleared() {
        let state = AppState()
        state.typicalBedtime = localDate(2026, 6, 28, 22, 0)
        state.typicalWakeTime = localDate(2026, 6, 28, 7, 0)
        state.appBlockingEndTime = state.typicalWakeTime
        state.sleepContractActivatedAt = localDate(2026, 6, 28, 8, 0)
        state.selectedSleepRules = [.dimLights]
        state.sleepRuleCompletions = []
        state.sleepRuleSlips = []

        state.completeSleepRule(.dimLights, at: localDate(2026, 6, 28, 21, 30))
        let snapshot = state.sleepContractSnapshot(now: localDate(2026, 6, 28, 23, 0))

        XCTAssertEqual(snapshot.actionableItems.map(\.rule), [.inBed])
        XCTAssertTrue(state.canCompleteSleepRule(snapshot.actionableItems[0], now: localDate(2026, 6, 28, 23, 0)))
    }

    func testReadyForSleepIsHiddenUntilEarlierHabitsAreCleared() {
        let state = AppState()
        state.typicalBedtime = localDate(2026, 6, 28, 22, 0)
        state.typicalWakeTime = localDate(2026, 6, 28, 7, 0)
        state.appBlockingEndTime = state.typicalWakeTime
        state.sleepContractActivatedAt = localDate(2026, 6, 28, 8, 0)
        state.selectedSleepRules = [.warmShower]
        state.sleepRuleCompletions = []
        state.sleepRuleSlips = []

        let missedHabitSnapshot = state.sleepContractSnapshot(now: localDate(2026, 6, 28, 23, 0))

        XCTAssertEqual(missedHabitSnapshot.allItems.map(\.rule), [.warmShower, .inBed])
        XCTAssertEqual(
            SleepContractPresentation.visiblePendingItems(missedHabitSnapshot).map(\.rule),
            [.warmShower]
        )
        XCTAssertEqual(
            SleepContractPresentation.heroItem(in: missedHabitSnapshot, sort: { $0.dueAt < $1.dueAt })?.rule,
            .warmShower
        )

        state.completeSleepRule(.warmShower, at: localDate(2026, 6, 28, 23, 1))
        let readyForSleepSnapshot = state.sleepContractSnapshot(now: localDate(2026, 6, 28, 23, 2))

        XCTAssertEqual(
            SleepContractPresentation.visiblePendingItems(readyForSleepSnapshot).map(\.rule),
            [.inBed]
        )
    }

    func testInBedCheckpointDoesNotScheduleRuleLockNotifications() {
        let state = AppState()
        state.typicalBedtime = localDate(2026, 6, 28, 22, 0)
        state.sleepContractActivatedAt = localDate(2026, 6, 28, 8, 0)
        state.selectedSleepRules = [.dimLights]
        state.sleepRuleCompletions = []
        state.sleepRuleSlips = []

        state.completeSleepRule(.dimLights, at: localDate(2026, 6, 28, 21, 30))

        let notificationRules = state.sleepContractNotificationItems(now: localDate(2026, 6, 28, 21, 31))
            .map(\.item.rule)

        XCTAssertFalse(notificationRules.contains(.inBed))
    }

    func testMorningAfterMissedPriorNightStartsFreshContractDay() {
        let state = AppState()
        state.typicalBedtime = localDate(2026, 6, 28, 22, 0)
        state.typicalWakeTime = localDate(2026, 6, 28, 7, 0)
        state.appBlockingEndTime = state.typicalWakeTime
        state.sleepContractActivatedAt = localDate(2026, 6, 28, 8, 0)
        state.selectedSleepRules = [.dimLights]
        state.sleepRuleCompletions = []
        state.sleepRuleSlips = []

        let morningAfter = localDate(2026, 6, 29, 9, 0)
        let snapshot = state.sleepContractSnapshot(now: morningAfter)

        XCTAssertEqual(snapshot.allItems.count, 2)
        XCTAssertTrue(snapshot.allItems.allSatisfy { Calendar.current.isDate($0.dueAt, inSameDayAs: morningAfter) })
        XCTAssertTrue(snapshot.actionableItems.isEmpty)
        if case .unlocked = snapshot.lockState {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected the morning after a missed prior-night rule to render the new day, not stale overnight lock UI")
        }
    }

    func testCooldownSnapshotUsesExactNowAndTenMinuteDeadline() {
        let state = AppState()
        state.typicalBedtime = localDate(2026, 6, 28, 22, 0)
        state.sleepContractActivatedAt = localDate(2026, 6, 28, 8, 0)
        state.selectedSleepRules = [.dimLights]

        let missedAt = localDate(2026, 6, 28, 21, 0)
        let displayTick = localDate(2026, 6, 28, 21, 4)
        let displayTickWithSeconds = Calendar.current.date(byAdding: .second, value: 32, to: displayTick)!
        let item = state.todaysContractItems(now: missedAt).first { $0.rule == .dimLights }!
        state.recordSleepRuleSlip(item, at: missedAt)

        let snapshot = state.sleepContractSnapshot(now: displayTickWithSeconds)

        XCTAssertEqual(snapshot.now, displayTickWithSeconds)
        if case .coolingDown(let item, let until) = snapshot.lockState {
            XCTAssertEqual(item.rule, .dimLights)
            XCTAssertEqual(until, missedAt.addingTimeInterval(10 * 60))
            XCTAssertEqual(Int(until.timeIntervalSince(displayTickWithSeconds)), 328)
        } else {
            XCTFail("Expected missed habit to expose a precise cooldown window")
        }
    }

    func testOverdueRulesRemainActionableDuringSleepWindow() {
        let state = AppState()
        state.typicalBedtime = localDate(2026, 6, 28, 22, 0)
        state.typicalWakeTime = localDate(2026, 6, 28, 7, 0)
        state.appBlockingEndTime = state.typicalWakeTime
        state.sleepContractActivatedAt = localDate(2026, 6, 28, 8, 0)
        state.selectedSleepRules = [.dimLights]
        state.sleepRuleCompletions = []
        state.sleepRuleConfigurations = [:]

        let snapshot = state.sleepContractSnapshot(now: localDate(2026, 6, 28, 22, 5))

        if case .sleepWindow = snapshot.lockState {
            XCTAssertEqual(snapshot.actionableItems.map(\.rule), [.dimLights])
            XCTAssertTrue(state.canCompleteSleepRule(snapshot.actionableItems[0], now: localDate(2026, 6, 28, 22, 5)))
            let inBedItem = snapshot.allItems.first { $0.rule == .inBed }
            XCTAssertNotNil(inBedItem)
            XCTAssertFalse(state.canCompleteSleepRule(inBedItem!, now: localDate(2026, 6, 28, 22, 5)))
        } else {
            XCTFail("Expected sleep window to own enforcement while overdue rules stay actionable")
        }
    }

    func testSleepWindowLockEventsUseContractDayAcrossMidnight() {
        let state = AppState()
        state.typicalBedtime = localDate(2026, 6, 28, 22, 0)
        state.typicalWakeTime = localDate(2026, 6, 28, 7, 0)

        let beforeMidnight = ContractLockEvent(kind: .sleepWindow, rule: nil, occurredAt: localDate(2026, 6, 28, 23, 30))
        let afterMidnight = ContractLockEvent(kind: .sleepWindow, rule: nil, occurredAt: localDate(2026, 6, 29, 1, 30))
        let ruleAfterMidnight = ContractLockEvent(kind: .rule, rule: .dimLights, occurredAt: localDate(2026, 6, 29, 1, 30))

        XCTAssertTrue(state.lockEvent(beforeMidnight, matchesContractDayOf: afterMidnight.occurredAt))
        XCTAssertTrue(Calendar.current.isDate(
            state.contractDay(forLockEvent: beforeMidnight),
            inSameDayAs: state.contractDay(forLockEvent: afterMidnight)
        ))
        XCTAssertFalse(state.lockEvent(ruleAfterMidnight, matchesContractDayOf: beforeMidnight.occurredAt))
    }

    func testSetupTimeLocksDoNotSeedTrendLockActivations() {
        let state = AppState()
        state.hasCompletedOnboarding = false
        state.sleepContractActivatedAt = nil
        state.typicalBedtime = localDate(2026, 6, 28, 22, 0)
        state.selectedSleepRules = [.dimLights]
        state.sleepRuleCompletions = []
        state.sleepRuleSlips = []

        let lockedDuringSetup = state.sleepContractSnapshot(now: localDate(2026, 6, 28, 21, 30))

        if case .lockedByRule = lockedDuringSetup.lockState {
            XCTAssertFalse(state.shouldRecordContractLockActivation(snapshot: lockedDuringSetup, now: lockedDuringSetup.now))
        } else {
            XCTFail("Expected a setup-time rule lock snapshot")
        }

        state.hasCompletedOnboarding = true
        state.sleepContractActivatedAt = localDate(2026, 6, 28, 8, 0)

        XCTAssertTrue(state.shouldRecordContractLockActivation(snapshot: lockedDuringSetup, now: lockedDuringSetup.now))
    }

    func testContractAllClearDoesNotMarkOldRoutineComplete() {
        let state = AppState()
        state.typicalBedtime = localDate(2026, 6, 28, 22, 0)
        state.sleepContractActivatedAt = localDate(2026, 6, 28, 8, 0)
        state.selectedSleepRules = [.dimLights]
        state.sleepRuleCompletions = []
        state.contractAllClearEvents = []

        state.completeSleepRule(.dimLights, at: localDate(2026, 6, 28, 20, 50))
        state.completeSleepRule(.inBed, at: localDate(2026, 6, 28, 22, 0))
        let firstRecord = state.recordContractAllClearIfNeeded(now: localDate(2026, 6, 28, 22, 1))
        let duplicateRecord = state.recordContractAllClearIfNeeded(now: localDate(2026, 6, 28, 22, 2))

        XCTAssertNotNil(firstRecord)
        XCTAssertNil(duplicateRecord)
        XCTAssertEqual(state.contractAllClearEvents.count, 1)
        XCTAssertFalse(state.sleepLogs.contains(where: \.completedNightlyFlow))
    }

    func testCompletedSleepRuleIsNotEligibleForLockNotifications() {
        let state = AppState()
        state.typicalBedtime = localDate(2026, 6, 28, 22, 0)
        state.sleepContractActivatedAt = localDate(2026, 6, 28, 8, 0)
        state.selectedSleepRules = [.dimLights, .tomorrowsPlan]

        state.completeSleepRule(.dimLights, at: localDate(2026, 6, 28, 20, 50))

        let notificationRules = state.sleepContractNotificationItems(now: localDate(2026, 6, 28, 20, 51))
            .filter { $0.dayOffset == 0 }
            .map(\.item.rule)

        XCTAssertFalse(notificationRules.contains(.dimLights))
        XCTAssertTrue(notificationRules.contains(.tomorrowsPlan))
    }

    func testSlippedSleepRuleIsNotEligibleForLockNotifications() {
        let state = AppState()
        state.typicalBedtime = localDate(2026, 6, 28, 22, 0)
        state.sleepContractActivatedAt = localDate(2026, 6, 28, 8, 0)
        state.selectedSleepRules = [.dimLights, .tomorrowsPlan]

        let item = state.todaysContractItems(now: localDate(2026, 6, 28, 20, 50))
            .first { $0.rule == .dimLights }!
        state.recordSleepRuleSlip(item, at: localDate(2026, 6, 28, 20, 50))

        let notificationRules = state.sleepContractNotificationItems(now: localDate(2026, 6, 28, 20, 51))
            .filter { $0.dayOffset == 0 }
            .map(\.item.rule)

        XCTAssertFalse(notificationRules.contains(.dimLights))
        XCTAssertTrue(notificationRules.contains(.tomorrowsPlan))
    }

    func testSleepWindowEditKeepsAppBlockingWindowInSync() {
        let state = AppState()
        state.typicalBedtime = localDate(2026, 6, 28, 21, 30)
        state.typicalWakeTime = localDate(2026, 6, 28, 6, 45)

        state.sleepWindowWasEdited()

        XCTAssertEqual(localHourMinute(state.appBlockingStartTime), "21:30")
        XCTAssertEqual(localHourMinute(state.appBlockingEndTime), "06:45")
    }

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        var comps = DateComponents()
        comps.calendar = calendar
        comps.timeZone = calendar.timeZone
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = hour
        comps.minute = minute
        return comps.date!
    }

    private func localDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        var comps = DateComponents()
        comps.calendar = Calendar.current
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = hour
        comps.minute = minute
        return comps.date!
    }

    private func hourMinute(_ date: Date) -> String {
        let comps = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", comps.hour ?? 0, comps.minute ?? 0)
    }

    private func localHourMinute(_ date: Date) -> String {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", comps.hour ?? 0, comps.minute ?? 0)
    }

    func testMorningSunVisibleThroughoutConfiguredWindow() {
        let state = AppState()
        state.typicalBedtime = localDate(2026, 7, 24, 21, 0)
        state.typicalWakeTime = localDate(2026, 7, 24, 7, 0)
        state.appBlockingEndTime = state.typicalWakeTime
        state.appBlockingStartTime = state.typicalBedtime
        state.sleepContractActivatedAt = localDate(2026, 7, 23, 21, 0)
        state.selectedSleepRules = [.morningSun, .caffeineCutoff, .warmShower]
        state.setSleepRuleTime(.caffeineCutoff, to: localDate(2026, 7, 24, 15, 0))
        state.setSleepRuleTime(.warmShower, to: localDate(2026, 7, 24, 19, 30))
        state.sleepRuleCompletions = []
        state.sleepRuleSlips = []

        for moment in [
            localDate(2026, 7, 24, MorningSunWindowDefaults.startHour + 1, 0),
            localDate(2026, 7, 24, MorningSunWindowDefaults.startHour + 4, 0),
            localDate(2026, 7, 24, MorningSunWindowDefaults.endHour - 1, 0),
        ] {
            let snapshot = state.sleepContractSnapshot(now: moment)
            let visible = SleepContractPresentation.visiblePendingItems(snapshot).map(\.rule)
            XCTAssertTrue(snapshot.actionableItems.contains { $0.rule == .morningSun })
            XCTAssertTrue(visible.contains(.morningSun))
            XCTAssertEqual(
                SleepContractPresentation.heroItem(in: snapshot, sort: { $0.availableAt < $1.availableAt })?.rule,
                .morningSun
            )
        }
    }

    func testExpiredMorningSunStaysVisibleAndOwnsHeroWhenItIsLocking() {
        let state = AppState()
        state.typicalBedtime = localDate(2026, 7, 24, 21, 0)
        state.typicalWakeTime = localDate(2026, 7, 24, 7, 0)
        state.appBlockingEndTime = state.typicalWakeTime
        state.appBlockingStartTime = state.typicalBedtime
        state.sleepContractActivatedAt = localDate(2026, 7, 23, 21, 0)
        state.selectedSleepRules = [.morningSun, .caffeineCutoff, .warmShower]
        state.setSleepRuleTime(.caffeineCutoff, to: localDate(2026, 7, 24, 15, 0))
        state.setSleepRuleTime(.warmShower, to: localDate(2026, 7, 24, 19, 30))
        state.sleepRuleCompletions = []
        state.sleepRuleSlips = [
            SleepRuleSlip(
                rule: .caffeineCutoff,
                dueAt: localDate(2026, 7, 24, 15, 0),
                slippedAt: localDate(2026, 7, 24, 15, 20)
            )
        ]

        let afternoon = localDate(2026, 7, 24, 16, 17)
        let snapshot = state.sleepContractSnapshot(now: afternoon)
        let visible = SleepContractPresentation.visiblePendingItems(snapshot).map(\.rule)
        let hero = SleepContractPresentation.heroItem(in: snapshot, sort: { lhs, rhs in
            if lhs.graceEndsAt != rhs.graceEndsAt { return lhs.graceEndsAt < rhs.graceEndsAt }
            return lhs.availableAt < rhs.availableAt
        })

        if case .lockedByRule(let item) = snapshot.lockState {
            XCTAssertEqual(item.rule, .morningSun)
        } else {
            XCTFail("Expected overdue Morning Sun to own the lock")
        }
        XCTAssertTrue(visible.contains(.morningSun))
        XCTAssertEqual(hero?.rule, .morningSun)
    }

    func testSleepWindowDoesNotShowMorningSunBeforeItIsAvailable() {
        let state = AppState()
        state.typicalBedtime = localDate(2026, 7, 24, 21, 0)
        state.typicalWakeTime = localDate(2026, 7, 24, 7, 0)
        state.appBlockingEndTime = state.typicalWakeTime
        state.appBlockingStartTime = state.typicalBedtime
        state.sleepContractActivatedAt = localDate(2026, 7, 23, 21, 0)
        state.selectedSleepRules = [.morningSun, .caffeineCutoff, .warmShower]
        state.setSleepRuleTime(.caffeineCutoff, to: localDate(2026, 7, 24, 15, 0))
        state.setSleepRuleTime(.warmShower, to: localDate(2026, 7, 24, 19, 30))
        state.sleepRuleCompletions = []
        state.sleepRuleSlips = []

        let preWakeMorning = localDate(2026, 7, 24, 4, 17)
        let snapshot = state.sleepContractSnapshot(now: preWakeMorning)
        let visible = SleepContractPresentation.visiblePendingItems(snapshot).map(\.rule)
        let morningSun = snapshot.allItems.first { $0.rule == .morningSun }

        XCTAssertTrue(snapshot.isSleepWindow)
        XCTAssertNotNil(morningSun)
        XCTAssertTrue(Calendar.current.isDate(morningSun!.availableAt, inSameDayAs: preWakeMorning))
        XCTAssertFalse(visible.contains(.morningSun))
        XCTAssertEqual(
            SleepContractPresentation.heroItem(in: snapshot, sort: sleepRuleDisplaySort)?.rule,
            .inBed
        )
    }

    private func sleepRuleDisplaySort(_ lhs: SleepContractItem, _ rhs: SleepContractItem) -> Bool {
        if lhs.rule == .inBed, rhs.rule != .inBed { return false }
        if lhs.rule != .inBed, rhs.rule == .inBed { return true }
        if lhs.graceEndsAt != rhs.graceEndsAt { return lhs.graceEndsAt < rhs.graceEndsAt }
        if lhs.dueAt != rhs.dueAt { return lhs.dueAt < rhs.dueAt }
        return lhs.rule.rawValue < rhs.rule.rawValue
    }

    func testShortSameDayWindowShowsActionableMorningSunOnFollowingMornings() {
        let state = AppState()
        state.typicalBedtime = localDate(2026, 6, 28, 17, 20)
        state.typicalWakeTime = localDate(2026, 6, 28, 17, 30)
        state.appBlockingEndTime = state.typicalWakeTime
        state.appBlockingStartTime = state.typicalBedtime
        state.sleepContractActivatedAt = localDate(2026, 6, 28, 18, 0)
        state.selectedSleepRules = [.morningSun]
        state.sleepRuleCompletions = []
        state.sleepRuleSlips = []

        let firstMorning = localDate(2026, 6, 29, 9, 0)
        let secondMorning = localDate(2026, 6, 30, 9, 0)

        for moment in [firstMorning, secondMorning] {
            let snapshot = state.sleepContractSnapshot(now: moment)
            let visible = SleepContractPresentation.visiblePendingItems(snapshot).map(\.rule)
            XCTAssertTrue(visible.contains(.morningSun))
            XCTAssertTrue(visible.contains(.inBed))
            XCTAssertEqual(
                SleepContractPresentation.heroItem(in: snapshot, sort: sleepRuleDisplaySort)?.rule,
                .morningSun
            )
        }
    }

    func testLockedMorningSunStaysVisibleWhenReadyForSleepIsAlsoVisible() {
        let state = AppState()
        state.typicalBedtime = localDate(2026, 6, 28, 17, 20)
        state.typicalWakeTime = localDate(2026, 6, 28, 17, 30)
        state.appBlockingEndTime = state.typicalWakeTime
        state.appBlockingStartTime = state.typicalBedtime
        state.sleepContractActivatedAt = localDate(2026, 6, 27, 18, 0)
        state.selectedSleepRules = [.morningSun]
        state.sleepRuleCompletions = []
        state.sleepRuleSlips = []

        let lockedEvening = localDate(2026, 6, 28, 17, 15)
        let snapshot = state.sleepContractSnapshot(now: lockedEvening)

        if case .lockedByRule(let item) = snapshot.lockState {
            XCTAssertEqual(item.rule, .morningSun)
        } else {
            XCTFail("Expected morning sun lock at \(lockedEvening), got \(snapshot.lockState)")
        }

        let visible = SleepContractPresentation.visiblePendingItems(snapshot).map(\.rule)
        XCTAssertTrue(visible.contains(.morningSun))
        XCTAssertTrue(visible.contains(.inBed))
        XCTAssertEqual(
            SleepContractPresentation.heroItem(in: snapshot, sort: sleepRuleDisplaySort)?.rule,
            .morningSun
        )
    }

    func testLockedMorningSunCannotBeDisplacedByLaterCutoffCards() {
        let state = AppState()
        state.typicalBedtime = localDate(2026, 8, 10, 23, 30)
        state.typicalWakeTime = localDate(2026, 8, 10, 7, 0)
        state.appBlockingStartTime = state.typicalBedtime
        state.appBlockingEndTime = state.typicalWakeTime
        state.sleepContractActivatedAt = localDate(2026, 8, 9, 20, 0)
        state.selectedSleepRules = [.morningSun, .caffeineCutoff, .workoutCutoff]
        state.setSleepRuleTime(.caffeineCutoff, to: localDate(2026, 8, 10, 17, 30))
        state.setSleepRuleTime(.workoutCutoff, to: localDate(2026, 8, 10, 21, 23))
        state.sleepRuleCompletions = []
        state.sleepRuleSlips = []

        let screenshotTime = localDate(2026, 8, 10, 12, 41)
        let snapshot = state.sleepContractSnapshot(now: screenshotTime)
        let visible = SleepContractPresentation.visiblePendingItems(snapshot)
        let hero = SleepContractPresentation.heroItem(in: snapshot, sort: sleepRuleDisplaySort)

        if case .lockedByRule(let item) = snapshot.lockState {
            XCTAssertEqual(item.rule, .morningSun)
        } else {
            XCTFail("Expected Morning Sun to own the lock at the reported failure time")
        }
        XCTAssertTrue(visible.contains { $0.rule == .morningSun })
        XCTAssertEqual(hero?.rule, .morningSun)
        XCTAssertTrue(state.canCompleteSleepRule(hero!, now: screenshotTime))
    }

    func testMovingCaffeineCutoffToCurrentMinutePreservesFullGracePeriod() throws {
        let state = AppState()
        state.typicalBedtime = localDate(2026, 8, 10, 23, 30)
        state.typicalWakeTime = localDate(2026, 8, 10, 7, 0)
        state.appBlockingStartTime = state.typicalBedtime
        state.appBlockingEndTime = state.typicalWakeTime
        state.sleepContractActivatedAt = localDate(2026, 8, 9, 20, 0)
        state.selectedSleepRules = [.caffeineCutoff]
        state.sleepRuleCompletions = []
        state.sleepRuleSlips = []
        state.setSleepRuleGraceMinutes(.caffeineCutoff, to: 15)

        let editedDueTime = localDate(2026, 8, 10, 14, 11)
        state.setSleepRuleTime(.caffeineCutoff, to: editedDueTime)

        let duringGrace = localDate(2026, 8, 10, 14, 11)
        let beforeGraceEnd = localDate(2026, 8, 10, 14, 25)
        let graceEnd = localDate(2026, 8, 10, 14, 26)
        let item = try XCTUnwrap(
            state.sleepContractSnapshot(now: duringGrace).allItems.first { $0.rule == .caffeineCutoff }
        )
        let ruleWindow = try XCTUnwrap(
            state.appBlockingMonitorWindows(now: duringGrace).first {
                $0.reason == .rule && $0.ruleTitle == SleepRuleKind.caffeineCutoff.title
            }
        )

        XCTAssertEqual(item.dueAt, editedDueTime)
        XCTAssertEqual(item.graceEndsAt, graceEnd)
        XCTAssertEqual(ruleWindow.start, graceEnd)
        XCTAssertFalse(AppBlockingMonitorStore.isActive(ruleWindow, now: duringGrace))
        XCTAssertFalse(state.sleepContractSnapshot(now: duringGrace).isLocked)
        XCTAssertFalse(state.sleepContractSnapshot(now: beforeGraceEnd).isLocked)
        if case .lockedByRule(let lockingItem) = state.sleepContractSnapshot(now: graceEnd).lockState {
            XCTAssertEqual(lockingItem.rule, .caffeineCutoff)
        } else {
            XCTFail("Caffeine cutoff should lock exactly when its 15-minute grace ends")
        }
    }

    func testCommittingAfternoonRuleTimePreservesPMAndDoesNotLockFromIntermediateAM() throws {
        let state = AppState()
        state.typicalBedtime = localDate(2026, 8, 10, 23, 30)
        state.typicalWakeTime = localDate(2026, 8, 10, 7, 0)
        state.appBlockingEndTime = state.typicalWakeTime
        state.sleepContractActivatedAt = localDate(2026, 8, 9, 20, 0)
        state.selectedSleepRules = [.caffeineCutoff]
        state.sleepRuleCompletions = []
        state.sleepRuleSlips = []
        state.setSleepRuleGraceMinutes(.caffeineCutoff, to: 15)

        let now = localDate(2026, 8, 10, 14, 45)
        let confirmedPMTime = localDate(2026, 8, 10, 14, 46)
        state.setSleepRuleTime(.caffeineCutoff, to: confirmedPMTime)

        let savedTime = try XCTUnwrap(state.sleepRuleConfigurations[.caffeineCutoff]?.dueTime)
        let item = try XCTUnwrap(
            state.sleepContractSnapshot(now: now).allItems.first { $0.rule == .caffeineCutoff }
        )
        let components = Calendar.current.dateComponents([.hour, .minute], from: savedTime)

        XCTAssertEqual(components.hour, 14)
        XCTAssertEqual(components.minute, 46)
        XCTAssertEqual(item.dueAt, confirmedPMTime)
        XCTAssertEqual(item.graceEndsAt, localDate(2026, 8, 10, 15, 1))
        XCTAssertFalse(state.sleepContractSnapshot(now: now).isLocked)
    }

    func testEditingRuleTimeReplacesDeviceActivityIdentityDuringNewGracePeriod() throws {
        let state = AppState()
        state.typicalBedtime = localDate(2026, 8, 10, 23, 30)
        state.typicalWakeTime = localDate(2026, 8, 10, 7, 0)
        state.appBlockingEndTime = state.typicalWakeTime
        state.sleepContractActivatedAt = localDate(2026, 8, 9, 20, 0)
        state.selectedSleepRules = [.caffeineCutoff]
        state.sleepRuleCompletions = []
        state.sleepRuleSlips = []
        state.setSleepRuleGraceMinutes(.caffeineCutoff, to: 15)

        state.setSleepRuleTime(.caffeineCutoff, to: localDate(2026, 8, 10, 17, 30))
        let oldWindow = try XCTUnwrap(
            state.appBlockingMonitorWindows(now: localDate(2026, 8, 10, 14, 11)).first {
                $0.reason == .rule && $0.ruleTitle == SleepRuleKind.caffeineCutoff.title
            }
        )

        state.setSleepRuleTime(.caffeineCutoff, to: localDate(2026, 8, 10, 14, 11))
        let editedAt = localDate(2026, 8, 10, 14, 11)
        let newWindow = try XCTUnwrap(
            state.appBlockingMonitorWindows(now: editedAt).first {
                $0.reason == .rule && $0.ruleTitle == SleepRuleKind.caffeineCutoff.title
            }
        )

        XCTAssertNotEqual(oldWindow.id, newWindow.id)
        XCTAssertEqual(newWindow.start, localDate(2026, 8, 10, 14, 26))
        XCTAssertFalse(AppBlockingMonitorStore.isActive(newWindow, now: editedAt))
        XCTAssertFalse(state.sleepContractSnapshot(now: editedAt).isLocked)
    }

    func testHoldConfirmUITestFixtureShowsActionableHero() {
        let state = AppState()
        state.applyUITestLaunchArgumentsIfNeeded([
            "--uitest-completed-onboarding",
            "--uitest-hold-confirm-fixture",
        ])

        let snapshot = state.sleepContractSnapshot(now: Date())
        let visible = SleepContractPresentation.visiblePendingItems(snapshot).map(\.rule)
        let hero = SleepContractPresentation.heroItem(in: snapshot, sort: { $0.availableAt < $1.availableAt })

        XCTAssertTrue(visible.contains(.dimLights), "visible=\(visible)")
        XCTAssertEqual(hero?.rule, .dimLights)
        XCTAssertTrue(state.canCompleteSleepRule(hero!, now: snapshot.now))

        state.completeSleepRule(hero!, at: snapshot.now)
        let after = state.sleepContractSnapshot(now: Date())
        let completed = after.allItems.first { $0.rule == .dimLights }
        XCTAssertTrue(completed?.isCompleted == true, "Expected dim lights completed after confirm")
    }

    func testSubscriptionLapseClearsPremiumAccessAndAppBlocking() {
        let state = AppState()
        state.hasCompletedOnboarding = true
        state.paywallState.tier = .subscribed
        state.appBlockingEnabled = true
        state.appBlockingSelection = FamilyActivitySelection()

        state.applyRevenueCatEntitlement(isActive: false)

        XCTAssertEqual(state.paywallState.tier, .free)
        XCTAssertFalse(state.hasPremiumAccess)
        XCTAssertFalse(state.canUseHardAppBlocking)
        state.handleSubscriptionLapsed()
    }

    func testDebugSimulateCancelledTrialExpiredDowngradesAccess() {
        let state = AppState()
        state.hasCompletedOnboarding = true
        state.paywallState.tier = .subscribed

        state.debugSimulateCancelledTrialExpired()

        XCTAssertEqual(state.paywallState.tier, .free)
        XCTAssertFalse(state.hasPremiumAccess)
        XCTAssertNotNil(state.paywallState.trialExpiredAt)
    }

    func testCompletingOnboardingStartsContractAppWithoutLegacyNightlyFlow() {
        let state = AppState()
        state.hasCompletedOnboarding = false
        state.showNightlyFlow = true
        state.selectedSleepRules = [.dimLights, .inBed]
        state.sleepContractActivatedAt = nil

        state.completeOnboardingAndStartRitual()

        XCTAssertTrue(state.hasCompletedOnboarding)
        XCTAssertFalse(state.showNightlyFlow)
        XCTAssertEqual(state.requestedTab, 0)
        XCTAssertEqual(state.selectedSleepRules, [.dimLights, .inBed])
        XCTAssertNotNil(state.sleepContractActivatedAt)
    }

    func testEmergencyAccessIsActiveOnlyUntilSelectedDurationEnds() {
        let state = AppState()
        let startedAt = localDate(2026, 7, 24, 22, 0)

        state.startEmergencyAppAccess(reason: .family, duration: .fifteen, now: startedAt)

        let expectedEnd = startedAt.addingTimeInterval(15 * 60)
        XCTAssertEqual(state.activeEmergencyAppAccessEnd(now: startedAt), expectedEnd)
        XCTAssertEqual(state.activeEmergencyAppAccessEnd(now: expectedEnd.addingTimeInterval(-1)), expectedEnd)
        XCTAssertNil(state.activeEmergencyAppAccessEnd(now: expectedEnd))
        XCTAssertNil(state.activeEmergencyAppAccessEnd(now: expectedEnd.addingTimeInterval(1)))
    }

    func testDailyBlockingWindowRemainsActiveAfterAppHasBeenClosedForDays() {
        let window = AppBlockingMonitorWindow(
            id: "sleep",
            start: localDate(2026, 7, 24, 22, 30),
            end: localDate(2026, 7, 25, 7, 0),
            reason: .sleepWindow,
            ruleTitle: nil,
            wakeTimeText: "7:00 AM",
            recurrence: .daily
        )

        XCTAssertTrue(AppBlockingMonitorStore.isActive(
            window,
            now: localDate(2026, 8, 3, 23, 0)
        ))
        XCTAssertTrue(AppBlockingMonitorStore.isActive(
            window,
            now: localDate(2026, 8, 4, 6, 59)
        ))
        XCTAssertFalse(AppBlockingMonitorStore.isActive(
            window,
            now: localDate(2026, 8, 4, 7, 0)
        ))
    }

    func testDailyBlockingWindowDoesNotActivateBeforeItsEffectiveStart() {
        let window = AppBlockingMonitorWindow(
            id: "rule.dimLights",
            start: localDate(2026, 7, 25, 20, 0),
            end: localDate(2026, 7, 26, 7, 0),
            reason: .rule,
            ruleTitle: SleepRuleKind.dimLights.title,
            wakeTimeText: "7:00 AM",
            recurrence: .daily
        )

        XCTAssertFalse(AppBlockingMonitorStore.isActive(
            window,
            now: localDate(2026, 7, 24, 21, 0)
        ))
        XCTAssertTrue(AppBlockingMonitorStore.isActive(
            window,
            now: localDate(2026, 7, 25, 20, 0)
        ))
    }

    func testReconcileWindowNeverActsAsASecondShieldWindow() {
        let start = localDate(2026, 7, 25, 22, 0)
        let window = AppBlockingMonitorWindow(
            id: "reconcile.emergency",
            start: start,
            end: start.addingTimeInterval(60),
            reason: .reconcile,
            ruleTitle: nil,
            wakeTimeText: "7:00 AM"
        )

        XCTAssertFalse(AppBlockingMonitorStore.isActive(window, now: start.addingTimeInterval(30)))
    }

    func testLegacyMonitorWindowWithoutRecurrenceDecodesAsOneTime() throws {
        let window = AppBlockingMonitorWindow(
            id: "legacy",
            start: localDate(2026, 7, 25, 22, 0),
            end: localDate(2026, 7, 26, 7, 0),
            reason: .sleepWindow,
            ruleTitle: nil,
            wakeTimeText: "7:00 AM"
        )
        var json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(window)) as? [String: Any]
        )
        json.removeValue(forKey: "recurrence")
        json.removeValue(forKey: "startMinuteOfDay")
        json.removeValue(forKey: "endMinuteOfDay")

        let decoded = try JSONDecoder().decode(
            AppBlockingMonitorWindow.self,
            from: JSONSerialization.data(withJSONObject: json)
        )

        XCTAssertEqual(decoded.recurrence, .oneTime)
    }

    func testBlockingPlanUsesRecurringBaseWindowAndEmergencyReconciliation() throws {
        let state = AppState()
        let now = localDate(2026, 7, 24, 21, 0)
        state.typicalBedtime = localDate(2026, 7, 24, 22, 30)
        state.typicalWakeTime = localDate(2026, 7, 25, 7, 0)
        state.appBlockingEndTime = state.typicalWakeTime
        state.sleepContractActivatedAt = localDate(2026, 7, 24, 18, 0)
        state.selectedSleepRules = [.dimLights]
        state.emergencyAppAccessSession = EmergencyAppAccessSession(
            reason: .health,
            duration: .fifteen,
            startedAt: now,
            endsAt: now.addingTimeInterval(15 * 60)
        )

        let windows = state.appBlockingMonitorWindows(now: now)
        let sleepWindow = try XCTUnwrap(windows.first { $0.reason == .sleepWindow })
        let reconciliation = try XCTUnwrap(windows.first { $0.reason == .reconcile })
        let schedule = try XCTUnwrap(state.deviceActivitySchedule(for: sleepWindow, now: now))

        XCTAssertTrue(sleepWindow.id.hasPrefix("sleep."))
        XCTAssertEqual(sleepWindow.recurrence, .daily)
        XCTAssertTrue(schedule.repeats)
        XCTAssertEqual(reconciliation.start, state.emergencyAppAccessSession?.endsAt)
        XCTAssertEqual(reconciliation.recurrence, .oneTime)
        XCTAssertEqual(reconciliation.end.timeIntervalSince(reconciliation.start), 15 * 60)
    }

    func testShortOneTimeMonitorIsPaddedToDeviceActivityMinimum() throws {
        let state = AppState()
        let now = localDate(2026, 7, 24, 21, 0)
        let window = AppBlockingMonitorWindow(
            id: "cooldown.dimLights",
            start: now,
            end: now.addingTimeInterval(10 * 60),
            reason: .rule,
            ruleTitle: SleepRuleKind.dimLights.title,
            wakeTimeText: "7:00 AM"
        )

        let schedule = try XCTUnwrap(state.deviceActivitySchedule(for: window, now: now))
        let scheduledStart = try XCTUnwrap(calendar.date(from: schedule.intervalStart))
        let scheduledEnd = try XCTUnwrap(calendar.date(from: schedule.intervalEnd))

        XCTAssertFalse(schedule.repeats)
        XCTAssertGreaterThanOrEqual(scheduledEnd.timeIntervalSince(scheduledStart), 15 * 60)
    }

    func testGentleBypassBoundaryIsExcludedFromHardBlockingPlan() {
        let state = AppState()
        let now = localDate(2026, 7, 24, 21, 0)
        state.typicalBedtime = localDate(2026, 7, 24, 22, 30)
        state.typicalWakeTime = localDate(2026, 7, 25, 7, 0)
        state.sleepContractActivatedAt = localDate(2026, 7, 24, 18, 0)
        state.paywallState.gentleBlockingBypassedUntil = now.addingTimeInterval(30 * 60)

        state.paywallState.tier = .subscribed
        XCTAssertFalse(state.appBlockingMonitorWindows(now: now).contains {
            $0.id.hasPrefix("reconcile.bypass")
        })

        state.paywallState.tier = .free
        XCTAssertTrue(state.appBlockingMonitorWindows(now: now).contains {
            $0.id.hasPrefix("reconcile.bypass")
        })
    }

    func testPersistedStateRoundTripsSleepContractFields() throws {
        let activatedAt = localDate(2026, 7, 24, 20, 0)
        let emergency = EmergencyAppAccessSession(
            reason: .health,
            duration: .five,
            startedAt: activatedAt,
            endsAt: activatedAt.addingTimeInterval(5 * 60)
        )
        let persisted = persistedStateFixture(
            activatedAt: activatedAt,
            selectedRules: [.morningSun, .dimLights],
            emergencySession: emergency
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let decoded = try decoder.decode(PersistedState.self, from: encoder.encode(persisted))

        XCTAssertEqual(decoded.sleepContractActivatedAt, activatedAt)
        XCTAssertEqual(decoded.selectedSleepRules, [.morningSun, .dimLights])
        XCTAssertEqual(decoded.emergencyAppAccessSession, emergency)
    }

    func testPreContractPersistedStateDefaultsContractFieldsSafely() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let encoded = try encoder.encode(persistedStateFixture())
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        json.removeValue(forKey: "sleepContractActivatedAt")
        json.removeValue(forKey: "selectedSleepRules")
        json.removeValue(forKey: "sleepRuleConfigurations")
        json.removeValue(forKey: "sleepRuleCompletions")
        json.removeValue(forKey: "sleepRuleSlips")
        json.removeValue(forKey: "contractLockEvents")
        json.removeValue(forKey: "contractAllClearEvents")
        json.removeValue(forKey: "emergencyAppAccessSession")
        let legacyData = try JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let decoded = try decoder.decode(PersistedState.self, from: legacyData)

        XCTAssertNil(decoded.sleepContractActivatedAt)
        XCTAssertTrue(decoded.selectedSleepRules.isEmpty)
        XCTAssertTrue(decoded.sleepRuleConfigurations.isEmpty)
        XCTAssertTrue(decoded.sleepRuleCompletions.isEmpty)
        XCTAssertTrue(decoded.sleepRuleSlips.isEmpty)
        XCTAssertTrue(decoded.contractLockEvents.isEmpty)
        XCTAssertTrue(decoded.contractAllClearEvents.isEmpty)
        XCTAssertNil(decoded.emergencyAppAccessSession)
    }

    private func persistedStateFixture(
        activatedAt: Date? = nil,
        selectedRules: [SleepRuleKind] = [],
        emergencySession: EmergencyAppAccessSession? = nil
    ) -> PersistedState {
        PersistedState(
            selectedSleepProblems: [],
            selectedWakes: [],
            sleepWindowMinutes: 30,
            typicalBedtime: localDate(2026, 7, 24, 22, 30),
            typicalWakeTime: localDate(2026, 7, 24, 7, 0),
            selectedPreBedActivities: [],
            selectedTriedThings: [],
            coreRoutine: [],
            routineExplanation: "",
            sleepLogs: [],
            sleepContractActivatedAt: activatedAt,
            selectedSleepRules: selectedRules,
            emergencyAppAccessSession: emergencySession
        )
    }

    private func step(order: Int,
                      label: String,
                      mode: RoutineMode,
                      lead: Int? = nil,
                      remedy: RemedyID) -> RoutineStep {
        RoutineStep(
            order: order,
            label: label,
            mode: mode,
            leadTimeMins: lead,
            durationLabel: nil,
            notes: nil,
            repeatCadence: nil,
            notifyEnabled: nil,
            remedyId: remedy,
            category: mode == .reminderOnly ? .bedtimePrep : .windDown,
            enforcementMode: nil
        )
    }
}
