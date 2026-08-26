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
    let avgEffort: Double?
}

struct LiftProgress: Identifiable {
    let id = UUID()
    let exerciseName: String
    let metric: PRMetric

    // .weight
    var earliestWeight: Double?
    var bestWeight: Double?                        // topWeightSet's weight — heaviest weight moved
    var estimatedOneRepMax: Double?
    var estimatedOneRepMaxSourceWeight: Double?     // which set produced the 1RM estimate — may differ from bestWeight
    var estimatedOneRepMaxSourceReps: Int?
    var bodyweightRatio: Double?

    // .reps (bodyweight sets only)
    var earliestReps: Int?
    var bestReps: Int?
    var addedWeightSeen: Bool = false
    var maxAddedWeight: Double?

    // .assisted
    var earliestEffectiveLoad: Double?
    var bestEffectiveLoad: Double?

    var deloadSignal: Bool = false

    var weightDelta: Double? {
        guard let e = earliestWeight, let b = bestWeight else { return nil }
        return b - e
    }
    var repsDelta: Int? {
        guard let e = earliestReps, let b = bestReps else { return nil }
        return b - e
    }
    var effectiveLoadDelta: Double? {
        guard let e = earliestEffectiveLoad, let b = bestEffectiveLoad else { return nil }
        return b - e
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
    let lowestEffortWeek: WeeklyStat?    // week with the lowest average RPE — sets felt easiest
    let highestEffortWeek: WeeklyStat?   // week with the highest average RPE — sets felt hardest
    let insights: [String]
}

enum ReportGenerator {
    static func generate(workouts: [Workout], allExercises: [Exercise], start: Date, end: Date, phase: TrainingPhase, bodyweightKg: Double) -> WorkoutReport {
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
        let lowestEffortWeek = weeksWithEffort.min { ($0.avgEffort ?? 0) < ($1.avgEffort ?? 0) }
        let highestEffortWeek = weeksWithEffort.max { ($0.avgEffort ?? 0) < ($1.avgEffort ?? 0) }

        let trackedExercises = allExercises.filter { $0.prMetric != nil }
        var liftProgress: [LiftProgress] = []

        for exercise in trackedExercises {
            guard let metric = exercise.prMetric else { continue }
            let entries = inRange.flatMap { $0.exercises }.filter { $0.exercise?.name == exercise.name }
            guard !entries.isEmpty else { continue }

            var progress = LiftProgress(exerciseName: exercise.name, metric: metric)

            switch metric {
            case .weight:
                let sessions: [(date: Date, weight: Double, reps: Int)] = entries.compactMap { entry in
                    guard let date = entry.workout?.date,
                          let top = entry.workingSets.max(by: { $0.weight < $1.weight }) else { return nil }
                    return (date, top.weight, top.reps)
                }.sorted { $0.date < $1.date }
                guard !sessions.isEmpty else { continue }

                // topWeightSet: heaviest weight moved, regardless of reps
                progress.earliestWeight = sessions.first?.weight
                progress.bestWeight = sessions.map { $0.weight }.max()

                // bestEstimated1RMSet: independently selected. Epley can favor a lighter,
                // higher-rep set over the nominally heaviest set (e.g. 100kg x 10 can beat
                // 110kg x 3) -- this is correct, not a bug, and the two are not guaranteed
                // to be the same set.
                let best1RMSession = sessions.max { lhs, rhs in
                    (lhs.weight * (1 + Double(lhs.reps) / 30.0)) < (rhs.weight * (1 + Double(rhs.reps) / 30.0))
                }
                progress.estimatedOneRepMax = best1RMSession.map { $0.weight * (1 + Double($0.reps) / 30.0) }
                progress.estimatedOneRepMaxSourceWeight = best1RMSession?.weight
                progress.estimatedOneRepMaxSourceReps = best1RMSession?.reps

                if bodyweightKg > 0, let best = progress.bestWeight {
                    progress.bodyweightRatio = best / bodyweightKg
                }
                progress.deloadSignal = detectDeloadSignal(entries: entries, calendar: calendar)

            case .reps:
                let bodyweightSessions: [(date: Date, reps: Int)] = entries.compactMap { entry in
                    guard let date = entry.workout?.date else { return nil }
                    let bwSets = entry.workingSets.filter { $0.weight == 0 }
                    guard let maxReps = bwSets.map({ $0.reps }).max() else { return nil }
                    return (date, maxReps)
                }.sorted { $0.date < $1.date }

                progress.earliestReps = bodyweightSessions.first?.reps
                progress.bestReps = bodyweightSessions.map { $0.reps }.max()

                let weightedSets = entries.flatMap { $0.workingSets }.filter { $0.weight > 0 }
                if let maxAdded = weightedSets.map({ $0.weight }).max() {
                    progress.addedWeightSeen = true
                    progress.maxAddedWeight = maxAdded
                }
                guard progress.earliestReps != nil || progress.addedWeightSeen else { continue }

            case .assisted:
                guard bodyweightKg > 0 else { continue }
                let sessions: [(date: Date, effectiveLoad: Double)] = entries.compactMap { entry in
                    guard let date = entry.workout?.date,
                          let minAssistance = entry.workingSets.map({ $0.weight }).min() else { return nil }
                    return (date, bodyweightKg - minAssistance)
                }.sorted { $0.date < $1.date }
                guard !sessions.isEmpty else { continue }

                progress.earliestEffectiveLoad = sessions.first?.effectiveLoad
                progress.bestEffectiveLoad = sessions.map { $0.effectiveLoad }.max()
            }

            liftProgress.append(progress)
        }

        let insights = buildInsights(
            phase: phase,
            liftProgress: liftProgress,
            weeklyStats: weeklyStats,
            lowestEffortWeek: lowestEffortWeek,
            highestEffortWeek: highestEffortWeek,
            totalWorkouts: inRange.count
        )

        return WorkoutReport(
            startDate: start, endDate: end, phase: phase,
            totalWorkouts: inRange.count, totalSets: totalSets,
            totalReps: totalReps, totalVolume: totalVolume,
            weeklyStats: weeklyStats, liftProgress: liftProgress,
            lowestEffortWeek: lowestEffortWeek, highestEffortWeek: highestEffortWeek,
            insights: insights
        )
    }

