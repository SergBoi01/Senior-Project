import 'package:flutter/material.dart';
import '../models/library_models.dart';

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
  late List<String?> columnMappings; // Maps each column to a field or null (ignore)
  final TextEditingController _glossaryNameController = TextEditingController();
  
  // Available mapping options
  final List<String> mappingOptions = [
    'Ignore',
    'English',
    'Spanish',
    'Definition',
    'Synonym',
  ];

  @override
  void initState() {
    super.initState();
    // Initialize all columns to 'Ignore'
    if (widget.csvData.isNotEmpty) {
      columnMappings = List.filled(widget.csvData[0].length, 'Ignore');
    } else {
      columnMappings = [];
    }
  }

  // Check if at least one column is mapped
  bool get _isValidMapping {
    // At least one column must be mapped (not all set to 'Ignore')
    return columnMappings.any((mapping) => mapping != null && mapping != 'Ignore');
  }

  // Check if a mapping option is already used
  bool _isMappingUsed(String mapping, int currentIndex) {
    if (mapping == 'Ignore') return false;
    for (int i = 0; i < columnMappings.length; i++) {
      if (i != currentIndex && columnMappings[i] == mapping) {
        return true;
      }
    }
    return false;
  }

  // Build display string for an entry showing non-empty fields
  String _buildEntryDisplayString(GlossaryEntry entry) {
    List<String> parts = [];
    if (entry.english.isNotEmpty) parts.add(entry.english);
    if (entry.spanish.isNotEmpty) parts.add(entry.spanish);
    if (entry.definition.isNotEmpty) parts.add(entry.definition);
    if (entry.synonym.isNotEmpty) parts.add(entry.synonym);
    return parts.isEmpty ? '(empty)' : parts.join(' / ');
  }

  // Detect duplicates based on all field combinations
  List<Map<String, dynamic>> _detectDuplicates(List<GlossaryEntry> entries) {
    List<Map<String, dynamic>> duplicates = [];
    Map<String, int> seen = {};

    for (int i = 0; i < entries.length; i++) {
      // Create unique key from all fields
      String key = '${entries[i].english}|${entries[i].spanish}|${entries[i].definition}|${entries[i].synonym}'.toLowerCase();
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

  // Build glossary entries from CSV data
  List<GlossaryEntry> _buildEntriesFromMapping() {
    List<GlossaryEntry> entries = [];
    
    int englishCol = columnMappings.indexOf('English');
    int spanishCol = columnMappings.indexOf('Spanish');
    int definitionCol = columnMappings.indexOf('Definition');
    int synonymCol = columnMappings.indexOf('Synonym');

    // Skip header row (row 0) and process data rows
    for (int i = 1; i < widget.csvData.length; i++) {
      List<dynamic> row = widget.csvData[i];
      
      // Skip empty rows
      if (row.isEmpty || row.every((cell) => cell.toString().trim().isEmpty)) {
        continue;
      }

      String english = englishCol >= 0 && englishCol < row.length 
          ? row[englishCol].toString().trim() 
          : '';
      String spanish = spanishCol >= 0 && spanishCol < row.length 
          ? row[spanishCol].toString().trim() 
          : '';
      String definition = definitionCol >= 0 && definitionCol < row.length 
          ? row[definitionCol].toString().trim() 
          : '';
      String synonym = synonymCol >= 0 && synonymCol < row.length 
          ? row[synonymCol].toString().trim() 
          : '';

      // Only add if at least one field is not empty
      if (english.isNotEmpty || spanish.isNotEmpty || definition.isNotEmpty || synonym.isNotEmpty) {
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

  // Show duplicate warning dialog
  Future<void> _showDuplicateWarning(List<Map<String, dynamic>> duplicates, List<GlossaryEntry> entries) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Duplicates Detected'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Found ${duplicates.length} duplicate entries:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            SizedBox(
              height: 150,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: duplicates.length > 5 ? 5 : duplicates.length,
                itemBuilder: (context, index) {
                  final dup = duplicates[index];
                  final entry = dup['entry'] as GlossaryEntry;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Text(
                      '• ${_buildEntryDisplayString(entry)}',
                      style: TextStyle(fontSize: 13),
                    ),
                  );
                },
              ),
            ),
            if (duplicates.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  '... and ${duplicates.length - 5} more',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            SizedBox(height: 8),
            Text('What would you like to do?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _finalizeImport(_removeDuplicates(entries, duplicates));
            },
            child: Text('Skip Duplicates'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _finalizeImport(entries);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: Text('Import All'),
          ),
        ],
      ),
    );
  }

  // Remove duplicate entries
  List<GlossaryEntry> _removeDuplicates(List<GlossaryEntry> entries, List<Map<String, dynamic>> duplicates) {
    Set<int> indicesToRemove = duplicates.map((d) => d['index'] as int).toSet();
    List<GlossaryEntry> cleaned = [];
    
    for (int i = 0; i < entries.length; i++) {
      if (!indicesToRemove.contains(i)) {
        cleaned.add(entries[i]);
      }
    }
    
    return cleaned;
  }

  // Finalize import by creating glossary
  void _finalizeImport(List<GlossaryEntry> entries) {
    if (_glossaryNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a glossary name')),
      );
      return;
    }

    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No valid entries to import')),
      );
      return;
    }

    // Create the glossary item
    final glossary = GlossaryItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _glossaryNameController.text.trim(),
      parentId: widget.parentFolderId,
      entries: entries,
    );

    // Return the glossary to the previous screen
    Navigator.pop(context, glossary);
  }

  // Handle import button press
  void _handleImport() {
    if (!_isValidMapping) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please map at least one column'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_glossaryNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a glossary name')),
      );
      return;
    }

    // Build entries from mapping
    List<GlossaryEntry> entries = _buildEntriesFromMapping();

    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No valid entries found in CSV')),
      );
      return;
    }

    // Check for duplicates
    List<Map<String, dynamic>> duplicates = _detectDuplicates(entries);

    if (duplicates.isNotEmpty) {
      _showDuplicateWarning(duplicates, entries);
    } else {
      _finalizeImport(entries);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.csvData.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Import CSV'),
          backgroundColor: Colors.grey[800],
        ),
        body: Center(
          child: Text('No data found in CSV file'),
        ),
      );
    }

    // Get first 10 rows for preview
    int previewRows = widget.csvData.length > 10 ? 10 : widget.csvData.length;

    return Scaffold(
      appBar: AppBar(
        title: Text('Map CSV Columns'),
        backgroundColor: Colors.grey[800],
      ),
      body: Column(
        children: [
          // Glossary Name Input
          Container(
            color: Colors.grey[200],
            padding: EdgeInsets.all(16),
            child: TextField(
              controller: _glossaryNameController,
              decoration: InputDecoration(
                labelText: 'Glossary Name *',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),

          // Instructions
          Container(
            color: Colors.blue[50],
            padding: EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Select which column maps to each field. Map at least one column to import.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

          // Column Mapping Dropdowns
          Container(
            color: Colors.grey[100],
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(
                  widget.csvData[0].length,
                  (index) => Container(
                    width: 150,
                    margin: EdgeInsets.symmetric(horizontal: 4),
                    child: DropdownButtonFormField<String>(
                      initialValue: columnMappings[index],
                      decoration: InputDecoration(
                        labelText: 'Column ${index + 1}',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      ),
                      items: mappingOptions.map((option) {
                        bool isUsed = _isMappingUsed(option, index);
                        return DropdownMenuItem(
                          value: option,
                          enabled: !isUsed,
                          child: Text(
                            option,
                            style: TextStyle(
                              color: isUsed ? Colors.grey : Colors.black,
                              fontSize: 13,
                            ),
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
              ),
            ),
          ),

          // Preview Table
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  border: TableBorder.all(color: Colors.grey[300]!),
                  headingRowColor: WidgetStateProperty.all(Colors.grey[200]),
                  columns: List.generate(
                    widget.csvData[0].length,
                    (index) => DataColumn(
                      label: SizedBox(
                        width: 120,
                        child: Text(
                          widget.csvData[0][index].toString(),
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                  rows: List.generate(
                    previewRows - 1,
                    (rowIndex) => DataRow(
                      cells: List.generate(
                        widget.csvData[0].length,
                        (colIndex) => DataCell(
                          SizedBox(
                            width: 120,
                            child: Text(
                              widget.csvData[rowIndex + 1][colIndex].toString(),
                              style: TextStyle(fontSize: 12),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Status Bar
          Container(
            color: _isValidMapping ? Colors.green[100] : Colors.orange[100],
            padding: EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(
                  _isValidMapping ? Icons.check_circle : Icons.warning,
                  color: _isValidMapping ? Colors.green : Colors.orange,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isValidMapping
                        ? 'Ready to import ${widget.csvData.length - 1} rows'
                        : 'Please map at least one column',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

          // Import Button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isValidMapping ? _handleImport : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[300],
                ),
                child: Text(
                  'Import Glossary',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _glossaryNameController.dispose();
    super.dispose();
  }
}