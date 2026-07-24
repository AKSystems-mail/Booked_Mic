# Test Checklist

## 1. Cold Start & Auth

- [ ] App launches without crash (spinner shown while auth settles)
- [ ] Returning user auto-restores session & skips login
- [ ] Registration screen renders Email, Google, Apple buttons
- [ ] Sign in with Email — new user (creates account, navigates to role selection)
- [ ] Sign in with Email — returning user (fetches existing profile)
- [ ] Sign in with Google — first time (creates user doc, shows host code)
- [ ] Sign in with Google — returning (no duplicate doc, shows host code)
- [ ] Sign in with Apple — first time (creates user doc, shows host code)
- [ ] Sign in with Apple — returning (no duplicate doc, shows host code)

## 2. Role Selection & Host Code

- [ ] Role selection screen appears after auth
- [ ] Tapping "Host" saves role, navigates to CreatedListsScreen
- [ ] Tapping "Performer" saves role, navigates to PerformerListScreen
- [ ] Host code displays (or shows "GENERATING CODE...")
- [ ] Host code resolves within ~15 seconds (no permanent stuck state)
- [ ] Retry button appears if host code fails → tapping it generates code

## 3. Host — List Management

- [ ] CreatedListsScreen shows existing lists (or empty state)
- [ ] Create new list: fills all fields, saves successfully
- [ ] New list appears immediately via Firestore stream
- [ ] Edit list: changes persist after save
- [ ] Delete list: confirm dialog → list removed
- [ ] Switch Role → goes back to RoleSelectionScreen
- [ ] Sign Out → returns to RegistrationScreen

## 4. Host — Live List

- [ ] Show List: opens with spots displayed correctly
- [ ] Manual name entry: spot shows name
- [ ] Mark Over: performer marked, remaining performers notified
- [ ] Reorder spots: performers move, positions update
- [ ] Waitlist promotion: when main spot opens, W1 moves up
- [ ] Download QR: saves image (web/mobile)
- [ ] Bucket draw: assigns random bucket performer to spot

## 5. Performer — Signup

- [ ] PerformerListScreen loads nearby/searchable lists
- [ ] State filter works (shows only matching lists)
- [ ] Tap list → navigates to signup screen
- [ ] Sign up for a spot: appears in correct position
- [ ] Reorder own position: moves to new spot
- [ ] Remove self: spot clears, other spots shift

## 6. Host Code Lookup

- [ ] Another user can search by host code
- [ ] Finds the correct host's lists
- [ ] Invalid code shows "not found" error

## 7. QR Scanner

- [ ] Scanner opens from performer screen
- [ ] Scanning a valid list QR navigates to signup
- [ ] Scanning again does not crash (single-fire fix)
- [ ] Camera released after scan (no blank screen on pop)

## 8. Push Notifications

- [ ] FCM registered on sign-in (fcmTokens stored)
- [ ] Spot shift: affected users get push notification
- [ ] App in foreground: haptic vibration + local notification on spot_update
- [ ] Sign out: tokens cleaned up (no phantom pushes)

## 9. Account & Session

- [ ] Delete account — Email user: re-auth password dialog → doc + auth deleted → back to registration
- [ ] Delete account — Google user: re-auth via Google sign-in → doc + auth deleted
- [ ] Delete account — Apple user: re-auth via Apple credential sheet → doc + auth deleted
- [ ] Sign Out → session cleared → next cold start shows login
- [ ] Switch Role multiple times without crash

## 10. Cross-Cutting

- [ ] No "HOST CODE: null" or permanent "GENERATING CODE..." without retry
- [ ] No red snackbar errors during normal navigation
- [ ] Hot restart / cold start restores previous session & role
- [ ] Test on real device (not just simulator) for camera + Apple Sign In
- [ ] Release build archive succeeds
