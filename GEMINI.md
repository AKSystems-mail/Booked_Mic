# Booked_Mic Project Context

## Project Overview
**Booked_Mic** is a comprehensive platform for managing performance lists at open mic events. It connects hosts and performers through a real-time ecosystem.

### Core Components
1.  **Mobile/Web App (Flutter):** The primary interface for performers (to sign up and track their spot) and hosts (to create and manage lists on the go).
2.  **Admin Dashboard (React):** A web-based portal for high-level administration and data management.
3.  **Backend (Firebase):**
    *   **Firestore:** Real-time NoSQL database for lists (`Lists` collection), users (`users` collection), and bucket signups.
    *   **Authentication:** Supports Email/Password and Google Sign-In.
    *   **Cloud Functions:** TypeScript-based serverless functions for secure operations like `findUserByEmail` and `manageSpotSignup`.
    *   **Emulators:** Fully configured for local development of Auth, Firestore, and Functions.

## Technical Architecture (Flutter)
- **State Management:** `Provider` pattern. `FirestoreProvider` handles the bridge between UI and `FirestoreService`.
- **Data Models:** 
    - `Show`: Represents an event/list. Includes `spots` (a Map of performer data) and `signedUpUserIds`.
- **Services:**
    - `FirestoreService`: Direct interaction with Firestore using transactions for atomic spot management.
    - `NotificationService`: Manages real-time spot updates using `awesome_notifications`.
- **Navigation:** `AuthWrapper` in `main.dart` handles routing based on `authStateChanges` and the user's saved role (`host` vs `performer`).

## Local Development & Testing

### Prerequisites
- Flutter SDK
- Node.js & npm
- Firebase CLI
- Google Maps API Key (stored in `.env`)

### Lean Local Workflow (Recommended for 8GB RAM)
1.  **Start Emulators:**
    ```bash
    firebase emulators:start --only auth,firestore,functions,ui
    ```
2.  **Run Flutter Web (Debug Mode):**
    ```bash
    flutter run -d chrome
    ```
    *Note: In debug mode, the app automatically connects to `localhost:9099` (Auth) and `localhost:8080` (Firestore).*
3.  **Run Admin Dashboard:**
    ```bash
    cd admin-dashboard && npm start
    ```

### Building for Production
- **Flutter Web:** `flutter build web`
- **Android:** `flutter build apk` or `flutter build appbundle`
- **Functions:** `cd functions && npm run build`

## Development Conventions
- **Atomic Transactions:** Always use Firestore transactions for spot signups/removals to prevent double-booking.
- **Surgical Dependencies:** Keep the 8GB MBP environment in mind; avoid adding heavy libraries unless necessary.
- **Security Compliance:** Use `npm audit` regularly. Core Firebase and Google Auth packages must be kept up to date to support modern security protocols (e.g., Google's `CredentialManager`).
- **Platform Checks:** Use `kIsWeb` for conditional logic between mobile and web-specific features (like Google Sign-In initialization).

## Key Files
- `lib/main.dart`: App entry point and Emulator connection logic.
- `lib/registration_screen.dart`: Authentication UI (compatible with `google_sign_in` 7.2.0).
- `lib/services/firestore_service.dart`: Core database logic.
- `functions/src/index.ts`: Backend business logic.
- `firebase.json`: Emulator and Firebase service configuration.
