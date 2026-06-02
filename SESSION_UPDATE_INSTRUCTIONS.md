# Booked Mic: Session Update Instructions (April 22, 2026)

This document provides a detailed breakdown of the modernization, stability fixes, and feature implementations completed during this session. Use these instructions to replicate the state of the workspace on a primary development machine.

---

## 1. Admin Dashboard (React Modernization)
The dashboard was migrated from Create React App (CRA) to Vite for better performance and modularity.

### Technical Stack Updates
- **Build Tool:** Migrated to **Vite 6.1.0**.
- **React:** Updated to **v19.0.0**.
- **TypeScript:** Updated to **v5.7.3**.
- **UI Framework:** Upgraded to **Bootstrap 5.3.8** with **Bootstrap Icons**.
- **Animations:** Added **Framer Motion** for fluid UI transitions.

### Key Changes
- **Directory Structure:** Moved `index.html` from `public/` to the root of `admin-dashboard/`.
- **Logic Cleanup:** Removed legacy CRA files (`reportWebVitals.ts`, `setupTests.ts`, `App.css`, `logo.svg`).
- **Modularization:** 
    - Created `src/types.ts` to centralize the `Show` and `Performer` interfaces.
    - Split `Dashboard.tsx` into `Sidebar.tsx`, `ShowTable.tsx`, and `EditShowModal.tsx`.
- **Feature Enhancements:**
    - **Live Search:** Implemented real-time filtering by show name, host, or address in `ShowTable.tsx`.
    - **Full Edit CRUD:** Fully implemented the "Edit" modal with atomic Firestore updates.
    - **UI/UX Sync:** Applied the blue-to-purple gradient and "glass-card" (semi-transparent) aesthetic to match the mobile app.

---

## 2. Flutter Performance & Robustness
Refactored core list management to prevent data corruption and improve maintainability.

### Atomic Reordering (`lib/services/firestore_service.dart`)
- **Implemented `reorderRegularSpots`:** Replaced the "Get-Modify-Update" pattern with a **Firestore Transaction**.
- **Logic:** The transaction locks the document, preserves Waitlist ('W') and Bucket ('B') spots, and re-maps Regular spots to numeric keys (1, 2, 3...) based on the host's new order. This prevents concurrent performer signups from being overwritten.

### UI Modularization (`lib/host_screens/show_list_screen.dart`)
- **New Model:** Created `lib/models/spot_display_data.dart` to handle queue logic outside of the UI layer.
- **Dedicated Widget:** Created `lib/widgets/performer_spot_card.dart` to encapsulate the complex list tile logic (Dismissible, Bucket animation, "Set Over" styling).
- **Complexity Reduction:** Reduced `show_list_screen.dart` from ~1,180 lines to a much cleaner structure using private builders for list sections.

---

## 3. Flutter Web Stability Fixes
Resolved critical initialization and rendering errors on the web platform.

### Core Fixes
- **Multiple Initialization Error:** Added a `static bool _isGoogleSignInInitialized` flag in `lib/registration_screen.dart` to ensure `google_sign_in.initialize()` is only called once.
- **`removeChild` of Null Error:** Fixed by overhauling `web/index.html`. Removed the manual JavaScript loader and used the standard `flutter-first-frame` event listener to cleanly remove the loading spinner once the engine is ready.
- **Plugin Safety:** Wrapped all `AwesomeNotifications` and `HapticFeedback` logic in `!kIsWeb` guards to prevent the web engine from crashing on mobile-only APIs.

---

## 4. Feature: Real-Time Queue Status
Implemented a "Physical + Visual" notification system for performers.

### Notification Logic (`lib/services/notification_service.dart`)
- **Queue Tracker:** The service now listens to signed-up lists and calculates the performer's distance from the stage based strictly on **Regular Spots**.
- **Directional Alerts:** Notifications only trigger when the performer moves **forward** in the queue.
- **Vibration:** Every move forward triggers a `HapticFeedback.heavyImpact()` vibration.

### UI Confirmation Banner (`lib/performer_screens/performer_list_screen.dart`)
- **Acknowledge-able Banner:** Added a `ValueListenableBuilder` that displays a top-positioned banner (Blue for general, Orange for "UP NEXT").
- **Persistence:** The banner stays visible until the user taps **"GOT IT"**, ensuring they don't miss their update even if they missed the vibration.

---

## 5. Android Build Environment
Upgraded the build toolchain to support modern dependency requirements.

### Version Upgrades
- **Android Gradle Plugin (AGP):** Upgraded from `8.7.0` to **`8.9.1`** (`android/settings.gradle.kts` and `android/build.gradle.kts`).
- **Gradle Wrapper:** Upgraded from `8.10.2` to **`8.11.1`** (`android/gradle/wrapper/gradle-wrapper.properties`).
- **Kotlin:** Maintained at `2.2.20`.

### Troubleshooting Note
The `gradle.user.home` property was removed from `android/gradle.properties` to resolve path/permission issues on macOS environments.

---
**End of Instructions**
