//
//  TrainingBlockContext.swift
//  WorkoutTracker
//
//  Created by Alexandru Mihalache on 12/10/2026.
//


import Foundation

struct TrainingBlockContext: Equatable {
    var startDate: Date
    var lengthWeeks: Int      // e.g. 10
    var testingWeek: Int      // 1...lengthWeeks, 0 = no testing week
    var notes: String         // free text, e.g. "week 5 is a deload"

    enum Keys {
        static let enabled = "blockContextEnabled"
        static let startTimestamp = "blockStartTimestamp"
        static let lengthWeeks = "blockLengthWeeks"
        static let testingWeek = "blockTestingWeek"
        static let notes = "blockNotes"
    }

    /// nil when the lifter hasn't enabled/configured block context.
    static func load(from defaults: UserDefaults = .standard) -> TrainingBlockContext? {
        guard defaults.bool(forKey: Keys.enabled) else { return nil }
        let timestamp = defaults.double(forKey: Keys.startTimestamp)
        // @AppStorage doesn't write its default values, so a missing key means "10".
        let length = (defaults.object(forKey: Keys.lengthWeeks) as? Int) ?? 10
        let testing = (defaults.object(forKey: Keys.testingWeek) as? Int) ?? 10
        guard timestamp > 0, length > 0 else { return nil }
        return TrainingBlockContext(
            startDate: Date(timeIntervalSince1970: timestamp),
            lengthWeeks: length,
            testingWeek: min(max(testing, 0), length),
            notes: defaults.string(forKey: Keys.notes) ?? ""
        )
    }

    /// 1-based week number within the repeating block. Blocks are assumed to
    /// repeat back-to-back, in both directions from the start date.
    func blockWeek(forWeekStarting weekStart: Date, calendar: Calendar = .current) -> Int {
        guard lengthWeeks > 0,
              let startWeek = calendar.dateInterval(of: .weekOfYear, for: startDate)?.start else { return 1 }
        let weeks = calendar.dateComponents([.weekOfYear], from: startWeek, to: weekStart).weekOfYear ?? 0
        return (((weeks % lengthWeeks) + lengthWeeks) % lengthWeeks) + 1
    }

    func isTestingWeek(forWeekStarting weekStart: Date, calendar: Calendar = .current) -> Bool {
        testingWeek > 0 && blockWeek(forWeekStarting: weekStart, calendar: calendar) == testingWeek
    }
}