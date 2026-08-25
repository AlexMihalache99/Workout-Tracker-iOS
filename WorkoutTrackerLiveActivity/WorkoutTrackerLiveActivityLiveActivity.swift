//
//  WorkoutTrackerLiveActivityLiveActivity.swift
//  WorkoutTrackerLiveActivity
//
//  Created by Alexandru Mihalache on 25/08/2026.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct WorkoutTrackerLiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct WorkoutTrackerLiveActivityLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutTrackerLiveActivityAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension WorkoutTrackerLiveActivityAttributes {
    fileprivate static var preview: WorkoutTrackerLiveActivityAttributes {
        WorkoutTrackerLiveActivityAttributes(name: "World")
    }
}

extension WorkoutTrackerLiveActivityAttributes.ContentState {
    fileprivate static var smiley: WorkoutTrackerLiveActivityAttributes.ContentState {
        WorkoutTrackerLiveActivityAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: WorkoutTrackerLiveActivityAttributes.ContentState {
         WorkoutTrackerLiveActivityAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: WorkoutTrackerLiveActivityAttributes.preview) {
   WorkoutTrackerLiveActivityLiveActivity()
} contentStates: {
    WorkoutTrackerLiveActivityAttributes.ContentState.smiley
    WorkoutTrackerLiveActivityAttributes.ContentState.starEyes
}
