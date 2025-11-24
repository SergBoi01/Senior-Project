# CSV Import Feature - Implementation Guide

## Overview
This feature allows users to bulk-import glossary entries from CSV files with flexible column mapping, duplicate detection, and validation.

## User Flow

### 1. Starting the Import
- User navigates to any folder in the Library screen
- Clicks the floating action button (+)
- Selects "Import from CSV" from the dialog
- File picker opens with CSV filter

### 2. Column Mapping Screen
Once a CSV file is selected, users see:

- **Glossary Name Input**: Required text field at the top
- **Instructions Banner**: Explains that at least one column must be mapped
- **Column Mapping Dropdowns**: One dropdown per CSV column
  - Options: Ignore, English, Spanish, Definition, Synonym
  - Already-used options are disabled (grayed out)
  - Prevents duplicate mappings
- **Data Preview Table**: Shows first 10 rows of CSV data
- **Status Bar**: Indicates whether mapping is valid or what's missing
- **Import Button**: Enabled when at least one column is mapped

### 3. Validation & Import
When user clicks "Import Glossary":

1. **Required Field Check**: Ensures at least one column is mapped (flexible - can be any combination)
2. **Glossary Name Check**: Ensures a name was entered
3. **Empty Row Handling**: Automatically skips empty rows
4. **Duplicate Detection**: Checks for duplicate entries based on all field combinations
   - If duplicates found, shows warning dialog with:
     - List of duplicates (up to 5 displayed)
     - Three options: Cancel, Skip Duplicates, or Import All
5. **Glossary Creation**: Creates GlossaryItem with all entries
6. **Success Feedback**: Shows snackbar with number of entries imported

## Technical Implementation

### New Files Created

#### `lib/screens/csv_column_mapping_screen.dart`
Main screen for CSV import with:
- Column mapping UI with dropdowns
- Preview table showing CSV data
- Validation logic for required fields
- Duplicate detection algorithm
- Glossary creation and navigation

**Key Methods:**
- `_isValidMapping`: Checks if at least one column is mapped
- `_isMappingUsed()`: Prevents duplicate field mappings
- `_buildEntryDisplayString()`: Creates display string for entries showing non-empty fields
- `_detectDuplicates()`: Finds duplicate entries based on all field combinations
- `_buildEntriesFromMapping()`: Converts CSV data to GlossaryEntry objects
- `_showDuplicateWarning()`: Displays duplicate handling dialog
- `_handleImport()`: Orchestrates the import process

### Modified Files

#### `pubspec.yaml`
Added dependencies:
```yaml
file_picker: ^8.0.0  # For CSV file selection
csv: ^6.0.0          # For parsing CSV files
```

#### `lib/screens/library_screen.dart`
Added:
- Import statements for file_picker, csv, and new mapping screen
- "Import from CSV" option in `_showCreateDialog()`
- `_importFromCSV()` method that:
  - Opens file picker with CSV filter
  - Parses CSV file using csv package
  - Validates file has header + data rows
  - Navigates to mapping screen
  - Adds returned glossary to current folder
  - Shows success/error feedback

### Data Models (No Changes Required)
The existing `GlossaryEntry` and `GlossaryItem` models in `library_models.dart` work perfectly with the CSV import feature.

## CSV Format Requirements

### Minimum Requirements
- Must have at least 2 rows (header + 1 data row)
- Must be valid CSV format
- Column names can be anything (user maps them)

### Recommended Format
```csv
English,Spanish,Definition,Synonym
word1,palabra1,definition1,synonym1
word2,palabra2,definition2,synonym2
```

### Flexible Format
The feature supports any column arrangement:
```csv
Spanish Term,English Term,Extra Info,Meaning,Similar Words
hola,hello,ignore this,a greeting,hi
```

User can map:
- Column 1 → Spanish
- Column 2 → English  
- Column 3 → Ignore
- Column 4 → Definition
- Column 5 → Synonym

## Edge Cases Handled

1. **Empty Rows**: Automatically skipped during import
2. **Missing Columns**: If CSV has fewer columns than expected, empty strings are used
3. **Extra Columns**: Set to "Ignore" and not imported
4. **Duplicates**: User chooses to import all or skip
5. **No File Selected**: Import cancelled gracefully
6. **Invalid CSV**: Error message shown
7. **Empty CSV**: Error message shown
8. **Invalid Mapping**: Import button disabled with clear message

## Sample CSV File
A `sample_glossary.csv` file has been created in the project root with 12 example entries for testing.

## Testing Checklist

- [ ] Import CSV with standard format (English, Spanish, Definition, Synonym)
- [ ] Import CSV with columns in different order
- [ ] Import CSV with extra columns (should be ignorable)
- [ ] Import CSV with missing Synonym column (optional field)
- [ ] Test duplicate detection and both handling options
- [ ] Test with empty rows in CSV
- [ ] Test canceling file picker
- [ ] Test canceling at mapping screen
- [ ] Test invalid mapping (missing required fields)
- [ ] Test with very large CSV (100+ entries)
- [ ] Test with special characters in entries
- [ ] Test creating glossary in root folder (should fail with message)

## Future Enhancements (Not Implemented)

1. **Excel Support**: Currently only supports CSV, not .xlsx
2. **Template Download**: Provide downloadable CSV template
3. **Column Auto-Detection**: Try to guess column mappings based on headers
4. **Progress Indicator**: Show progress for very large imports
5. **Error Row Highlighting**: Show which specific rows have issues
6. **Edit Before Import**: Allow editing entries before final import
7. **Multiple File Import**: Import multiple CSVs at once

