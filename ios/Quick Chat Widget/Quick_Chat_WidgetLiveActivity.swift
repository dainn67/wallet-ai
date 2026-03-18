//
//  Quick_Chat_WidgetLiveActivity.swift
//  Quick Chat Widget
//
//  Created by Nguyễn Đại on 18/3/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct Quick_Chat_WidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct Quick_Chat_WidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: Quick_Chat_WidgetAttributes.self) { context in
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

extension Quick_Chat_WidgetAttributes {
    fileprivate static var preview: Quick_Chat_WidgetAttributes {
        Quick_Chat_WidgetAttributes(name: "World")
    }
}

extension Quick_Chat_WidgetAttributes.ContentState {
    fileprivate static var smiley: Quick_Chat_WidgetAttributes.ContentState {
        Quick_Chat_WidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: Quick_Chat_WidgetAttributes.ContentState {
         Quick_Chat_WidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: Quick_Chat_WidgetAttributes.preview) {
   Quick_Chat_WidgetLiveActivity()
} contentStates: {
    Quick_Chat_WidgetAttributes.ContentState.smiley
    Quick_Chat_WidgetAttributes.ContentState.starEyes
}
