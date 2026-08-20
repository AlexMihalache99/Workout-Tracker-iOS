//
//  ReportGenerator.swift
//  WorkoutTracker
//
//  Created by Alexandru Mihalache on 20/08/2026.
//

import Foundation

enum TrainingPhase: String, CaseIterable, Identifiable {
    case strength = "Strength"
    case bodybuilding = "Bodybuilding"
    var id: String { rawValue }
}

struct WeeklyStat: Identifiable {
    let id = UUID()
    let weekStart: Date
    let totalVolume: Double
    let workoutCount: Int
    let avgEffort: Double?   // 0–10 scale, higher = harder
}

struct LiftProgress: Identifiable {
    let id = UUID()
    let exerciseName: String
    let earliestTopSet: Double?
    let bestTopSet: Double?
    let bestTopSetReps: Int?
    let estimatedOneRepMax: Double?

    var delta: Double? {
        guard let earliest = earliestTopSet, let best = bestTopSet else { return nil }
        return best - earliest
    }
}

struct WorkoutReport {
    let startDate: Date
    let endDate: Date
    let phase: TrainingPhase
    let totalWorkouts: Int
    let totalSets: Int
    let totalReps: Int
    let totalVolume: Double
    let weeklyStats: [WeeklyStat]
    let liftProgress: [LiftProgress]
    let bestWeek: WeeklyStat?
    let toughestWeek: WeeklyStat?
    let insights: [String]
}

enum ReportGenerator {
    static func generate(workouts: [Workout], start: Date, end: Date, phase: TrainingPhase) -> WorkoutReport {
        let calendar = Calendar.current
        let inRange = workouts
            .filter { $0.date >= start && $0.date <= end }
            .sorted { $0.date < $1.date }

        let totalSets = inRange.reduce(0) { $0 + $1.totalWorkingSets }
        let totalReps = inRange.reduce(0) { $0 + $1.totalReps }
        let totalVolume = inRange.reduce(0.0) { $0 + $1.totalVolume }

        var weekBuckets: [Date: [Workout]] = [:]
        for workout in inRange {
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: workout.date)?.start ?? workout.date
            weekBuckets[weekStart, default: []].append(workout)
        }

        let weeklyStats: [WeeklyStat] = weekBuckets.map { weekStart, workoutsInWeek in
            let volume = workoutsInWeek.reduce(0.0) { $0 + $1.totalVolume }
            let efforts = workoutsInWeek
                .flatMap { $0.exercises }
                .flatMap { $0.workingSets }
                .compactMap { effortScore(for: $0) }
            let avgEffort = efforts.isEmpty ? nil : efforts.reduce(0, +) / Double(efforts.count)
            return WeeklyStat(weekStart: weekStart, totalVolume: volume, workoutCount: workoutsInWeek.count, avgEffort: avgEffort)
        }.sorted { $0.weekStart < $1.weekStart }

        let weeksWithEffort = weeklyStats.filter { $0.avgEffort != nil }
        let bestWeek = weeksWithEffort.min { ($0.avgEffort ?? 0) < ($1.avgEffort ?? 0) }
        let toughestWeek = weeksWithEffort.max { ($0.avgEffort ?? 0) < ($1.avgEffort ?? 0) }

        let mainLiftNames = ["Deadlift", "Bench Press", "Squat"]
        var liftProgress: [LiftProgress] = []
        for name in mainLiftNames {
            let entries = inRange.flatMap { $0.exercises }.filter { $0.exercise?.name == name }
            let sessionTopSets: [(date: Date, weight: Double, reps: Int)] = entries.compactMap { entry in
                guard let workoutDate = entry.workout?.date,
                      let topSet = entry.workingSets.max(by: { $0.weight < $1.weight }) else { return nil }
                return (workoutDate, topSet.weight, topSet.reps)
            }.sorted { $0.date < $1.date }

            guard !sessionTopSets.isEmpty else { continue }

            let earliest = sessionTopSets.first?.weight
            let best = sessionTopSets.max { $0.weight < $1.weight }

            let best1RMCandidate = sessionTopSets.max { lhs, rhs in
                let lhs1RM = lhs.weight * (1 + Double(lhs.reps) / 30.0)
                let rhs1RM = rhs.weight * (1 + Double(rhs.reps) / 30.0)
                return lhs1RM < rhs1RM
            }
            let estimated1RM = best1RMCandidate.map { $0.weight * (1 + Double($0.reps) / 30.0) }

            liftProgress.append(LiftProgress(
                exerciseName: name,
                earliestTopSet: earliest,
                bestTopSet: best?.weight,
                bestTopSetReps: best?.reps,
                estimatedOneRepMax: estimated1RM
            ))
        }
        
