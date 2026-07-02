# iOS SPM Migration Guide

> Booked_Mic — June 2026
> Flutter 3.46.0-0.2.pre (beta)

---

## Background: What is SPM and why does it matter?

**Swift Package Manager (SPM)** is Apple's native dependency manager, built into Xcode since Xcode 11. It resolves Swift/ObjC libraries directly from git repositories or local packages, without needing a separate tool like CocoaPods.

### CocoaPods deprecation timeline

- **April 2026**: Flutter 3.44 made SPM the **default** for iOS/macOS native dependencies
- **December 2, 2026**: The CocoaPods CDN becomes **read-only** — no new pod versions can be published
- **Future**: Flutter will eventually remove CocoaPods support entirely

This means every Flutter project needs to migrate to SPM before the deadline. Booked_Mic is already in the transition window.

### How Flutter decides: SPM vs CocoaPods

When you run `flutter build ios` or `flutter run -d ios`, Flutter:

1. Scans each plugin's `ios/` directory for a `Package.swift` file
2. **If found**: the plugin is added to the generated SPM package (`FlutterGeneratedPluginSwiftPackage`)
3. **If missing**: the plugin falls back to CocoaPods via `flutter_install_all_ios_pods` in the Podfile

A plugin's `Package.swift` must use an SPM-standard source layout (`Sources/` directory) and declare its native dependencies (e.g., `firebase-ios-sdk`) as SPM dependencies.

### The dual-resolution trap

When a plugin like `firebase_core` is installed **both** via SPM (because it has a `Package.swift`) **and** via CocoaPods (because `flutter_install_all_ios_pods` lists it), the Firebase SDK's native module map gets defined twice:

```
Redefinition of module 'Firebase'
  → ios/Pods/Firebase/CoreOnly/Sources/module.modulemap       (CocoaPods)
  → build/ios/SourcePackages/checkouts/firebase-ios-sdk/...   (SPM)
```

This was the root cause of the 32 build errors this project had. The fix: remove the explicit `pod 'Firebase/...'` lines from the Podfile, which let Flutter's build tool correctly route Firebase plugins **only** through SPM, leaving CocoaPods for the plugins that don't support SPM yet.

---

## Current SPM status (after initial fix)

| System | Plugins managed |
|---|---|
| **SPM** | `firebase_core`, `cloud_firestore`, `firebase_auth`, `cloud_functions`, `firebase_messaging`, `connectivity_plus`, `flutter_local_notifications`, `gal`, `google_sign_in_ios`, `package_info_plus`, `path_provider_foundation`, `quick_actions_ios`, `share_plus`, `shared_preferences_foundation`, `url_launcher_ios`, `wakelock_plus`, `FlutterFramework` |
| **CocoaPods** | `awesome_notifications`, `geocoding_ios`, `home_widget`, `permission_handler_apple`, `qr_code_scanner`, `sign_in_with_apple`, `simple_barcode_scanner`, `torch_light` |

The goal: move **all** plugins to SPM before the CocoaPods deadline.

---

## Migration plan

### Step 1: Update in-place plugins (6)

These plugins now have SPM-compatible versions — just bump the dependency:

