import XCTest
@testable import TenThirty

@MainActor
final class AppStateRegressionTests: XCTestCase {
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

        XCTAssertTrue(state.shouldOfferAppBlockingAfterFirstNight)
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

    func testMorningSunUsesWakeToNoonRangeAndCanCompleteDuringMorning() {
        let state = AppState()
        state.typicalWakeTime = localDate(2026, 6, 28, 7, 15)
        state.selectedSleepRules = [.morningSun]

        let item = state.todaysContractItems(now: localDate(2026, 6, 28, 8, 30)).first!
        let start = Calendar.current.dateComponents([.hour, .minute], from: item.availableAt)
        let end = Calendar.current.dateComponents([.hour, .minute], from: item.dueAt)

        XCTAssertEqual(start.hour, 7)
        XCTAssertEqual(start.minute, 15)
        XCTAssertEqual(end.hour, 12)
        XCTAssertEqual(end.minute, 0)
        XCTAssertTrue(item.isRange)
        XCTAssertTrue(state.canCompleteSleepRule(item, now: localDate(2026, 6, 28, 8, 30)))
        XCTAssertFalse(state.canCompleteSleepRule(item, now: localDate(2026, 6, 28, 7, 0)))
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

    func testLateCompletionCreatesTenMinuteCooldownThenUnlocks() {
        let state = AppState()
        state.typicalBedtime = localDate(2026, 6, 28, 22, 0)
        state.sleepContractActivatedAt = localDate(2026, 6, 28, 8, 0)
        state.selectedSleepRules = [.dimLights]

        state.completeSleepRule(.dimLights, at: localDate(2026, 6, 28, 21, 0))

        if case .coolingDown(let item, _) = state.sleepContractSnapshot(now: localDate(2026, 6, 28, 21, 5)).lockState {
            XCTAssertEqual(item.rule, .dimLights)
        } else {
            XCTFail("Expected late completion cooldown")
        }

        if case .unlocked = state.sleepContractSnapshot(now: localDate(2026, 6, 28, 21, 11)).lockState {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected cooldown to expire after 10 minutes")
        }
    }

    func testSlippedRuleStartsSleepWindowTenMinutesEarlyWithoutClearing() {
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
        XCTAssertEqual(localHourMinute(state.effectiveSleepWindowStart(now: localDate(2026, 6, 28, 21, 16))), "21:50")

        if case .unlocked = state.sleepContractSnapshot(now: localDate(2026, 6, 28, 21, 49)).lockState {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected apps to stay unlocked before the slipped early window")
        }

        if case .sleepWindow = state.sleepContractSnapshot(now: localDate(2026, 6, 28, 21, 55)).lockState {
            XCTAssertTrue(state.sleepContractSnapshot(now: localDate(2026, 6, 28, 21, 55)).allItems.first?.isSlipped == true)
        } else {
            XCTFail("Expected slipped rule to start the sleep-window lock 10 minutes early")
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

        XCTAssertEqual(snapshot.allItems.map(\.startsTomorrow), [true, true])
        XCTAssertTrue(snapshot.actionableItems.isEmpty)
        if case .sleepWindow = snapshot.lockState {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected sleep window lock without exposing prior-evening rules")
        }
    }

    func testSleepWindowOverridesLateCompletionCooldown() {
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
            XCTFail("Expected sleep window lock to override cooldown")
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

        let completedAt = localDate(2026, 6, 28, 21, 0)
        let displayTick = localDate(2026, 6, 28, 21, 4)
        let displayTickWithSeconds = Calendar.current.date(byAdding: .second, value: 32, to: displayTick)!
        state.completeSleepRule(.dimLights, at: completedAt)

        let snapshot = state.sleepContractSnapshot(now: displayTickWithSeconds)

        XCTAssertEqual(snapshot.now, displayTickWithSeconds)
        if case .coolingDown(let item, let until) = snapshot.lockState {
            XCTAssertEqual(item.rule, .dimLights)
            XCTAssertEqual(until, completedAt.addingTimeInterval(10 * 60))
            XCTAssertEqual(Int(until.timeIntervalSince(displayTickWithSeconds)), 328)
        } else {
            XCTFail("Expected late completion to expose a precise cooldown window")
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
