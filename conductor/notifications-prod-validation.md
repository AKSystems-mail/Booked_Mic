# Plan: Implementing Performer Notifications in Production

## Objective
Implement and validate reliable "Up Next" and "Queue Position" notifications for performers, transitioning away from unstable local Flutter web testing to a robust development-to-production workflow.

## Background & Motivation
The current Flutter web preview environment is proving unreliable (API key issues, browser restrictions, environment drift). Since Booked_Mic is a live application, we need to test backend-driven notification logic (Firestore triggers + Cloud Functions) in a way that doesn't disrupt real performers but allows for accurate verification.

## Scope & Impact
- Implementation of `onListUpdateShiftSpots` Firestore trigger logic.
- Validation of notification delivery (Firebase Cloud Messaging).
- Zero disruption to production users.

## Proposed Strategy: "Staging-via-Project-Isolation"
Instead of local testing against live production data, we will use a **Firebase Project-Based Staging Environment**.

1.  **Project Duplication (Optional/Recommended):** Create a 'BookedMic-Staging' project to mirror production data.
2.  **Notification Hardening:** Refactor notification delivery to ensure it handles state transitions (e.g., spot index shifts) correctly.
3.  **Production-Safe Testing:** Use a dedicated "Test List" in the production project to verify notification dispatch without triggering global events.

## Implementation Plan

### Phase 1: Environment Setup
- [ ] Create/Configure a dedicated staging Firebase project (if desired, or use a "Test" list in Production).
- [ ] Ensure `.env` is correctly populated for the staging/test environment.

### Phase 2: Logic Refactoring (Backend & Frontend)
- [ ] **Backend:** Review `functions/src/index.ts` (specifically `onListUpdateShiftSpots`) to ensure notification triggers are atomic.
- [ ] **Frontend:** Harden `firestore_provider.dart` and `notification_service.dart` to handle FCM token updates and display logic.

### Phase 3: Validation
- [ ] Deploy functions to staging/production.
- [ ] Conduct live tests using a dedicated "Test Event" list.
- [ ] Verify notification receipt on physical devices.

## Verification
- FCM Logs: Monitor Cloud Functions logs for successful trigger dispatch.
- Device Testing: Verify that notifications arrive on target devices with the correct "people ahead" count.

## Rollback Strategy
- Cloud Functions: Keep previous stable versions deployed; use `firebase functions:rollback` if new logic introduces regressions.
- Frontend: Maintain stable GitHub codebase; deploy only after successful staging verification.