| Plugin | Current | Target | Risk |
|---|---|---|---|
| `awesome_notifications` | `0.11.0` | `^0.12.0` | Low — same API, added SPM support |
| `geocoding` (→ `geocoding_ios`) | current | latest | Low — transitive update |
| `home_widget` | `0.0.1` | `^0.9.3` | **Medium** — API may have changed (0.0.1 → 0.9.x is a big jump). Review [0.9 migration guide](https://docs.page/ABausG/home_widget/migrations/0.9.0). Requires iOS 14+ (target is 16.0, safe). |
| `permission_handler` (→ `permission_handler_apple`) | current | `>=9.4.8` | Low — SPM support added in 9.4.8+ |
| `sign_in_with_apple` | `0.0.1` | `^8.1.0` | **High** — massive version jump (v0 → v8). API surface likely completely different. Must audit all call sites first. |
| `torch_light` | `0.0.1` | `^2.0.0` | Low — added SPM in 2.0.0 |

**How to do it:** Update the version constraint in `pubspec.yaml`, run `flutter pub get`, then fix any compilation errors.

### Step 2: Replace abandoned plugins (2)

These are unmaintained upstream and will never support SPM:

| Plugin | Status | Replacement |
|---|---|---|
| `qr_code_scanner` `0.2.0` | No releases in 3+ years, uses archived `MTBBarcodeScanner` | [`mobile_scanner`](https://pub.dev/packages/mobile_scanner) — uses MLKit/AVFoundation, actively maintained, SPM-compatible |
| `simple_barcode_scanner` `0.1.7` | No SPM support, limited iOS support | same — `mobile_scanner` handles both QR codes and barcodes |

**Why `mobile_scanner`:** It's the most actively maintained scanner plugin on pub.dev, supports both QR and 1D barcodes, uses Google MLKit on iOS (SPM-compatible via Firebase) and Google Play Services on Android. Two replacements become one dependency.

**Migration:** Remove `qr_code_scanner` and `simple_barcode_scanner` from `pubspec.yaml`, add `mobile_scanner: ^6.0.0`, then rewrite scanner screens.

### Step 3: Audit & synchronize existing code

- `lib/widgets/qr_scanner_overlay.dart` — already modified recently, needs `MobileScanner` API adaptation
- Search for `QrScanner`, `QrView`, `BarcodeScanner`, `SimpleBarcodeScanner` imports across `lib/`
- Search for `SignInWithApple` calls to assess the 0.0.1 → 8.x migration scope
- Search for `HomeWidget` calls to assess the 0.0.1 → 0.9.x migration scope

### Step 4: Verify

```bash
flutter pub get

# iOS — confirm zero CocoaPods fallbacks for Firebase plugins
flutter build ios --no-codesign --debug
# Check Podfile.lock — should contain NO Firebase pods

# Android — ensure nothing broke
flutter build apk --debug

# Project-wide static analysis
dart analyze --fatal-infos
```

---

## Architecture notes

### The `[CP] Embed Pods Frameworks` incident

During the initial fix, the SPM `FlutterGeneratedPluginSwiftPackage` references were manually stripped from `project.pbxproj` and the `[CP] Embed Pods Frameworks` build phase was restored. The `flutter build ios` command then **re-added** the SPM references and **removed** the CocoaPods embed phase again — and the build succeeded. This confirms that:

1. The **only necessary fix** was removing explicit Firebase pod pins from the Podfile
2. The `project.pbxproj` edits were unnecessary (and were overwritten by Flutter's build tooling)
3. Flutter's build tool correctly decides between SPM and CocoaPods per-plugin at build time

### CocoaPods is not going away overnight

Even during migration, **mixed-mode is supported**. Plugins without `Package.swift` continue working via CocoaPods with zero issues. The only risk is if a plugin resolves the **same** native SDK through both channels — which was the Firebase bug.

### `use_frameworks! :linkage => :static`

The Podfile now uses `use_frameworks! :linkage => :static` (changed from bare `use_frameworks!`). Static linkage avoids dynamic framework loading issues and is the recommended setting for Flutter iOS projects. It was also required for SPM compatibility — dynamic frameworks and SPM static packages can conflict.

---

## Quick reference: SPM-compatible alternatives

| Purpose | Current plugin | SPM-compatible replacement |
|---|---|---|
| QR scanning | `qr_code_scanner` | `mobile_scanner` |
| Barcode scanning | `simple_barcode_scanner` | `mobile_scanner` |
| Notifications | `awesome_notifications` | Update to `0.12.0` (same plugin) |
| Geocoding | `geocoding_ios` | Update to `3.1.0` (same plugin) |
| Home widget | `home_widget` | Update to `0.9.3` (same plugin) |
| Permissions | `permission_handler_apple` | Update to `9.4.8+` (same plugin) |
| Apple sign-in | `sign_in_with_apple` | Update to `8.1.0` (same plugin) |
| Torch/flashlight | `torch_light` | Update to `2.0.0` (same plugin) |
