# LinguaFlow - Interpreter Assistance App

Welcome to LinguaFlow! This is a Flutter application designed to assist interpreters by recognizing handwritten symbols and providing real-time translations based on a personal, cloud-synced glossary.

## ✨ Features

*   **Cloud-First:** All of your notes, glossary terms, and user data are synced to the cloud using Firebase, allowing for a seamless experience across devices.
*   **User Authentication:** Secure login and registration powered by Firebase Authentication.
*   **Real-time Symbol Recognition:** Draw symbols on the canvas, and the app will recognize and translate them based on your glossary.
*   **Digital Notebook:** A multi-page notebook to draw and take notes, which are automatically saved to the cloud.
*   **Customizable Glossary:** A dedicated screen for managing your personal glossary. Add, edit, and delete terms, definitions, and their corresponding handwritten symbols.
*   **Cross-Platform:** Built with Flutter to support iOS, Android, and Web from a single codebase.

## 🛠️ Technology Stack

*   **Framework:** Flutter
*   **Backend & Database:** Google Firebase
    *   **Authentication:** Firebase Authentication (Email & Password)
    *   **Database:** Cloud Firestore

## 🚀 Getting Started

Follow these instructions to get the project set up and running on your local machine for development and testing.

### 1. Prerequisites

*   **Flutter SDK:** Make sure you have the Flutter SDK installed. For installation instructions, see the [official Flutter documentation](https://flutter.dev/docs/get-started/install).
*   **Android Studio:** Required for the Android emulator and build tools.
*   **A Google Account:** For creating and managing the Firebase project.

### 2. Firebase Setup (Crucial)

This application requires a Firebase project to function.

1.  **Create a Firebase Project:**
    *   Go to the [Firebase Console](https://console.firebase.google.com/).
    *   Click "Add project" and follow the on-screen instructions.

2.  **Create a Firestore Database:**
    *   In your new project, go to the **Firestore Database** section in the left-hand menu.
    *   Click **Create database**.
    *   Select **Start in test mode**. This allows the app to write data during development.
    *   Choose a location for your database and click **Enable**.

3.  **Enable Authentication:**
    *   Go to the **Authentication** section.
    *   Click the **Sign-in method** tab.
    *   Click on **Email/Password** and enable it.

4.  **Register the Android App:**
    *   Go back to your Project Overview and click the Android icon (`</>`) to add an Android app.
    *   The **Package name** must be `com.example.senior_project`.
    *   Follow the on-screen steps. When prompted, download the `google-services.json` file and place it in the `android/app/` directory of this project.

5.  **Add SHA Fingerprints:**
    *   Firebase needs your computer's signature (SHA key) to allow authentication from your local machine.
    *   Open a terminal and navigate to the `android` directory of the project.
    *   Run the command: `.\gradlew signingReport`.
    *   **Troubleshooting:**
        *   If it says `.\gradlew is not recognized`, make sure you are in the `android` directory, not `android/app`.
        *   If it says `JAVA_HOME is not set`, run this command first (for PowerShell): `$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"`, then try the `signingReport` command again.
    *   The command will output several keys. Copy the **SHA-1** and **SHA-256** keys for the `debug` variant.
    *   In the Firebase console, go to **Project Settings** (the gear icon) > **Your apps**.
    *   Add both the SHA-1 and SHA-256 keys as fingerprints.

6.  **Update `google-services.json`:**
    *   After adding the SHA keys, a new configuration file is generated. Download the `google-services.json` file again from your Firebase project settings and replace the old one in `android/app/`.

### 3. Running the Application

1.  **Clone the repository:**
    ```sh
    git clone <repository-url>
    ```
2.  **Navigate to the project directory:**
    ```sh
    cd Senior-Project
    ```
3.  **Install the dependencies:**
    ```sh
    flutter pub get
    ```
4.  **Run the application:**
    *   Make sure an Android emulator is running.
    *   Run the command:
    ```sh
    flutter run
    ```

## 📖 How to Use the App

1.  **Login/Register:** Create an account or log in. Your session is saved securely.
2.  **Main Canvas:** The main screen is a digital notebook. You can draw freely on the canvas. Your strokes are automatically saved. Use the buttons to navigate between pages or create new ones.
3.  **Glossary:** Access the Glossary from the side menu. Here you can add new words, their translations, and draw the symbol you want to associate with them.
4.  **Symbol Recognition:** As you draw on the main canvas, the app will attempt to recognize the symbols you draw and display the corresponding translation from your glossary.
