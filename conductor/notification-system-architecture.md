# Notification System Architecture

> **Last updated:** 2026-06-27
> **Scope:** FCM (Cloud Function) + Flutter local notifications + home screen widgets

---

## Overview

Booked_Mic uses a **dual-path notification system** — both paths are independently capable of alerting a performer about their position changes:

| Path | Trigger | Scope | Used for |
|------|---------|-------|----------|
| **Cloud Function (FCM)** | `onDocumentUpdated` on `Lists/{listId}` | Background — works when app is killed or backgrounded | Spots 3+ reorder/shift/isOver advance |
| **Flutter Local** | Firestore snapshot listener in `NotificationService` | Foreground — app must be running | Spot 2 "You're up next!" + stage arrival |

---

## Cloud Function Path (`functions/src/index.ts`)

### Trigger

`onDocumentUpdated("Lists/{listId}")` — fires on every write to any `Lists` document.

### Decision Tree

```
Write to Lists/{listId}
│
├── Main spot removed? (key "1"..N exists in before, absent in after)
│   └── YES → Perform Shifts (move spots up, promote W1, notify shifted performers)
│
└── NO (no removal)
    │
    ├── isOver transition detected? (any spot has isOver change false→true)
    │   └── YES → Notify remaining performers with decreased Ahead Count
    │
    └── NO isOver → Reorder detected? (same userId found at different Spot Key)
        └── YES → Notify reordered performers with new spot number
```

### Notification Content by Event

| Event | Body | FCM for | Skipped |
|-------|------|---------|---------|
| **isOver advance** (Ahead Count decreased) | `N ahead of you.` | All spots where `newAhead > 0` | Stage (ahead=0) — performer is live |
| **Reorder** (same user, new key) | `Moved to spot #N` | Spots 3+ | Spot 1 (stage) + Spot 2 (up next — local notification handles it) |
| **Shift** (waitlist promotion / spot deletion) | `Moved to spot #N • N-1 ahead of you.` | Spots 3+ | Spot 1 (stage) + Spot 2 (up next — local notification handles it) |

### Key Details

#### isOver Guard (line 171)
```typescript
if (newValue.isOver === true || ('userId' in newValue && newValue.userId))
```
- A spot must have **either** `userId` (for FCM) or `isOver === true` (for the isOver transition itself).
- **Bug fix (2026-06-26):** Spots from host-code signups may lack a `userId` field entirely. The original guard `'userId' in newValue && newValue.userId` would skip them, silently missing isOver detection. Fixed by adding `newValue.isOver === true` as an alternative entry condition.

#### Ahead Count Calculation
```typescript
function countActiveAhead(spots: any, key: string): number
```
- Counts ACTIVE (non-isOver) performers with a lower Spot Key.
- Spot 1 → Ahead Count 0 (On Stage)
- Spot 2 → Ahead Count 1 (Up Next)
- Spot N → Ahead Count N−1

#### Stage/Up Next Skip Logic
Both isOver advance and reorder/shift paths skip FCM for:
- **Spot 1 (ahead=0):** Performer is live on stage — no notification needed.
- **Spot 2 (ahead=1):** Handled by Flutter local notification — skip FCM to avoid double-notification.

#### Shift Process (`onListUpdateShiftSpots`)
When a main list spot is removed, the function:
1. Shifts all higher-numbered main spots up (key N → key N-1)
2. Promotes first waitlist spot W1 into the vacated main spot
3. Shifts remaining waitlist spots up (WN → WN-1)
4. Sends FCM notifications to every performer whose spot changed

---

## Flutter Local Notification Path (`lib/services/notification_service.dart`)

### Trigger

Firestore snapshot listener on `Lists` collection, filtered by `signedUpUserIds` array-contains the current user's UID.

### Detection Logic (`_updateAndNotifyPositions`)

1. Walks Spot Keys 1..numRegular, counting non-isOver performers as "ahead"
2. Finds the user's spot by matching `userId` 
3. Computes current position (0 = on stage)
4. Compares with last-notified position from SharedPreferences

### When Local Notifications Fire