        let insights = buildInsights(
            phase: phase,
            liftProgress: liftProgress,
            weeklyStats: weeklyStats,
            bestWeek: bestWeek,
            toughestWeek: toughestWeek,
            totalWorkouts: inRange.count
        )

        return WorkoutReport(
            startDate: start, endDate: end, phase: phase,
            totalWorkouts: inRange.count, totalSets: totalSets,
            totalReps: totalReps, totalVolume: totalVolume,
            weeklyStats: weeklyStats, liftProgress: liftProgress,
            bestWeek: bestWeek, toughestWeek: toughestWeek, insights: insights
        )
    }

    private static func effortScore(for set: SetEntry) -> Double? {
        if let rpe = set.rpe { return rpe }
        if let rir = set.rir { return 10.0 - Double(rir) }
        return nil
    }

    private static func buildInsights(
        phase: TrainingPhase,
        liftProgress: [LiftProgress],
        weeklyStats: [WeeklyStat],
        bestWeek: WeeklyStat?,
        toughestWeek: WeeklyStat?,
        totalWorkouts: Int
    ) -> [String] {
        var insights: [String] = []
        guard totalWorkouts > 0 else {
            return ["No workouts logged in this period."]
        }

        switch phase {
        case .strength:
            for lift in liftProgress {
                if let delta = lift.delta {
                    if delta > 0 {
                        insights.append("\(lift.exerciseName) went from your week-1 top set up to a period-best \(String(format: "%.1f", lift.bestTopSet ?? 0)) kg — a \(String(format: "%.1f", delta)) kg improvement.")
                    } else if delta < 0 {
                        insights.append("\(lift.exerciseName) period-best top set (\(String(format: "%.1f", lift.bestTopSet ?? 0)) kg) came in \(String(format: "%.1f", abs(delta))) kg below your week-1 top set — worth a look.")
                    } else {
                        insights.append("\(lift.exerciseName) top set held steady across the period.")
                    }
                }
                if let oneRM = lift.estimatedOneRepMax {
                    insights.append("\(lift.exerciseName) estimated 1RM (Epley): \(String(format: "%.1f", oneRM)) kg.")
                }
            }
        case .bodybuilding:
            if weeklyStats.count >= 2, let firstVolume = weeklyStats.first?.totalVolume, let lastVolume = weeklyStats.last?.totalVolume {
                if lastVolume > firstVolume {
                    insights.append("Weekly training volume trended up — good sign for hypertrophy progression.")
                } else if lastVolume < firstVolume {
                    insights.append("Weekly training volume trended down — worth checking if that was a planned deload or a dip in consistency.")
                }
            }
            if !weeklyStats.isEmpty {
                let avgPerWeek = Double(totalWorkouts) / Double(weeklyStats.count)
                insights.append("Averaged \(String(format: "%.1f", avgPerWeek)) workouts per week over this period.")
            }
        }

        if let best = bestWeek, let toughest = toughestWeek, best.weekStart != toughest.weekStart {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            insights.append("Week of \(formatter.string(from: best.weekStart)) had your lowest average effort — you were likely feeling strongest.")
            insights.append("Week of \(formatter.string(from: toughest.weekStart)) had your highest average effort — your toughest stretch.")
        }

        return insights
    }
}
