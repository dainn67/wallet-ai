# PRD: iOS Quick Chat Widget Implementation
**App ID:** `com.example.walletAi`
**Widget ID:** `com.example.walletAi.Quick-Chat-Widget`
**App Group:** `group.com.example.walletAi`

---

## 1. Objective
Enable users to view their last AI chat snippet and launch directly into the AI Chat interface from the iPhone Home Screen using a native iOS Widget.

## 2. Technical Stack
- **Flutter Framework:** Main application logic.
- **SwiftUI & WidgetKit:** Native iOS Widget UI.
- **Communication:** `home_widget` package using `UserDefaults` via **App Groups**.
- **Navigation:** Custom URL Scheme (`walletai://chat`) for deep linking.

---

## 3. Requirements & Architecture

### 3.1 Data Flow
1. **Flutter Side:** When a new chat message is received/sent, the app saves the string to `group.com.example.walletAi`.
2. **Native Side:** The SwiftUI Widget reads from the same App Group container.
3. **Trigger:** Flutter calls `HomeWidget.updateWidget` to notify iOS to redraw the widget.

### 3.2 Deep Linking
- **URL Scheme:** `walletai://`
- **Route:** `chat`
- **Action:** Tapping the widget must trigger `walletai://chat`, which the Flutter app handles to navigate to the chat screen.

---

## 4. Implementation Checklist for AI Agent

### Phase 1: Flutter Dependencies & Config
- [ ] Add `home_widget: ^0.7.0` to `pubspec.yaml`.
- [ ] Add URL Scheme to `ios/Runner/Info.plist`:
  ```xml
  <key>CFBundleURLTypes</key>
  <array>
      <dict>
          <key>CFBundleURLSchemes</key>
          <array>
              <string>walletai</string>
          </array>
      </dict>
  </array>
Phase 2: Native iOS Setup (Xcode)
[ ] Create a new Widget Extension target named QuickChatWidget.

[ ] Set the "Product Bundle Identifier" to com.example.walletAi.Quick-Chat-Widget.

[ ] App Groups: Add the App Groups capability to both Runner and QuickChatWidget targets using ID: group.com.example.walletAi.

Phase 3: SwiftUI Implementation (QuickChatWidget.swift)
[ ] Define WidgetData struct to decode JSON/UserDefaults.

[ ] Implement Provider (TimelineProvider) to read from UserDefaults(suiteName: "group.com.example.walletAi").

[ ] Create the View:

Display "Quick Chat" title.

Display last_chat_message key.

Wrap the view in a Link(destination: URL(string: "walletai://chat")!).

Phase 4: Flutter Service Layer
[ ] Create lib/services/widget_service.dart:

Dart
import 'package:home_widget/home_widget.dart';

class WidgetService {
  static const String groupID = 'group.com.example.walletAi';
  static const String iOSWidgetName = 'Quick-Chat-Widget';

  static Future<void> updateChatSnippet(String message) async {
    await HomeWidget.setAppGroupId(groupID);
    await HomeWidget.saveWidgetData('last_chat_message', message);
    await HomeWidget.updateWidget(iOSName: iOSWidgetName);
  }
}
5. UI/UX Design Constraints
Small Widget: Display Icon + "Last Chat" + 2 lines of message text.

Medium Widget: Display Icon + "Quick Chat" + 4 lines of message text + "Continue" button.

Empty State: If no message exists, display "Start a new conversation."

6. Security & Privacy
Do not store sensitive wallet keys or balances in the Widget UserDefaults.

Only store non-sensitive chat snippets or AI responses.