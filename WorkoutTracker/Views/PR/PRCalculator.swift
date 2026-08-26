//
//  PRCalculator.swift
//  WorkoutTracker
//
//  Created by Alexandru Mihalache on 25/08/2026.
//

import Foundation

struct PRDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

enum PRCalculator {
    static func weightDataPoints(entries: [ExerciseEntry]) -> [PRDataPoint] {
        entries
            .compactMap { entry -> PRDataPoint? in
                guard let date = entry.workout?.date,
                      let sessionMax = entry.workingSets.map({ $0.weight }).max() else { return nil }
                return PRDataPoint(date: date, value: sessionMax)
            }
            .sorted { $0.date < $1.date }
    }

    static func weightPR(entries: [ExerciseEntry]) -> Double? {
        weightDataPoints(entries: entries).map { $0.value }.max()
    }

    static func bodyweightRatio(prWeightKg: Double?, bodyweightKg: Double) -> Double? {
        guard bodyweightKg > 0, let pr = prWeightKg else { return nil }
        return pr / bodyweightKg
    }

    static func repsDataPoints(entries: [ExerciseEntry]) -> [PRDataPoint] {
        entries
            .compactMap { entry -> PRDataPoint? in
                guard let date = entry.workout?.date else { return nil }
                let bodyweightSets = entry.workingSets.filter { $0.weight == 0 }
                guard let sessionMax = bodyweightSets.map({ $0.reps }).max() else { return nil }
                return PRDataPoint(date: date, value: Double(sessionMax))
            }
            .sorted { $0.date < $1.date }
    }

    static func repsPR(entries: [ExerciseEntry]) -> Int? {
        let points = repsDataPoints(entries: entries)
        guard let maxVal = points.map({ $0.value }).max() else { return nil }
        return Int(maxVal)
    }

    static func assistedDataPoints(entries: [ExerciseEntry], bodyweightKg: Double) -> [PRDataPoint] {
        guard bodyweightKg > 0 else { return [] }
        return entries
            .compactMap { entry -> PRDataPoint? in
                guard let date = entry.workout?.date,
                      let minAssistance = entry.workingSets.map({ $0.weight }).min() else { return nil }
                return PRDataPoint(date: date, value: bodyweightKg - minAssistance)
            }
            .sorted { $0.date < $1.date }
    }

    static func assistedPR(entries: [ExerciseEntry], bodyweightKg: Double) -> Double? {
        assistedDataPoints(entries: entries, bodyweightKg: bodyweightKg).map { $0.value }.max()
    }
}