    private static func effortScore(for set: SetEntry) -> Double? {
        if let rpe = set.rpe { return rpe }
        if let rir = set.rir { return 10.0 - Double(rir) }
        return nil
    }

    private static func detectDeloadSignal(entries: [ExerciseEntry], calendar: Calendar) -> Bool {
        var weeklyEffort: [Date: [Double]] = [:]

        for entry in entries {
            guard let date = entry.workout?.date else { continue }

            let weekStart = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date

            for set in entry.workingSets {
                if let rpe = set.rpe {
                    weeklyEffort[weekStart, default: []].append(rpe)
                } else if let rir = set.rir {
                    weeklyEffort[weekStart, default: []].append(10.0 - Double(rir))
                }
            }
        }

        let sortedWeeks = weeklyEffort.keys.sorted()
        guard sortedWeeks.count >= 3 else { return false }

        let lastThreeWeeks = Array(sortedWeeks.suffix(3))
        guard lastThreeWeeks.count == 3 else { return false }

        let areConsecutive = zip(lastThreeWeeks, lastThreeWeeks.dropFirst()).allSatisfy {
            guard let expectedNext = calendar.date(byAdding: .weekOfYear, value: 1, to: $0) else {
                return false
            }
            return calendar.isDate(expectedNext, inSameDayAs: $1)
        }

        guard areConsecutive else { return false }

        let avgByWeek = lastThreeWeeks.map { week -> Double in
            let values = weeklyEffort[week] ?? []
            return values.reduce(0, +) / Double(max(values.count, 1))
        }

        let risingEffort =
            avgByWeek[0] < avgByWeek[1] &&
            avgByWeek[1] < avgByWeek[2]

        let topSetsInWindow = entries.compactMap { entry -> (week: Date, weight: Double)? in
            guard let date = entry.workout?.date,
                  let weekStart = calendar.dateInterval(of: .weekOfYear, for: date)?.start,
                  lastThreeWeeks.contains(weekStart),
                  let top = entry.workingSets.map({ $0.weight }).max() else {
                return nil
            }

            return (weekStart, top)
        }

        guard let firstWeekTop = topSetsInWindow
            .filter({ $0.week == lastThreeWeeks.first })
            .map({ $0.weight })
            .max(),
              let lastWeekTop = topSetsInWindow
            .filter({ $0.week == lastThreeWeeks.last })
            .map({ $0.weight })
            .max() else {
            return risingEffort
        }

        let weightStagnant = lastWeekTop <= firstWeekTop

        return risingEffort && weightStagnant
    }

