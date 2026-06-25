# iOS Widget Implementation Guide

This document describes everything needed to add iOS home screen widgets for **Booked Mic**. It mirrors the existing Android widget architecture but uses Apple's WidgetKit (SwiftUI) on the native side.

---

## Overview

There are **two widgets** on Android, both need iOS equivalents:

| Widget | Purpose | Data | iOS Name (already set) |
|--------|---------|------|----------------------|
| **Up Next Widget** | Shows user's position in the performance queue | `list_name`, `spot_number`, `is_on_stage`, `is_up_next` | `UpNextWidget` |
| **Nearby Mics Widget** | Shows count of open mics with available spots | `nearby_count`, `nearby_city` | `NearbyMicsWidget` |

---

## Prerequisites

1. **Mac with Xcode 16+** — required for iOS development
2. **Apple Developer Account** — needed for App Groups capability
3. **Firebase iOS project** — if not already created:
   - Add iOS app in Firebase Console (bundle ID: `com.bookedmic.app`)
   - Download `GoogleService-Info.plist`
4. **Home Widget package** — `home_widget: ^0.7.0` is already in `pubspec.yaml`

---

## Step 1: Add iOS Platform to Flutter Project

```bash
cd ~/path/to/Booked_Mic
flutter create --platforms ios .
```

This creates:
- `ios/` directory with `Runner.xcworkspace`, `Podfile`, etc.
- Default iOS app scaffolding

Then run `flutter pub get` to sync dependencies, which pulls in the `home_widget` native pod.

---

## Step 2: Configure WidgetKit Extension in Xcode

The `home_widget` package provides a **Swift script** that generates a WidgetExtension target. Run:

```bash
# This generates the Swift source files for WidgetKit
# Consult home_widget docs for the exact command:
# https://pub.dev/packages/home_widget
```

