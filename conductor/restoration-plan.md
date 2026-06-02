# Plan: Restoring Missing Frontend Features

## Objective
Restore missing UI components (QR code generation, list management options, edit toggles) in the Flutter frontend, reconciling the codebase with the stable GitHub version.

## Verification of Recent Changes
- **Backend:** I deployed notification logic that triggers on Firestore spot shifts. This backend change is independent of the missing UI features.
- **Frontend:** It appears the recent "Production Transition" and "Search Icon" fixes may have introduced regressions or revealed that the local environment wasn't fully synced with the stable GitHub repository.

## Restoration Strategy
1. **GitHub Sync Analysis:** Compare the current local `lib/` directory against the stable GitHub repository (source of truth) to identify discrepancies in UI components.
2. **Missing UI Implementation:**
   - **QR Code:** Ensure `qr_flutter` (or equivalent) is used, check `show_list_screen.dart` for rendering logic.
   - **Missing Options:** Restore missing UI interactions (edit/show alternatives) in the list card component.
   - **Edit Toggles:** Verify implementation of toggles in `edit_list_screen.dart`.
3. **Validation:** Relaunch Flutter web to ensure the features are restored.

## Phase 1: Identification & Reconciliation
- [ ] List directories in `lib/` and compare with GitHub.
- [ ] Inspect `show_list_screen.dart` for QR code rendering block.
- [ ] Inspect `host_screens/edit_list_screen.dart` for missing form toggles.

## Phase 2: Implementation (Targeted Restoration)
- [ ] Restore QR widget in `show_list_screen.dart`.
- [ ] Restore missing menu options in the list card component.
- [ ] Update `edit_list_screen.dart` toggles.

## Phase 3: Final Verification
- [ ] Verify `flutter analyze` passes.
- [ ] Confirm features are visible in the web preview.
