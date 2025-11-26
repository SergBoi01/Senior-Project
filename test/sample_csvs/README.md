# Sample CSV Test Files

This directory contains sample CSV files for testing the CSV import functionality in the Senior Project app.

## Files

### `valid_glossary.csv`
A properly formatted CSV file with all four columns (English, Spanish, Definition, Synonym) filled in correctly.

**Use case:** Testing normal, successful import flow.

### `mismatched_columns.csv`
A CSV file where different rows have different numbers of columns.

**Use case:** Testing that the app handles:
- Rows with fewer columns than the header
- Rows with more columns than expected
- Missing data without crashing

### `empty_rows.csv`
A CSV file containing empty rows and rows with only whitespace.

**Use case:** Testing that empty rows are properly skipped during import.

### `special_characters.csv`
A CSV file containing special characters including:
- Unicode characters (emoji, tildes)
- Quotes and double quotes
- Line breaks within cells
- Special symbols

**Use case:** Testing UTF-8 encoding and special character handling.

### `only_ignore_columns.csv`
A CSV file with generic column names that would typically be mapped to "Ignore".

**Use case:** Testing that when all columns are ignored, no entries are created (graceful handling).

## How to Use

1. Open the app and navigate to a folder in the Library
2. Tap the "+" button and select "Import from CSV"
3. Select one of these sample CSV files
4. Map the columns appropriately
5. Verify the app handles each edge case correctly

## Expected Behaviors

- **Valid CSV**: Should import all entries successfully
- **Mismatched columns**: Should handle missing/extra columns gracefully without crashing
- **Empty rows**: Should skip empty rows and only import valid entries
- **Special characters**: Should preserve special characters and emojis correctly
- **Ignore columns**: Should not create entries when all columns are ignored

