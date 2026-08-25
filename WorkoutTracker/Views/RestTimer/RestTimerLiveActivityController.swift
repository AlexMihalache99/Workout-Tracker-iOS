//
//  RestTimerLiveActivityController.swift
//  WorkoutTracker
//
//  Created by Coding Assistant on 25/08/2026.
//

import ActivityKit
import Foundation

enum RestTimerLiveActivityController {
    static func start(startedAt: Date, endsAt: Date, totalSeconds: Int) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        await endAll(dismissalPolicy: .immediate)

        let attributes = RestTimerAttributes(title: "Rest Timer")
        let state = RestTimerAttributes.ContentState(
            startedAt: startedAt,
            endsAt: endsAt,
            totalSeconds: totalSeconds
        )
        let content = ActivityContent(state: state, staleDate: endsAt, relevanceScore: 100)

        do {
            _ = try Activity.request(attributes: attributes, content: content, pushType: nil)
        } catch {
            // Live Activities can be unavailable or denied; the notification fallback still covers completion.
        }
    }

    static func update(startedAt: Date, endsAt: Date, totalSeconds: Int) async {
        let state = RestTimerAttributes.ContentState(
            startedAt: startedAt,
            endsAt: endsAt,
            totalSeconds: totalSeconds
        )
        let content = ActivityContent(state: state, staleDate: endsAt, relevanceScore: 100)

        for activity in Activity<RestTimerAttributes>.activities {
            await activity.update(content)
        }
    }

    static func end(dismissalPolicy: ActivityUIDismissalPolicy = .immediate) async {
        await endAll(dismissalPolicy: dismissalPolicy)
    }

    private static func endAll(dismissalPolicy: ActivityUIDismissalPolicy) async {
        let now = Date()
        for activity in Activity<RestTimerAttributes>.activities {
            let currentState = activity.content.state
            let finalState = RestTimerAttributes.ContentState(
                startedAt: currentState.startedAt,
                endsAt: max(currentState.endsAt, now),
                totalSeconds: currentState.totalSeconds
            )
            let content = ActivityContent(state: finalState, staleDate: nil)
            await activity.end(content, dismissalPolicy: dismissalPolicy)
        }
    }
}
