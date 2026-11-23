# 365 Days Home Food Menu App

An iPhone-first Flutter application for Maharashtrian and Indian family meal planning, designed for a household of four.

## Current implementation

- Flutter application source is in `lib/main.dart`.
- Date-based daily breakfast, lunch and dinner screens.
- Recipe and ingredient reference list.
- Shopping checklist with saved checked items.
- Marathi / English interface toggle.
- Favourites.
- Strict vegetarian rule on **Monday, Thursday and Saturday** (no meat, fish or eggs in those day menus).
- Daily 7:00 PM Asia/Kolkata next-day preparation reminders, queued for the next 30 days.
- macOS GitHub Actions workflow validates the iOS release build and uploads an unsigned `.app` bundle for inspection.

## Important menu limitation

The current app uses a small starter recipe bank rotated across dates. It is **not yet a fully curated, 365-day unique menu**. Recipe instructions and ingredient quantities are also starter guidance and need a complete editorial pass before relying on them as a household meal schedule. This is stated in the app's Settings screen as well.

## Reminder behavior

The app schedules reminders for 7:00 PM India time and includes the next day's meals, ingredients, and advance-preparation notes. Android/iOS notification permissions must be granted. Android uses inexact scheduling to avoid requiring exact-alarm access. The app currently queues 30 days and refreshes that queue when opened; users should open the app periodically. Notification display length can be limited by the operating system.

## Build for iPhone

1. Open the **Actions** tab in this private repository.
2. Select **Build iPhone app**.
3. Run the workflow manually with **Run workflow**, or push a change to the iOS workflow's watched paths.
4. When the run succeeds, download the artifact named `365-days-home-food-iphone-unsigned`.

The workflow runs Flutter analysis and tests, then compiles an unsigned iOS release app on a macOS runner. An unsigned app is for build verification only; it cannot be installed directly on family iPhones. Installation and TestFlight distribution require Apple code signing, provisioning, and an Apple Developer account.

## Technology

- Flutter / Dart
- `shared_preferences` for local preferences and grocery checklist state
- `flutter_local_notifications` and `timezone` for local reminders
- No paid API or cloud service is required for the current app.

## Platform status

- **Android:** automated APK workflow is configured; check the latest Actions run for its verified result.
- **iPhone:** source is Flutter-compatible, but an iOS build has not been generated or tested. iOS compilation/signing requires macOS and Apple tooling.
- **Device testing:** notification timing, offline behavior, and screen layouts still need real-device verification.

## Food safety

Keep raw meat and fish refrigerated promptly and thaw safely in the refrigerator. Ingredient lists are planning suggestions, not medical or nutrition advice. Adjust quantities and recipes to the household's needs.


<!-- Rebuild after Android Gradle desugaring workflow correction. -->

<!-- Trigger build after Gradle dependency correction. -->
