# Interpreter Assistance App

A Flutter application designed to assist interpreters by translating written or typed symbols and text into a transcript. The application will use a customizable glossary and symbol set to provide accurate and real-time translations.

## Features

*   **User Authentication:** A simple login screen to secure access to the application.
*   **Dashboard:** A main page with a navigation drawer for easy access to different features.
*   **Glossary:** A dedicated screen for managing a glossary of terms and their translations.
*   **Symbols:** A screen for managing the set of recognized symbols.
*   **Cross-Platform:** Built with Flutter to support iOS, Android, Web, and desktop platforms from a single codebase.

## Getting Started

### Prerequisites

*   [Flutter SDK](https://flutter.dev/docs/get-started/install)

### Running the Application

1.  Clone the repository:
    ```sh
    git clone <repository-url>
    ```
2.  Navigate to the project directory:
    ```sh
    cd Senior-Project
    ```
3.  Install the dependencies:
    ```sh
    flutter pub get
    ```
4.  Run the application:
    ```sh
    flutter run
    ```

## Project Structure

```
lib/
├── main.dart               # App entry point
└── screens/
    ├── splash_screen.dart    # Initial screen shown on app load
    ├── login_screen.dart     # Handles user authentication
    ├── main_page.dart        # The main dashboard after login
    ├── glossary_screen.dart  # Displays the glossary of terms
    └── symbols_screen.dart   # Displays the list of symbols
```

## Future Development

*   Implement the core translation functionality.
*   Connect to a backend service for user management and data storage.
*   Develop the UI for the glossary and symbols screens.
*   Implement the writing/drawing canvas for symbol input.