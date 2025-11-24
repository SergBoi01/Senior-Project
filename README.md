# Interpreter Assistance App

A Flutter application designed to assist interpreters by translating written or typed symbols and text into a transcript. The application will use a customizable glossary and symbol set to provide accurate and real-time translations.

## Features

*   **User Authentication:** A simple login screen to secure access to the application.
*   **Dashboard:** A main page with a navigation drawer for easy access to different features.
*   **Library System:** Organize glossaries in folders and subfolders for better management.
*   **Glossary Management:** Create and edit glossaries with English, Spanish, Definition, and Synonym fields.
*   **Symbol Drawing:** Draw custom symbols for glossary entries using an interactive canvas.
*   **CSV Import:** Bulk import glossary entries from CSV files with flexible column mapping.
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

## Using CSV Import

You can quickly populate a glossary by importing data from a CSV file:

1. **Prepare your CSV file** with columns for English, Spanish, Definition, and Synonym
   - See `sample_glossary.csv` for an example format
   - Your CSV can have any column names and any number of columns

2. **Navigate to a folder** in the Library screen

3. **Click the + button** and select "Import from CSV"

4. **Choose your CSV file** from the file picker

5. **Map your columns:**
   - Use the dropdown menus to specify which column contains English, Spanish, Definition, etc.
   - Map at least one column (can be any combination you want)
   - All fields are flexible - import with just one column or all four
   - Set unused columns to "Ignore"

6. **Enter a glossary name** and click "Import Glossary"

7. **Handle duplicates** if any are detected:
   - Import all entries (including duplicates)
   - Skip duplicate entries
   - Cancel the import

### CSV Format Example

```csv
English Word,Spanish Word,Definition,Synonym
Hello,Hola,A greeting used when meeting someone,Hi
Goodbye,Adiós,A farewell expression,Bye
Thank you,Gracias,Expression of gratitude,Thanks
```

## Project Structure

```
lib/
├── main.dart                           # App entry point
├── firebase_options.dart               # Firebase configuration
├── models/
│   └── library_models.dart             # Data models for folders and glossaries
├── screens/
│   ├── splash_screen.dart              # Initial screen shown on app load
│   ├── login_screen.dart               # Handles user authentication
│   ├── registration_screen.dart        # User registration
│   ├── main_page.dart                  # The main dashboard after login
│   ├── library_screen.dart             # Folder/glossary organization
│   ├── glossary_screen.dart            # Edit glossary entries and draw symbols
│   ├── csv_column_mapping_screen.dart  # CSV import with column mapping
│   └── symbols_screen.dart             # Displays the list of symbols
└── widgets/
    └── library_item_card.dart          # Card widget for folders/glossaries
```

## Future Development

*   Implement the core translation functionality.
*   Connect to a backend service for user management and data storage.
*   Develop the UI for the glossary and symbols screens.
*   Implement the writing/drawing canvas for symbol input.