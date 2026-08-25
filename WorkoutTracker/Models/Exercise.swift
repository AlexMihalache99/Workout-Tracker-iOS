//
//  Exercise.swift
//  WorkoutTracker
//
//  Created by Alexandru Mihalache on 18/07/2026.
//

import Foundation
import SwiftData

enum PRMetric: String, Codable, CaseIterable {
    case weight
    case reps
    case assisted
}

@Model
final class Exercise {
    var name: String
    var category: String
    var isMainLift: Bool
    var prMetric: PRMetric?

    init(name: String, category: String, isMainLift: Bool = false, prMetric: PRMetric? = nil) {
        self.name = name
        self.category = category
        self.isMainLift = isMainLift
        self.prMetric = prMetric
    }
}
