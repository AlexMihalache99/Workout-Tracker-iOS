//
//  SetEntry.swift
//  WorkoutTracker
//
//  Created by Alexandru Mihalache on 18/07/2026.
//

import Foundation
import SwiftData

enum SetType: String, Codable {
    case warmup
    case working
}

@Model
final class SetEntry {
    var setType: SetType
    var setNumber: Int
    var weight: Double
    var reps: Int
    var rpe: Double?
    var rir: Int?
    var exerciseEntry: ExerciseEntry?

    static let validRPERange: ClosedRange<Double> = 0.5...10
    static let validRIRRange: ClosedRange<Int> = 0...5

    init(setType: SetType, setNumber: Int, weight: Double, reps: Int, rpe: Double? = nil, rir: Int? = nil) {
        self.setType = setType
        self.setNumber = setNumber
        self.weight = max(weight, 0)
        self.reps = max(reps, 0)

        if let rpe {
            self.rpe = rpe.clamped(to: SetEntry.validRPERange)
            self.rir = nil
        } else if let rir {
            self.rir = rir.clamped(to: SetEntry.validRIRRange)
            self.rpe = nil
        } else {
            self.rpe = nil
            self.rir = nil
        }
    }
    
    func normalize() {
        weight = max(weight, 0)
        reps = max(reps, 0)
        if rpe != nil {
            rpe = rpe.map { $0.clamped(to: SetEntry.validRPERange) }
            rir = nil
        } else if let currentRIR = rir {
            rir = currentRIR.clamped(to: SetEntry.validRIRRange)
        }
    }
    
    func update(weight: Double, reps: Int, rpe: Double?, rir: Int?) {
        self.weight = weight
        self.reps = reps
        self.rpe = rpe
        self.rir = rir
        normalize()
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

