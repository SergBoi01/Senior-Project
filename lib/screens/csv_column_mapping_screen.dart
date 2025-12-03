
import 'package:flutter/material.dart';
import '../models/library_model.dart';

// =============================================================================
// CSV COLUMN MAPPING SCREEN
// =============================================================================

/// Screen for mapping CSV columns to glossary fields during import.
/// 
/// Allows users to:
/// - Name their new glossary
/// - Map CSV columns to English, Spanish, Definition, Synonym, or Ignore
/// - Preview the data before importing
/// - Handle duplicate entries
class CsvColumnMappingScreen extends StatefulWidget {
  final List<List<dynamic>> csvData;
  final String? parentFolderId;

  const CsvColumnMappingScreen({
    Key? key,
    required this.csvData,
    this.parentFolderId,
  }) : super(key: key);

  @override
  _CsvColumnMappingScreenState createState() => _CsvColumnMappingScreenState();
}

class _CsvColumnMappingScreenState extends State<CsvColumnMappingScreen> {
  // ===========================================================================
  // CONSTANTS
  // ===========================================================================

  static const Color primaryGreen = Color(0xFF5B8A51);
  static const Color backgroundColor = Color(0xFFE8E8E8);
  static const Color cardColor = Colors.white;
  static const Color darkText = Color(0xFF2D2D2D);
  static const Color subtleText = Color(0xFF6B6B6B);

  /// Available mapping options for CSV columns.
  static const List<String> mappingOptions = [
    'Ignore',
    'English',
    'Spanish',
    'Definition',
    'Synonym',
  ];

  // ===========================================================================
  // STATE
  // ===========================================================================

  /// Mapping for each column index -> field name.
  late List<String?> columnMappings;

  /// Controller for glossary name input.
  final TextEditingController _glossaryNameController = TextEditingController();

  // ===========================================================================
  // LIFECYCLE
  // ===========================================================================

  @override
  void initState() {
    super.initState();
    // Initialize all columns to 'Ignore' by default
    if (widget.csvData.isNotEmpty) {
      columnMappings = List.filled(widget.csvData[0].length, 'Ignore');
    } else {
      columnMappings = [];
    }
  }

