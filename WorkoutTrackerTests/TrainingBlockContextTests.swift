//
//  TrainingBlockContextTests.swift
//  WorkoutTracker
//
//  Created by Alexandru Mihalache on 12/10/2026.
//


import XCTest
@testable import WorkoutTracker

final class TrainingBlockContextTests: XCTestCase {

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        c.firstWeekday = 2
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d))!
    }

    // Monday Jun 1 2026 = week 1 of a 10-week block with testing in week 10.
    private var block: TrainingBlockContext {
        TrainingBlockContext(startDate: date(2026, 6, 1), lengthWeeks: 10, testingWeek: 10, notes: "")
    }

    func test_blockWeek_countsFromStartWeek() {
        XCTAssertEqual(block.blockWeek(forWeekStarting: date(2026, 6, 1), calendar: calendar), 1)
        XCTAssertEqual(block.blockWeek(forWeekStarting: date(2026, 6, 8), calendar: calendar), 2)
        XCTAssertEqual(block.blockWeek(forWeekStarting: date(2026, 8, 3), calendar: calendar), 10)
    }

    func test_blockWeek_wrapsIntoNextBlock() {
        XCTAssertEqual(block.blockWeek(forWeekStarting: date(2026, 8, 10), calendar: calendar), 1)
    }

    func test_blockWeek_extendsBackwardsBeforeStart() {
        XCTAssertEqual(block.blockWeek(forWeekStarting: date(2026, 5, 25), calendar: calendar), 10)
    }

    func test_startDateMidWeek_anchorsToThatWeeksMonday() {
        let midWeek = TrainingBlockContext(startDate: date(2026, 6, 3), lengthWeeks: 10, testingWeek: 10, notes: "")
        XCTAssertEqual(midWeek.blockWeek(forWeekStarting: date(2026, 6, 1), calendar: calendar), 1)
    }

    func test_isTestingWeek() {
        XCTAssertTrue(block.isTestingWeek(forWeekStarting: date(2026, 8, 3), calendar: calendar))
        XCTAssertFalse(block.isTestingWeek(forWeekStarting: date(2026, 7, 27), calendar: calendar))
    }

    func test_noTestingWeek_neverMarksOne() {
        var noTesting = block
        noTesting.testingWeek = 0
        XCTAssertFalse(noTesting.isTestingWeek(forWeekStarting: date(2026, 8, 3), calendar: calendar))
    }

    func test_load_returnsNilWhenDisabledOrUnset() {
        let defaults = UserDefaults(suiteName: "TrainingBlockContextTests")!
        defaults.removePersistentDomain(forName: "TrainingBlockContextTests")

        XCTAssertNil(TrainingBlockContext.load(from: defaults))   // disabled

        defaults.set(true, forKey: TrainingBlockContext.Keys.enabled)
        XCTAssertNil(TrainingBlockContext.load(from: defaults))   // no start date yet
    }

    func test_load_appliesDefaultsAndClampsTestingWeek() {
        let defaults = UserDefaults(suiteName: "TrainingBlockContextTests")!
        defaults.removePersistentDomain(forName: "TrainingBlockContextTests")
        defaults.set(true, forKey: TrainingBlockContext.Keys.enabled)
        defaults.set(date(2026, 6, 1).timeIntervalSince1970, forKey: TrainingBlockContext.Keys.startTimestamp)

        let loaded = TrainingBlockContext.load(from: defaults)
        XCTAssertEqual(loaded?.lengthWeeks, 10)    // AppStorage default isn't persisted
        XCTAssertEqual(loaded?.testingWeek, 10)

        defaults.set(8, forKey: TrainingBlockContext.Keys.lengthWeeks)
        XCTAssertEqual(TrainingBlockContext.load(from: defaults)?.testingWeek, 8)   // clamped to length
    }
}