| Condition | Action |
|-----------|--------|
| First snapshot for a list | Set baseline position in SharedPreferences (no notification) |
| Position improved to **Spot 2** (ahead=1) **and** last notified > 1 ahead | `_showCustomPositionNotification` with "You're up next!" banner |
| Position improved but still > Spot 2 | Fire position notification (non-critical, in-app banner) |
| Position improved to **Spot 1** (stage) **and** last notified > 1 ahead | Fire critical "You're up next!" as last non-silent notification |
| Missed advancement detection | Guards against Android listener suspension — if app was backgrounded and reconnects to final state, fires the appropriate catch-up notification |

### Widget System

`NotificationService` also manages two Android home screen widgets via `WidgetService`:

- **Up Next Widget:** Updated every 30s heartbeat — shows list name, spot number, on-stage/up-next status
- **Nearby Mics Widget:** Updated every 30s — counts open mics in the user's state

### Helper Methods

- `_logDiag()` — writes to `diagnostics/{uid}/snapshots/{listId}` for debugging
- `_loadLastNotifiedPosition()` / `_saveLastNotifiedPosition()` — SharedPreferences persistence
- `dismissBanner()` — clears the in-app banner
- `stopListening()` — cancels subscription and timers

---

## Notification Flow Summary

```
                    ┌──────────────────────────────────┐
                    │  Host modifies list  │
                    │  (mark over, reorder, delete)     │
                    └──────────┬───────────────────────┘
                               │
                    ┌──────────▼──────────┐
                    │  Firestore write     │
                    │  to Lists/{listId}    │
                    └──────────┬──────────┘
                               │
              ┌────────────────┼────────────────┐
              ▼                                 ▼
    ┌───────────────────┐          ┌─────────────────────────┐
    │ Cloud Function    │          │ Flutter Snapshot Listener│
    │ (background)      │          │ (foreground / active app)│
    │ FCM → Notification│          │ Local Notification       │
    │ even if app killed │          │ (in-app / banner)        │
    └───────────────────┘          └─────────────────────────┘
```

> **Note:** The Flutter listener fires for ALL lists the user is signed up for. It independently tracks position and fires local notifications. Both paths can fire for the same event — the skip logic (no FCM for spots 1-2) prevents double-alerting for nearby performers.

---

## Recent Fixes (2026-06-27)

### 1. isOver Guard for userId-less Spots
- **File:** `functions/src/index.ts` line 173
- **Before:** `'userId' in newValue && newValue.userId`
- **After:** `newValue.isOver === true || ('userId' in newValue && newValue.userId)`
- **Why:** Host-code signups produce spots without a `userId` field. The original guard would skip them entirely, preventing isOver detection for spots 1-7 in the test list.
- **Verification:** Spots 4-5 were not receiving isOver-cascade notifications because their predecessors lacked `userId`. After this fix, the cloud function correctly processes isOver transitions regardless of userId presence.

### 2. isOver Notification Body Text
- **File:** `functions/src/index.ts` line 198
- **Before:** `const body = \`${newAhead} ahead\`;`
- **After:** `const body = \`${newAhead} ahead of you.\`;`
- **Why:** More natural phrasing for performer-facing notifications.
- **Status:** Deployed (v12 function build).

### 3. isOver FCM Skip Threshold
- **File:** `functions/src/index.ts` line 195
- **Before:** `if (newAhead <= 1)` — skipped spots with ahead=1 (spot 2)
- **After:** `if (newAhead <= 0)` — only skip stage (ahead=0)
- **Why:** Spot 2 now gets FCM because the Flutter local notification may not fire when the app is backgrounded.
- **Note:** Reorder path skips spots 1–2 separately; shift path also skips spots 1–2.

### 4. List Setup Screen — Title Capitalization
- **File:** `lib/host_screens/list_setup_screen.dart` line 207
- **Added:** `textCapitalization: TextCapitalization.sentences`, `textInputAction: TextInputAction.next`, `onFieldSubmitted: (_) => _addressFocusNode.requestFocus()`
- **Why:** Auto-capitalizes first letter of the list name; keyboard "Next" button moves focus to address field; pressing done on title keyboard moves to address.

### 5. List Setup Screen — Address Field Cursor Jump Fix
- **File:** `lib/host_screens/list_setup_screen.dart` 
- **Added:** `focusNode: _addressFocusNode` to `GooglePlaceAutoCompleteTextField` (line 215); `_addressFocusNode.requestFocus()` after `setState` in `getPlaceDetailWithLatLng` (line 234)
- **New FocusNode:** Declared at line 35, disposed at line 53
- **Why:** When a user tapped an autocomplete suggestion, `setState()` in the callback would cause a rebuild that moved focus back to the title field. Refocusing the address node prevents this cursor jump.