  @override
  void dispose() {
    _glossaryNameController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // VALIDATION
  // ===========================================================================

  /// Returns true if at least one column is mapped (not Ignore).
  bool get _isValidMapping {
    return columnMappings.any((mapping) => mapping != null && mapping != 'Ignore');
  }

  /// Checks if a mapping is already used by another column.
  bool _isMappingUsed(String mapping, int currentIndex) {
    if (mapping == 'Ignore') return false;
    for (int i = 0; i < columnMappings.length; i++) {
      if (i != currentIndex && columnMappings[i] == mapping) {
        return true;
      }
    }
    return false;
  }

  // ===========================================================================
  // DATA PROCESSING
  // ===========================================================================

  /// Safely retrieves a cell value, handling missing columns.
  String _safeGetCell(List<dynamic> row, int columnIndex) {
    if (columnIndex < 0 || columnIndex >= row.length) {
      return '';
    }
    final value = row[columnIndex];
    if (value == null) {
      return '';
    }
    return value.toString().trim();
  }

  /// Builds glossary entries from the CSV data using current mappings.
  List<GlossaryEntry> _buildEntriesFromMapping() {
    List<GlossaryEntry> entries = [];

    // Find column indices for each field
    int englishCol = columnMappings.indexOf('English');
    int spanishCol = columnMappings.indexOf('Spanish');
    int definitionCol = columnMappings.indexOf('Definition');
    int synonymCol = columnMappings.indexOf('Synonym');

    // Skip header row (index 0)
    for (int i = 1; i < widget.csvData.length; i++) {
      List<dynamic> row = widget.csvData[i];

      // Skip empty rows
      if (row.isEmpty || row.every((cell) => cell.toString().trim().isEmpty)) {
        continue;
      }

      // Extract values using safe cell access
      String english = _safeGetCell(row, englishCol);
      String spanish = _safeGetCell(row, spanishCol);
      String definition = _safeGetCell(row, definitionCol);
      String synonym = _safeGetCell(row, synonymCol);

      // Only add if at least one field has content
      if (english.isNotEmpty ||
          spanish.isNotEmpty ||
          definition.isNotEmpty ||
          synonym.isNotEmpty) {
        entries.add(GlossaryEntry(
          english: english,
          spanish: spanish,
          definition: definition,
          synonym: synonym,
        ));
      }
    }

    return entries;
  }

  /// Detects duplicate entries in the list.
  List<Map<String, dynamic>> _detectDuplicates(List<GlossaryEntry> entries) {
    List<Map<String, dynamic>> duplicates = [];
    Map<String, int> seen = {};

    for (int i = 0; i < entries.length; i++) {
      // Create a unique key from all fields
      String key = '${entries[i].english}|${entries[i].spanish}|'
              '${entries[i].definition}|${entries[i].synonym}'
          .toLowerCase();

      if (seen.containsKey(key)) {
        duplicates.add({
          'index': i,
          'firstIndex': seen[key],
          'entry': entries[i],
        });
      } else {
        seen[key] = i;
      }
    }

    return duplicates;
  }

  /// Removes duplicate entries from the list.
  List<GlossaryEntry> _removeDuplicates(
    List<GlossaryEntry> entries,
    List<Map<String, dynamic>> duplicates,
  ) {
    Set<int> indicesToRemove = duplicates.map((d) => d['index'] as int).toSet();
    List<GlossaryEntry> cleaned = [];

    for (int i = 0; i < entries.length; i++) {
      if (!indicesToRemove.contains(i)) {
        cleaned.add(entries[i]);
      }
    }

    return cleaned;
  }

  /// Builds a display string for an entry (used in duplicate warning).
  String _buildEntryDisplayString(GlossaryEntry entry) {
    List<String> parts = [];
    if (entry.english.isNotEmpty) parts.add(entry.english);
    if (entry.spanish.isNotEmpty) parts.add(entry.spanish);
    if (entry.definition.isNotEmpty) parts.add(entry.definition);
    if (entry.synonym.isNotEmpty) parts.add(entry.synonym);
    return parts.isEmpty ? '(empty)' : parts.join(' / ');
  }

  // ===========================================================================
  // IMPORT ACTIONS
  // ===========================================================================

  /// Handles the import button tap.
  void _handleImport() {
    if (!_isValidMapping) {
      _showSnackBar('Please map at least one column', isError: true);
      return;
    }

    if (_glossaryNameController.text.trim().isEmpty) {
      _showSnackBar('Please enter a glossary name', isError: true);
      return;
    }

    List<GlossaryEntry> entries = _buildEntriesFromMapping();

    if (entries.isEmpty) {
      _showSnackBar('No valid entries found in CSV', isError: true);
      return;
    }

    List<Map<String, dynamic>> duplicates = _detectDuplicates(entries);

    if (duplicates.isNotEmpty) {
      _showDuplicateWarning(duplicates, entries);
    } else {
      _finalizeImport(entries);
    }
  }

  /// Completes the import with the given entries.
  void _finalizeImport(List<GlossaryEntry> entries) {
    if (_glossaryNameController.text.trim().isEmpty) {
      _showSnackBar('Please enter a glossary name', isError: true);
      return;
    }

    if (entries.isEmpty) {
      _showSnackBar('No valid entries to import', isError: true);
      return;
    }

    final glossary = GlossaryItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _glossaryNameController.text.trim(),
      parentId: widget.parentFolderId,
      entries: entries,
    );

    Navigator.pop(context, glossary);
  }

  // ===========================================================================
  // DIALOGS
  // ===========================================================================