**Manual alternative** (if the script doesn't suit):

1. Open `ios/Runner.xcworkspace` in Xcode
2. **File → New → Target** → Search for "Widget Extension"
3. Name: `BookedMicWidgets`, ensure "Include Configuration Intent" is **unchecked**, Language: Swift
4. **Do NOT** activate the scheme when prompted
5. The extension creates a `BookedMicWidgets` folder with `BookedMicWidgets.swift`

---

## Step 3: Configure App Groups (Shared Data)

Both the main app and the widget extension need to read/write the same `UserDefaults`:

1. In Xcode, select the **Runner** target → **Signing & Capabilities**
2. Click **+ Capability** → Add **App Groups**
3. Ensure the group matches the Dart code: `group.bookedmic.app`
4. Do the same for the **BookedMicWidgets** extension target

The Dart code already uses this group ID:

```dart
// widget_service.dart
static const String _groupId = 'group.bookedmic.app';
```

And `main.dart` sets it at startup:

```dart
HomeWidget.setAppGroupId('group.bookedmic.app');
```

---

## Step 4: Write the Widget Extension Swift Code

### UpNextWidget.swift

Create this inside the `BookedMicWidgets` extension folder:

```swift
import WidgetKit
import SwiftUI
import Intents

struct UpNextProvider: TimelineProvider {
    func placeholder(in context: Context) -> UpNextEntry {
        UpNextEntry(date: Date(), listName: "No Active List", spotNumber: "--", isOnStage: false, isUpNext: false)
    }
    
    func getSnapshot(in context: Context, completion: @escaping (UpNextEntry) -> ()) {
        let entry = loadEntry()
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<UpNextEntry>) -> ()) {
        let entry = loadEntry()
        // Refresh every 15 minutes as fallback; main app triggers immediate refresh
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(900)))
        completion(timeline)
    }
    
    private func loadEntry() -> UpNextEntry {
        let defaults = UserDefaults(suiteName: "group.bookedmic.app")
        let listName = defaults?.string(forKey: "list_name") ?? "No Active List"
        let spotNumber = defaults?.string(forKey: "spot_number") ?? "--"
        let isOnStage = defaults?.bool(forKey: "is_on_stage") ?? false
        let isUpNext = defaults?.bool(forKey: "is_up_next") ?? false
        return UpNextEntry(date: Date(), listName: listName, spotNumber: spotNumber, isOnStage: isOnStage, isUpNext: isUpNext)
    }
}

struct UpNextEntry: TimelineEntry {
    let date: Date
    let listName: String
    let spotNumber: String
    let isOnStage: Bool
    let isUpNext: Bool
}

struct UpNextWidgetEntryView: View {
    var entry: UpNextProvider.Entry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Booked Mic")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.7))
            
            Text(entry.listName)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Spacer()
            
            VStack(spacing: 2) {
                Text("YOUR SPOT")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
                
                Text(entry.spotNumber)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(Color(red: 0.39, green: 0.71, blue: 0.96))
            }
            .frame(maxWidth: .infinity)
            
            Spacer()
            
            Text(statusText)
                .font(.caption)
                .foregroundColor(Color(red: 0.39, green: 0.71, blue: 0.96))
                .italic()
                .frame(maxWidth: .infinity)
        }
        .padding()
        .containerBackground(.linearGradient(colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.4)], startPoint: .top, endPoint: .bottom), for: .widget)
        .widgetURL(URL(string: "bookedmic://upNext"))
    }
    
    private var statusText: String {
        if entry.isOnStage { return "YOU ARE ON" }
        if entry.isUpNext { return "YOU ARE UP NEXT!" }
        return "Waiting..."
    }
}

struct UpNextWidget: Widget {
    let kind: String = "UpNextWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: UpNextProvider()) { entry in
            UpNextWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Up Next")
        .description("Track your position in the queue.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
```

### NearbyMicsWidget.swift

```swift
import WidgetKit
import SwiftUI

struct NearbyMicsProvider: TimelineProvider {
    func placeholder(in context: Context) -> NearbyMicsEntry {
        NearbyMicsEntry(date: Date(), count: 0, city: "Detecting Location...")
    }
    
    func getSnapshot(in context: Context, completion: @escaping (NearbyMicsEntry) -> ()) {
        let entry = loadEntry()
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<NearbyMicsEntry>) -> ()) {
        let entry = loadEntry()
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(900)))
        completion(timeline)
    }
    
    private func loadEntry() -> NearbyMicsEntry {
        let defaults = UserDefaults(suiteName: "group.bookedmic.app")
        let count = defaults?.integer(forKey: "nearby_count") ?? 0
        let city = defaults?.string(forKey: "nearby_city") ?? "Detecting Location..."
        return NearbyMicsEntry(date: Date(), count: count, city: city)
    }
}

struct NearbyMicsEntry: TimelineEntry {
    let date: Date
    let count: Int
    let city: String
}

struct NearbyMicsWidgetEntryView: View {
    var entry: NearbyMicsProvider.Entry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Booked Mic")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.7))
            
            Text("Nearby Mics")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Spacer()
            
            VStack(spacing: 2) {
                Text("\(entry.count)")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(Color(red: 0.39, green: 0.71, blue: 0.96))
                
                Text("ACTIVE LISTS")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            
            Spacer()
            
            Text(entry.city)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.7))
                .frame(maxWidth: .infinity)
        }
        .padding()
        .containerBackground(.linearGradient(colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.4)], startPoint: .top, endPoint: .bottom), for: .widget)
        .widgetURL(URL(string: "bookedmic://nearbyMics"))
    }
}

struct NearbyMicsWidget: Widget {
    let kind: String = "NearbyMicsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NearbyMicsProvider()) { entry in
            NearbyMicsWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Nearby Mics")
        .description("See how many open mics are active.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
```

### Bundle Entry Point

Modify the auto-generated `BookedMicWidgets.swift` to register both widgets:

```swift
import WidgetKit
import SwiftUI

@main
struct BookedMicWidgetsBundle: WidgetBundle {
    var body: some Widget {
        UpNextWidget()
        NearbyMicsWidget()
    }
}
```

---

## Step 5: Ensure iOS Widget Names Match Dart Code

The `WidgetService.dart` already sets the correct iOS names:

```dart
// For Up Next widget
await HomeWidget.updateWidget(
  name: _androidWidgetName,     // 'BookedMicWidgetProvider'
  iOSName: 'UpNextWidget',       // ← must match Widget .kind in Swift
);

// For Nearby Mics widget
await HomeWidget.updateWidget(
  name: _nearbyMicsAndroidWidgetName,  // 'NearbyMicsWidgetProvider'
  iOSName: 'NearbyMicsWidget',         // ← must match Widget .kind in Swift
);
```

The iOS name string (`kind`) must exactly match the `kind` property in the Swift `Widget` struct.

---

## Step 6: Verify Deep Link Handling

Tapping the widget opens the app via `widgetURL`. On Android, tapping Nearby Mics routes to `bookedmic://nearbyMics`. `main.dart` already handles both cases:

```dart
// lib/main.dart — _setupHomeWidgetLinks()
HomeWidget.initiallyLaunchedFromHomeWidget().then((uri) {
  if (uri?.host == 'nearbyMics') {
    navigatorKey.currentState?.pushNamed('/nearbyMics');
  }
});

HomeWidget.widgetClicked.listen((uri) {
  if (uri?.host == 'nearbyMics') {
    navigatorKey.currentState?.pushNamed('/nearbyMics');
  }
});
```

On iOS, WidgetKit will call the deep link via `widgetURL`. The `home_widget` plugin catches this natively and fires the `HomeWidget.widgetClicked` stream. **No changes needed to main.dart.**

Note: The **Up Next** widget on Android launches to the app's default page (no deep link). On iOS, the suggested code above uses `widgetURL(URL(string: "bookedmic://upNext"))` — you can decide whether to handle that route or leave it as a basic app launch.

---

## Step 7: Add GoogleService-Info.plist

1. Go to **Firebase Console → Project Settings → Your apps → iOS app**
2. Download `GoogleService-Info.plist`
3. Add it to the `ios/Runner/` directory in Xcode (right-click Runner → Add Files to "Runner")
4. Ensure it's included in the Runner target (not the widget extension)

---

## Step 8: Test on Simulator

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select an iOS 17+ simulator
3. Build and run the Flutter app from Xcode (or `flutter run`)
4. Once running, go to the home screen and add widgets:
   - Long-press on the home screen → **+** → search "Booked Mic"
   - Add both **Up Next** and **Nearby Mics** widgets
5. Sign in as a performer in the app
6. Verify the widget updates within 30 seconds (heartbeat cycle)

---

## Data Flow (for reference)

```
NotificationService._fetchAndUpdateNearbyMicsWidget()
  │  (runs on 30s heartbeat + immediately on sign-in)
  ▼
WidgetService.updateNearbyMicsWidget(count:, city:)
  │
  ├── HomeWidget.saveWidgetData('nearby_count', count)
  ├── HomeWidget.saveWidgetData('nearby_city', city)
  │
  └── HomeWidget.updateWidget(iOSName: 'NearbyMicsWidget')
        │
        ▼  [writes to shared UserDefaults(suiteName: "group.bookedmic.app")]
        │
        ▼
  WidgetKit TimelineProvider reads from UserDefaults
        │
        ▼
  SwiftUI View renders the widget on the home screen
        │  (tap triggers bookedmic://nearbyMics)
        ▼
  Flutter's HomeWidget.widgetClicked stream → push /nearbyMics route
```

For **Up Next**, the trigger path is:

```
NotificationService._updateWidgetData()   ← called from Firestore snapshot listener
  │  (fires on any spot position change)
  ▼
WidgetService.updateUpNextWidget(listName:, spotNumber:, isOnStage:, isUpNext:)
  │
  └── HomeWidget.updateWidget(iOSName: 'UpNextWidget')
```

---

## Key Differences from Android Implementation

| Aspect | Android | iOS |
|--------|---------|-----|
| Update mechanism | Heartbeat polling every 30s + spot change events | TimelineProvider with fallback 15min refresh + push via `WidgetCenter.reloadTimelines()` from Flutter |
| Layout definition | XML `RemoteViews` in `res/layout/` | SwiftUI in Widget Extension |
| Widget metadata | XML in `res/xml/` | `WidgetConfiguration` in Swift |
| Data storage | `SharedPreferences` (app process only) | `UserDefaults` with App Group (shared between app and extension) |
| Deep link | `HomeWidgetLaunchIntent` with custom URI scheme | `widgetURL(_:)` or `Link` in SwiftUI |
| Background refresh | Dart 30s heartbeat timer works fine | System limits widget background updates; need to trigger from Flutter via `HomeWidget.updateWidget()` |
| Preview images | PNG in `res/drawable/` | PNG in Asset Catalog (.xcassets) |

---

## Gotchas & Pitfalls

1. **App Groups must be enabled for both Runner + Widget Extension targets** — without this, UserDefaults won't share data and the widget will always show placeholder values
2. **`kind` string must match exactly** between Dart `iOSName:` and Swift `Widget.kind` — case-sensitive
3. **iOS widgets don't auto-refresh frequently** — the 15-minute fallback in TimelineProvider exists for cold boots. Real-time updates come from `WidgetCenter.reloadTimelines()` triggered by `HomeWidget.updateWidget()` from Dart, which fires every 30s in the heartbeat
4. **`GoogleService-Info.plist` is only needed in Runner target**, not the widget extension (widget extension doesn't use Firebase directly — it reads shared UserDefaults)
5. **Widget extension runs in a separate process** — it cannot access the Flutter engine, Firestore, or any Dart code directly. All data must go through the App Group UserDefaults bridge
6. **Minimum iOS deployment target** — WidgetKit requires iOS 14+. The project's iOS target should be set to 14.0 or higher in Xcode
7. **Simulator limitations** — widgets on simulator need to be added to the home screen each session; cold boot may show placeholders until the first Flutter heartbeat fires
8. **Bundle ID consistency** — main app: `com.bookedmic.app`, widget extension will auto-generate as `com.bookedmic.app.BookedMicWidgets` — this is normal

---

## File Checklist

After completing all steps, you should have these new/modified files:

```
ios/
├── Runner.xcworkspace/                (modified — App Groups enabled)
├── GoogleService-Info.plist           (new — download from Firebase Console)
└── BookedMicWidgets/                  (new — Widget Extension target)
    ├── UpNextWidget.swift
    ├── NearbyMicsWidget.swift
    ├── BookedMicWidgetsBundle.swift
    └── Info.plist

lib/services/widget_service.dart       (already done — iOSName set)
android/                               (untouched)
```

---

## Rollback: Removing iOS from the Project

If the Widget Extension doesn't work out, remove it from Xcode, then:

```bash
# Remove entire iOS directory (Flutter will regenerate clean if needed)
rm -rf ios/
```

The Dart-side changes (`widget_service.dart`, `notification_service.dart`) are platform-guarded with `if (!kIsWeb)` and won't affect Android or Web builds.