### 6. Shift FCM Wording — \`ahead\` → \`ahead of you.\`
- **File:** `functions/src/index.ts` line 375
- **Before:** `body = \`Moved to spot #${spotKey} • ${parseInt(spotKey) - 1} ahead\`;`
- **After:** `body = \`Moved to spot #${spotKey} • ${parseInt(spotKey) - 1} ahead of you.\`;`
- **Why:** Consistent with isOver advance wording — full natural phrasing for performer-facing notifications.
- **Status:** Deployed (v12 function build).

### 7. Foreground Banner Fix — \`ahead\` → \`ahead of you.\`
- **File:** `lib/services/notification_service.dart` line 371
- **Before:** `body = "Moved to spot #${currentPositionIndex + 1} • ${currentPositionIndex} ahead";`
- **After:** `body = "${currentPositionIndex} ahead of you.";`
- **Why:** Removed spot number from foreground banner (consistent with FCM advance path); uses "ahead of you." for natural phrasing.
- **Note:** Spot #0 (stage) silently returns with no banner or notification. Spot #1 (up next) still fires "You're up next!" banner + locked local notification. Spot #2+ shows "N ahead of you." banner only (no local notification — FCM handles background).

### 8. Shift FCM Stage/Up Next Skip
- **File:** `functions/src/index.ts` lines 250, 368
- **Added:** Skip FCM for spots 1 and 2 in both reorder and shift paths (previously only reorder skipped them).
- **Why:** Prevent double-notification: spot 1 (stage) needs no alert, spot 2 (up next) is handled by Flutter local notification.
- **Status:** Deployed (v12 function build).

---

## Testing Instructions

### Prerequisites
- Host device with debug APK (v10+) installed
- Performer device with same UID: `fZlkU1nMAxOBNh4Qjpj7KE7yViO2`
- Test list: `Start Fresh Mic` (ID: `Lists/K5wXGJra6RxgjV2y9gVR`)
- 8 performers signed up (spots 1-7: host-code, spot 8: logged-in user)

### Test Scenarios

| Scenario | Action on Host | Expected Result |
|----------|---------------|-----------------|
| Reorder (spot 3+) | Move spot 8 → spot 3 | FCM: "Moved to spot #3" on performer phone |
| Reorder (spot 2) | Move spot 8 → spot 2 | Local notification: "You're up next!" — NO FCM |
| isOver advance | Mark spot 1 Over | FCM to spots 3+: "2 ahead of you." / "1 ahead of you." |
| Spot deletion + shift | Delete spot 1 | FCM to shifted performers: "Moved to spot #N • N-1 ahead of you." |
| Foreground banner | Sign in as performer, watch list advance | Banner reads "N ahead of you." — no spot number, no notification popup |
| Title capitalization | Type list name | First letter of each sentence auto-capitalized |
| Address cursor jump | Type address, tap suggestion | Address field retains focus after selection |

### Cloud Function Logs
```bash
cd functions && npm run logs
# Search for [listId] entries to trace each notification decision
```

### Diagnostics Collection
Check `diagnostics/{uid}/snapshots/{listId}` in Firestore for Flutter-side diagnostic entries.

---

## Edge Cases & Notes

- **Android listener suspension:** When the app is backgrounded, Android may suspend the snapshot listener. On reconnection, the app gets the final state but misses intermediate advancements. The missed-advancement guard (`currentPositionIndex == 0 && lastNotifiedPosition > 1`) fires a catch-up notification.
- **No double notifications:** The cloud function skips FCM for spots 1-2 in ALL paths (isOver, reorder, shift). The Flutter listener fires local notifications for these spots. The two paths don't conflict for spots 3+ — the FCM arrives whether or not the app is running.
- **Host-code spots lack userId:** Host-code signups create spots with only `name` and `isOver`. These spots cannot receive FCM (no tokens). They are still processed correctly for isOver detection and ahead-count calculations.
- **Desktop widget:** Reads Firestore directly — unaffected by notification logic.