  /// Shows a warning dialog for duplicate entries.
  Future<void> _showDuplicateWarning(
    List<Map<String, dynamic>> duplicates,
    List<GlossaryEntry> entries,
  ) async {
    return showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Duplicates Found',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: darkText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Duplicate count
              Text(
                'Found ${duplicates.length} duplicate '
                '${duplicates.length == 1 ? 'entry' : 'entries'}:',
                style: const TextStyle(fontWeight: FontWeight.w600, color: darkText),
              ),
              const SizedBox(height: 12),

              // Duplicate list preview
              Container(
                height: 120,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  shrinkWrap: true,
                  itemCount: duplicates.length > 5 ? 5 : duplicates.length,
                  itemBuilder: (context, index) {
                    final dup = duplicates[index];
                    final entry = dup['entry'] as GlossaryEntry;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _buildEntryDisplayString(entry),
                              style: const TextStyle(fontSize: 13, color: subtleText),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // "And X more" message
              if (duplicates.length > 5)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    '... and ${duplicates.length - 5} more',
                    style: const TextStyle(
                      fontSize: 12,
                      color: subtleText,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              const SizedBox(height: 24),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: subtleText, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _finalizeImport(_removeDuplicates(entries, duplicates));
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Colors.orange.withOpacity(0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Skip Dupes',
                        style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _finalizeImport(entries);
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: primaryGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Import All',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Shows the help dialog with import instructions.
  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primaryGreen.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.lightbulb_outline,
                      color: primaryGreen,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'How to Import',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: darkText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Steps
              _buildHelpItem('1', 'Enter a name for your glossary'),
              _buildHelpItem('2', 'Map each CSV column to a field type'),
              _buildHelpItem('3', 'Preview your data in the table below'),
              _buildHelpItem('4', 'Tap Import when ready'),
              const SizedBox(height: 20),

              // Close button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Got it!',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // UI HELPERS
  // ===========================================================================

  /// Shows a styled snackbar.
  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade400 : primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  /// Returns the icon for a mapping type.
  IconData _getMappingIcon(String mapping) {
    switch (mapping) {
      case 'Ignore':
        return Icons.block_outlined;
      case 'English':
        return Icons.translate;
      case 'Spanish':
        return Icons.language;
      case 'Definition':
        return Icons.menu_book_outlined;
      case 'Synonym':
        return Icons.swap_horiz;
      default:
        return Icons.help_outline;
    }
  }

  // ===========================================================================
  // BUILD METHODS
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    // Handle empty CSV data
    if (widget.csvData.isEmpty) {
      return Scaffold(
        backgroundColor: backgroundColor,
        appBar: _buildAppBar(),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.table_chart_outlined,
                  size: 48,
                  color: Colors.grey.shade400,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'No data found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: darkText,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'The CSV file appears to be empty',
                style: TextStyle(color: subtleText),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildGlossaryNameCard(),
                  const SizedBox(height: 16),
                  _buildMappingSection(),
                  const SizedBox(height: 16),
                  _buildPreviewSection(),
                ],
              ),
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  /// Builds the app bar.
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: cardColor,
      elevation: 0,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.arrow_back_ios_new, size: 16, color: darkText),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'Import CSV',
        style: TextStyle(
          color: darkText,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.help_outline, size: 18, color: subtleText),
          ),
          onPressed: _showHelpDialog,
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  /// Builds a help item row.
  Widget _buildHelpItem(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: primaryGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: const TextStyle(color: subtleText)),
          ),
        ],
      ),
    );
  }

  /// Builds the glossary name input card.
  Widget _buildGlossaryNameCard() {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primaryGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.book_outlined, color: primaryGreen, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Glossary Details',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: darkText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Name input
          TextField(
            controller: _glossaryNameController,
            style: const TextStyle(fontSize: 16, color: darkText),
            decoration: InputDecoration(
              hintText: 'Enter glossary name...',
              hintStyle: TextStyle(color: Colors.grey.shade400),
              filled: true,
              fillColor: backgroundColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: primaryGreen, width: 2),
              ),
              prefixIcon: const Icon(Icons.edit_outlined, color: subtleText, size: 20),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the column mapping section.
  Widget _buildMappingSection() {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primaryGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.view_column_outlined,
                  color: primaryGreen,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Column Mapping',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: darkText,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Assign each column to a field',
                      style: TextStyle(fontSize: 12, color: subtleText),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Mapping cards
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(
                widget.csvData[0].length,
                (index) => _buildMappingCard(index),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a single column mapping card.
  Widget _buildMappingCard(int index) {
    final currentMapping = columnMappings[index] ?? 'Ignore';
    final isIgnored = currentMapping == 'Ignore';
    final headerValue = widget.csvData[0][index].toString();

    return Container(
      width: 140,
      margin: EdgeInsets.only(
        right: index < widget.csvData[0].length - 1 ? 12 : 0,
      ),
      decoration: BoxDecoration(
        color: isIgnored ? Colors.grey.shade50 : primaryGreen.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isIgnored ? Colors.grey.shade200 : primaryGreen.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Column label
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isIgnored
                      ? Colors.grey.shade200
                      : primaryGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Col ${index + 1}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isIgnored ? subtleText : primaryGreen,
                  ),
                ),
              ),
              const Spacer(),
              if (!isIgnored)
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: primaryGreen,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 12),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // CSV header name
          Text(
            headerValue,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isIgnored ? subtleText : darkText,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),

          // Dropdown
          Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: currentMapping,
                isExpanded: true,
                icon: Icon(
                  Icons.keyboard_arrow_down,
                  size: 18,
                  color: isIgnored ? subtleText : primaryGreen,
                ),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isIgnored ? subtleText : primaryGreen,
                ),
                items: mappingOptions.map((option) {
                  bool isUsed = _isMappingUsed(option, index);
                  return DropdownMenuItem(
                    value: option,
                    enabled: !isUsed,
                    child: Row(
                      children: [
                        Icon(
                          _getMappingIcon(option),
                          size: 14,
                          color: isUsed
                              ? Colors.grey.shade300
                              : (option == 'Ignore' ? subtleText : primaryGreen),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          option,
                          style: TextStyle(
                            color: isUsed ? Colors.grey.shade300 : darkText,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    columnMappings[index] = value;
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the data preview section.
  Widget _buildPreviewSection() {
    int previewRows = widget.csvData.length > 6 ? 6 : widget.csvData.length;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primaryGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.table_chart_outlined,
                  color: primaryGreen,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Data Preview',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: darkText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Showing ${previewRows - 1} of ${widget.csvData.length - 1} rows',
                      style: const TextStyle(fontSize: 12, color: subtleText),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Preview table
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row
                    _buildPreviewHeaderRow(),
                    // Data rows
                    ...List.generate(
                      previewRows - 1,
                      (rowIndex) => _buildPreviewDataRow(rowIndex),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the preview table header row.
  Widget _buildPreviewHeaderRow() {
    return Container(
      color: primaryGreen.withOpacity(0.1),
      child: Row(
        children: List.generate(
          widget.csvData[0].length,
          (colIndex) {
            final mapping = columnMappings[colIndex] ?? 'Ignore';
            final isIgnored = mapping == 'Ignore';
            return Container(
              width: 120,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                border: Border(
                  right: colIndex < widget.csvData[0].length - 1
                      ? BorderSide(color: Colors.grey.shade200)
                      : BorderSide.none,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.csvData[0][colIndex].toString(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: isIgnored ? subtleText : darkText,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isIgnored ? Colors.grey.shade200 : primaryGreen,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      mapping,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: isIgnored ? subtleText : Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Builds a preview table data row.
  Widget _buildPreviewDataRow(int rowIndex) {
    return Container(
      color: rowIndex.isEven ? Colors.grey.shade50 : cardColor,
      child: Row(
        children: List.generate(
          widget.csvData[0].length,
          (colIndex) {
            final mapping = columnMappings[colIndex] ?? 'Ignore';
            final isIgnored = mapping == 'Ignore';
            return Container(
              width: 120,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  right: colIndex < widget.csvData[0].length - 1
                      ? BorderSide(color: Colors.grey.shade200)
                      : BorderSide.none,
                  bottom: BorderSide(color: Colors.grey.shade100),
                ),
              ),
              child: Text(
                _safeGetCell(widget.csvData[rowIndex + 1], colIndex),
                style: TextStyle(
                  fontSize: 12,
                  color: isIgnored ? subtleText : darkText,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            );
          },
        ),
      ),
    );
  }

  /// Builds the bottom action bar.
  Widget _buildBottomBar() {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Status indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _isValidMapping
                    ? primaryGreen.withOpacity(0.1)
                    : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _isValidMapping ? primaryGreen : Colors.orange,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isValidMapping ? Icons.check : Icons.info_outline,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _isValidMapping
                          ? 'Ready to import ${widget.csvData.length - 1} entries'
                          : 'Map at least one column to continue',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: _isValidMapping ? primaryGreen : Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Import button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isValidMapping ? _handleImport : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  disabledForegroundColor: Colors.grey.shade500,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.file_download_outlined,
                      size: 20,
                      color: _isValidMapping ? Colors.white : Colors.grey.shade500,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Import Glossary',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _isValidMapping ? Colors.white : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
