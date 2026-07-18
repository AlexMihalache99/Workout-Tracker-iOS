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
    var rpe: Double?   // optional, 0.5–10
    var rir: Int?       // optional, 0–5 (use RPE or RIR, not both)

    init(setType: SetType, setNumber: Int, weight: Double, reps: Int, rpe: Double? = nil, rir: Int? = nil) {
        self.setType = setType
        self.setNumber = setNumber
        self.weight = weight
        self.reps = reps
        self.rpe = rpe
        self.rir = rir
    }
}
