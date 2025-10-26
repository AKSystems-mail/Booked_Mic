# Project Overview

This is a Flutter-based mobile application called "Booked Mic" with a React-based web admin dashboard and a Firebase backend.

**Mobile App (Flutter):**

*   **Purpose:** The mobile app appears to be for performers and hosts at events. Performers can likely see their position on a list, and hosts can manage these lists.
*   **Technologies:**
    *   Flutter for the cross-platform mobile application.
    *   Firebase for backend services:
        *   **Firestore:** As a database.
        *   **Firebase Authentication:** For user management.
        *   **Firebase Cloud Functions:** For backend logic.
    *   `provider` for state management.
    *   `awesome_notifications` for local notifications.
    *   `google_sign_in` for authentication.
    *   Other dependencies for handling device features like camera, flashlight, and permissions.

**Admin Dashboard (React):**

*   **Purpose:** A web-based dashboard for administrators to manage the application's data.
*   **Technologies:**
    *   React for the user interface.
    *   `firebase` for interacting with the Firebase backend.
    *   `react-router-dom` for routing.
    *   `bootstrap` for styling.

**Backend (Firebase Cloud Functions):**

*   **Purpose:** To host the backend logic for the application.
*   **Technologies:**
    *   Node.js with TypeScript.
    *   `firebase-admin` and `firebase-functions` for interacting with Firebase services.

# Building and Running

**Flutter App:**

To run the Flutter app, you will need to have the Flutter SDK installed.

1.  **Install dependencies:**
    ```bash
    flutter pub get
    ```
2.  **Run the app:**
    ```bash
    flutter run
    ```

**Admin Dashboard:**

To run the admin dashboard, you will need to have Node.js and npm installed.

1.  **Navigate to the `admin-dashboard` directory:**
    ```bash
    cd admin-dashboard
    ```
2.  **Install dependencies:**
    ```bash
    npm install
    ```
3.  **Start the development server:**
    ```bash
    npm start
    ```

**Firebase Functions:**

To deploy or test the Firebase Functions, you will need to have the Firebase CLI installed.

1.  **Navigate to the `functions` directory:**
    ```bash
    cd functions
    ```
2.  **Install dependencies:**
    ```bash
    npm install
    ```
3.  **Build the TypeScript code:**
    ```bash
    npm run build
    ```
4.  **Run the functions in the emulator:**
    ```bash
    npm run serve
    ```
5.  **Deploy the functions:**
    ```bash
    npm run deploy
    ```

# Development Conventions

*   The project follows the standard Flutter and React project structures.
*   The Flutter app uses the `provider` package for state management.
*   The backend Firebase Functions are written in TypeScript.
*   The admin dashboard is a standard Create React App.
