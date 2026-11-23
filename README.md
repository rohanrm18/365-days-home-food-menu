# 365 Days Home Food Menu App

A family meal-planning app focused on Maharashtrian and Indian home cooking. The goal is to make everyday meal planning, advance preparation, and grocery shopping easier for a household of four.

## Project status

**Repository setup:** Created  
**README:** Enabled  
**Application source:** Not yet uploaded to this repository  
**Build status:** No Android APK or iOS build has been produced or device-tested yet.

This repository is the project home. Features below describe the agreed product requirements; they should not be interpreted as already implemented until the corresponding source code and tests are committed.

## Planned features

- 365-day meal calendar with breakfast, lunch, and dinner (1,095 meal slots).
- Maharashtrian and wider Indian home-food options.
- Marathi and English language support.
- Vegetarian and non-vegetarian choices on eligible days.
- **Strict vegetarian days: Monday, Thursday, and Saturday** — no meat, fish, or eggs.
- Recipes with ingredients, quantities sized for four people, and cooking instructions.
- Grocery list with controls to mark items as already available or to buy.
- Favourites and meal replacement.
- Weekly and monthly calendar views.
- Festival and family-friendly menu suggestions.
- Offline access to saved menu and recipe data.
- Simple household-friendly interface for Android and iPhone.

## Advance preparation reminder

The planned daily reminder is **7:00 PM India time (Asia/Kolkata)** and should preview the following day's:

- Breakfast, lunch, and dinner.
- Ingredients and estimated quantities for four people.
- Vegetables and any required non-vegetarian items.
- Advance tasks such as soaking, cleaning, marinating, and safe thawing.

The app should allow reminders to be enabled or disabled in settings. Notification delivery must be verified on real Android and iOS devices; operating-system permissions and battery settings can affect delivery.

## Technology direction

- **Flutter / Dart** for a shared Android and iOS application.
- Local storage for offline access.
- Local notifications for preparation reminders.

The final package choices and platform configuration will be documented after the application source is added and builds are verified.

## Development plan

1. Add the Flutter application scaffold and source.
2. Build the meal calendar, bilingual interface, recipes, and grocery list.
3. Add and validate the 7:00 PM next-day reminder flow.
4. Expand the menu into a genuinely curated 365-day plan.
5. Run automated checks and build the Android app.
6. Verify notifications, offline behavior, and usability on devices.
7. Configure and test the iOS build on macOS with the required Apple signing setup.

## Important notes

- The menu must not schedule eggs, meat, or fish on Monday, Thursday, or Saturday.
- Ingredient quantities are planning estimates, not medical or nutrition advice.
- Handle raw meat and fish safely; keep them refrigerated and thaw in the refrigerator.
- Do not mark a feature as complete until its implementation and relevant tests have been checked.

## Contributing

Development is currently managed in the project repository. When source code is added, include clear setup, test, and build instructions here.
