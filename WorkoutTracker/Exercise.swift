//
//  Exercise.swift
//  WorkoutTracker
//
//  Created by Alexandru Mihalache on 18/07/2026.
//

import Foundation
import SwiftData

@Model
final class Exercise {
    var name: String
    var category: String   // e.g. "Big 3", "Accessory", "Cardio"
    var isMainLift: Bool   // true for Deadlift, Bench Press, Squat

    init(name: String, category: String, isMainLift: Bool = false) {
        self.name = name
        self.category = category
        self.isMainLift = isMainLift
    }
}
