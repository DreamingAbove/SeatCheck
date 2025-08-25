# SeatCheck iOS App – MVP Specification

## Purpose

SeatCheck helps users avoid leaving personal belongings behind in rideshares and other temporary spaces. By starting a session when you sit down and prompting you when it's time to leave, the app encourages a quick sweep of your seat and surroundings.

## Key Features

- **1‑tap session start**: Choose a preset (e.g., Ride or Custom) and a duration. A Live Activity shows session progress with an option to end early.
- **Smart end prompts**: When the timer ends or the app detects that you're no longer moving (via Core Location and Motion), Bluetooth disconnects, or you leave a geofence, a high‑priority notification reminds you to check your seat. Action buttons allow marking all items as collected, snoozing the reminder, or opening a quick camera scan.
- **Optional AR scan**: A lightweight camera view helps you visually sweep the seat; in later versions, Vision frameworks could highlight items left behind.
- **Customizable checklists**: Set common items (phone, wallet, keys, bag, charger) and reuse them for quick sessions.
- **Session history and streaks**: Local data stores sessions and can show streaks of days without losing items.

## Technical Approach

- **Platform**: iOS 16+ using SwiftUI and ActivityKit for the Live Activity.
- **Sensors**: CoreLocation (for geofence and movement), Core Motion (to detect automotive and stationary states), optional Bluetooth (to detect disconnects from car), optional camera (for AR scan).
- **Data model**: Sessions (id, preset, startAt, plannedDuration, endSignal, completed checklist items), ChecklistItem (id, title, icon), Settings (AR scan toggle, notification preferences).
- **Notifications**: Time‑sensitive local notifications with actions for mark all, scan, and snooze.
- **Permissions**: Location (when in use), Motion & Fitness (optional), Bluetooth (optional), Camera (for scan).

## Roadmap

1. **Week 1‑2** – Build basic SwiftUI shell with presets, timer and Live Activity; implement simple local notifications.
2. **Week 3** – Integrate location and motion heuristics; implement end prompts and snooze.
3. **Week 4** – Add AR scanning flow and baseline photo; build Home screen widget and Siri shortcut; polish and battery tests.
4. **V1.1+** – Expand presets (cafés, classrooms, flights), integrate object detection and difference images in scans, add calendar or map hooks, and AirTag integration.

## Considerations

- All processing is on‑device; no user accounts or cloud back‑end for the MVP.
- Emphasize low friction: starting a session should take one tap.
- Reminders rely on heuristics and user‑set timers; false positives are minimized by waiting for the user to become stationary before prompting.