    private static func buildInsights(
        phase: TrainingPhase,
        liftProgress: [LiftProgress],
        weeklyStats: [WeeklyStat],
        lowestEffortWeek: WeeklyStat?,
        highestEffortWeek: WeeklyStat?,
        totalWorkouts: Int
    ) -> [String] {
        var insights: [String] = []
        guard totalWorkouts > 0 else {
            return ["No workouts logged in this period."]
        }

        for lift in liftProgress {
            switch lift.metric {
            case .weight:
                if phase == .strength {
                    if let delta = lift.weightDelta {
                        if delta > 0 {
                            insights.append("\(lift.exerciseName) went from your week-1 top set up to a period-best \(String(format: "%.1f", lift.bestWeight ?? 0)) kg — a \(String(format: "%.1f", delta)) kg improvement.")
                        } else if delta < 0 {
                            insights.append("\(lift.exerciseName) period-best top set (\(String(format: "%.1f", lift.bestWeight ?? 0)) kg) came in \(String(format: "%.1f", abs(delta))) kg below your week-1 top set — worth a look.")
                        } else {
                            insights.append("\(lift.exerciseName) top set held steady across the period.")
                        }
                    }
                    if let oneRM = lift.estimatedOneRepMax {
                        if let srcWeight = lift.estimatedOneRepMaxSourceWeight, let srcReps = lift.estimatedOneRepMaxSourceReps {
                            insights.append("\(lift.exerciseName) estimated 1RM (Epley): \(String(format: "%.1f", oneRM)) kg, based on \(String(format: "%.1f", srcWeight)) kg × \(srcReps).")
                        } else {
                            insights.append("\(lift.exerciseName) estimated 1RM (Epley): \(String(format: "%.1f", oneRM)) kg.")
                        }
                    }
                    if let ratio = lift.bodyweightRatio {
                        insights.append("\(lift.exerciseName) is now \(String(format: "%.2f", ratio))x your bodyweight.")
                    }
                }
                if lift.deloadSignal {
                    insights.append("⚠️ \(lift.exerciseName): effort has risen for 3 straight weeks without a matching weight increase — a deload may help.")
                }

            case .reps:
                if let delta = lift.repsDelta {
                    if delta > 0 {
                        insights.append("\(lift.exerciseName) bodyweight reps went from \(lift.earliestReps ?? 0) to a period-best \(lift.bestReps ?? 0) — up \(delta) reps.")
                    } else if delta < 0 {
                        insights.append("\(lift.exerciseName) period-best bodyweight reps (\(lift.bestReps ?? 0)) came in below your week-1 count (\(lift.earliestReps ?? 0)).")
                    } else {
                        insights.append("\(lift.exerciseName) bodyweight reps held steady at \(lift.bestReps ?? 0).")
                    }
                }
                if lift.addedWeightSeen, let maxAdded = lift.maxAddedWeight {
                    insights.append("\(lift.exerciseName): you added external weight this period, up to \(String(format: "%.1f", maxAdded)) kg.")
                }

            case .assisted:
                if let delta = lift.effectiveLoadDelta {
                    if delta > 0 {
                        insights.append("\(lift.exerciseName) effective load went from \(String(format: "%.1f", lift.earliestEffectiveLoad ?? 0)) kg to a period-best \(String(format: "%.1f", lift.bestEffectiveLoad ?? 0)) kg as assistance decreased.")
                    } else if delta < 0 {
                        insights.append("\(lift.exerciseName) effective load dipped this period — you're using more assistance than in week 1.")
                    } else {
                        insights.append("\(lift.exerciseName) effective load held steady.")
                    }
                }
            }
        }

        if phase == .bodybuilding {
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

        if let lowest = lowestEffortWeek, let highest = highestEffortWeek, lowest.weekStart != highest.weekStart {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            insights.append("Week of \(formatter.string(from: lowest.weekStart)) had your lowest average RPE — sets felt easiest that week.")
            insights.append("Week of \(formatter.string(from: highest.weekStart)) had your highest average RPE — sets felt hardest that week.")
        }

        return insights
    }
}
