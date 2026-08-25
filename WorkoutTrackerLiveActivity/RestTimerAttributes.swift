//
//  RestTimerAttributes.swift
//  WorkoutTrackerLiveActivity
//
//  Created by Coding Assistant on 25/08/2026.
//

import ActivityKit
import Foundation

struct RestTimerAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let startedAt: Date
        let endsAt: Date
        let totalSeconds: Int
    }

    let title: String
}
