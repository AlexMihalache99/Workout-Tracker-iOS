//
//  ConsistencyCalculator.swift
//  WorkoutTracker
//
//  Created by Alexandru Mihalache on 24/08/2026.
//

import Foundation

struct DayActivity: Identifiable {
    let id = UUID()
    let date: Date
    let setCount: Int
    let workoutCount: Int

    var intensityLevel: Int {
        guard workoutCount > 0 else { return 0 }
        switch setCount {
        case 0: return 0
        case 1...5: return 1
        case 6...10: return 2
        case 11...15: return 3
        default: return 4
        }
    }
}

struct ConsistencyStats {
    let days: [DayActivity]   // oldest -> newest, aligned to full weeks
    let currentWeekStreak: Int
    let longestWeekStreak: Int
    let avgSessionsPerWeek: Double
}

enum ConsistencyCalculator {
    static func build(workouts: [Workout], weeksBack: Int = 20, referenceDate: Date = .now) -> ConsistencyStats {
        let calendar = Calendar.current
        let workoutsByDay = Dictionary(grouping: workouts) { calendar.startOfDay(for: $0.date) }

        guard let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: referenceDate)?.start,
              let currentWeekEnd = calendar.dateInterval(of: .weekOfYear, for: referenceDate)?.end,
              let gridStart = calendar.date(byAdding: .weekOfYear, value: -(weeksBack - 1), to: currentWeekStart) else {
            return ConsistencyStats(days: [], currentWeekStreak: 0, longestWeekStreak: 0, avgSessionsPerWeek: 0)
        }

        var days: [DayActivity] = []
        var cursor = gridStart
        while cursor < currentWeekEnd {
            let dayWorkouts = workoutsByDay[cursor] ?? []
            let setCount = dayWorkouts.reduce(0) { $0 + $1.totalWorkingSets }
            days.append(DayActivity(date: cursor, setCount: setCount, workoutCount: dayWorkouts.count))
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? cursor.addingTimeInterval(86400)
        }

        let weeksWithActivity = Set(
            workouts
                .filter { $0.date < currentWeekEnd }
                .map { calendar.dateInterval(of: .weekOfYear, for: $0.date)?.start ?? $0.date }
        )

        var currentStreak = 0
        var weekCursor = currentWeekStart
        while weeksWithActivity.contains(weekCursor) {
            currentStreak += 1
            weekCursor = calendar.date(byAdding: .weekOfYear, value: -1, to: weekCursor) ?? weekCursor
        }

        let sortedWeeks = weeksWithActivity.sorted()
        var longestStreak = 0
        var running = 0
        var previous: Date?
        for week in sortedWeeks {
            if let prev = previous, calendar.date(byAdding: .weekOfYear, value: 1, to: prev) == week {
                running += 1
            } else {
                running = 1
            }
            longestStreak = max(longestStreak, running)
            previous = week
        }

        let earliestWorkoutDate = workouts.map { $0.date }.min()
        let weeksActive: Int
        if let earliest = earliestWorkoutDate, earliest > gridStart {
            let weeksSinceStart = calendar.dateComponents([.weekOfYear], from: earliest, to: currentWeekEnd).weekOfYear ?? weeksBack
            weeksActive = max(1, min(weeksBack, weeksSinceStart + 1))
        } else {
            weeksActive = weeksBack
        }
        let windowWorkoutCount = workouts.filter { $0.date >= gridStart && $0.date < currentWeekEnd }.count
        let avgPerWeek = Double(windowWorkoutCount) / Double(weeksActive)

        return ConsistencyStats(days: days, currentWeekStreak: currentStreak, longestWeekStreak: longestStreak, avgSessionsPerWeek: avgPerWeek)
    }
}
