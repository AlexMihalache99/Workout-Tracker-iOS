//
//  RestTimerLiveActivityWidget.swift
//  WorkoutTrackerLiveActivity
//
//  Created by Coding Assistant on 25/08/2026.
//

import ActivityKit
import SwiftUI
import WidgetKit

struct RestTimerLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestTimerAttributes.self) { context in
            RestTimerLockScreenView(context: context)
                .activityBackgroundTint(Color(hex: "1F2024"))
                .activitySystemActionForegroundColor(Color(hex: "F3F2ED"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("Resting", systemImage: "timer")
                        .font(.headline)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    RestTimerCountdownText(state: context.state, size: 28)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    RestTimerProgressView(state: context.state)
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .foregroundStyle(Color(hex: "0057B8"))
            } compactTrailing: {
                RestTimerCountdownText(state: context.state, size: 14)
                    .monospacedDigit()
            } minimal: {
                Image(systemName: "timer")
                    .foregroundStyle(Color(hex: "0057B8"))
            }
        }
    }
}

private struct RestTimerLockScreenView: View {
    let context: ActivityViewContext<RestTimerAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(context.attributes.title, systemImage: "timer")
                    .font(.headline)
                    .foregroundStyle(Color(hex: "F3F2ED"))

                Spacer()

                RestTimerCountdownText(state: context.state, size: 34)
            }

            RestTimerProgressView(state: context.state)

            Text("Next set soon")
                .font(.caption)
                .foregroundStyle(Color(hex: "9A9CA3"))
        }
        .padding(16)
    }
}

private struct RestTimerCountdownText: View {
    let state: RestTimerAttributes.ContentState
    let size: CGFloat

    var body: some View {
        Text(timerInterval: state.startedAt...state.endsAt, countsDown: true, showsHours: false)
            .font(.system(size: size, weight: .black, design: .rounded))
            .foregroundStyle(Color(hex: "F3F2ED"))
            .contentTransition(.numericText(countsDown: true))
            .monospacedDigit()
    }
}

private struct RestTimerProgressView: View {
    let state: RestTimerAttributes.ContentState

    var body: some View {
        ProgressView(timerInterval: state.startedAt...state.endsAt, countsDown: false)
            .progressViewStyle(.linear)
            .tint(Color(hex: "0057B8"))
    }
}

private extension Color {
    init(hex: String) {
        var sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        sanitized = sanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&rgb)

        let red = Double((rgb & 0xFF0000) >> 16) / 255
        let green = Double((rgb & 0x00FF00) >> 8) / 255
        let blue = Double(rgb & 0x0000FF) / 255

        self.init(red: red, green: green, blue: blue)
    }
}
