import 'package:flutter/material.dart';
import '../models/library_models.dart';
import '../widgets/library_item_card.dart';
import 'glossary_screen.dart';
import 'csv_column_mapping_screen.dart';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'dart:convert';

class LibraryScreen extends StatefulWidget {
  final FolderItem? initialFolder; // For navigating into a specific folder

  const LibraryScreen({Key? key, this.initialFolder}) : super(key: key);

  @override
  _LibraryScreenState createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  // Root level storage - only folders (glossaries are inside folders)
  final List<FolderItem> _rootFolders = [];

  // Folder navigation stack to track current location
  final List<FolderItem> _folderStack = [];

  // Get current folder (null if at root)
  FolderItem? get _currentFolder => _folderStack.isEmpty ? null : _folderStack.last;

  // Get items to display in current location (folders + glossaries)
  List<dynamic> get _currentItems {
    if (_currentFolder == null) {
      // At root: only show folders
      return _rootFolders;
    } else {
      // Inside a folder: show both folders and glossaries
      return _currentFolder!.children;
    }
  }

  @override
  void initState() {
    super.initState();
    // If navigating into a specific folder, set up the stack
    if (widget.initialFolder != null) {
      _folderStack.add(widget.initialFolder!);
    }
  }

  // Generate unique ID
  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString() +
        Random().nextInt(1000).toString();
  }

  // Navigate into a folder
  void _navigateToFolder(FolderItem folder) {
    setState(() {
      _folderStack.add(folder);
    });
  }

  // Navigate back
  void _navigateBack() {
    if (_folderStack.isNotEmpty) {
      setState(() {
        _folderStack.removeLast();
      });
    } else {
      Navigator.pop(context);
    }
  }

  // Create new folder in current location
  void _createFolder() {
    final TextEditingController nameController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_currentFolder == null ? 'Create Folder' : 'Create Subfolder'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: InputDecoration(
            labelText: _currentFolder == null ? 'Folder Name' : 'Subfolder Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                final folder = FolderItem(
                  id: _generateId(),
                  name: nameController.text.trim(),
                  parentId: _currentFolder?.id,
                );
                
                setState(() {
                  if (_currentFolder == null) {
                    // Add to root level
                    _rootFolders.add(folder);
                  } else {
                    // Add to current folder (subfolder)
                    _currentFolder!.addChild(folder);
                  }
                });
                
                Navigator.pop(context);
              }
            },
            child: Text('Create'),
          ),
        ],
      ),
    );
  }

  // Create new glossary in current location
  void _createGlossary() {
    // Can't create glossary at root - must be inside a folder
    if (_currentFolder == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Glossaries must be created inside a folder')),
      );
      return;
    }

    final TextEditingController nameController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Create Glossary'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Glossary Name *',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Name is mandatory
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Please enter a glossary name')),
                );
                return;
              }
              
              final glossary = GlossaryItem(
                id: _generateId(),
                name: nameController.text.trim(),
                parentId: _currentFolder!.id,
              );
              
              setState(() {
                _currentFolder!.addChild(glossary);
              });
              
              Navigator.pop(context);
            },
            child: Text('Create'),
          ),
        ],
      ),
    );
  }

  // Import glossary from CSV file
  Future<void> _importFromCSV() async {
    // Can't import at root - must be inside a folder
    if (_currentFolder == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CSV files must be imported inside a folder')),
      );
      return;
    }

    try {
      // Pick CSV file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        // User canceled the picker
        return;
      }

      final file = result.files.first;
      
      if (file.bytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not read file')),
        );
        return;
      }

      // Parse CSV
      String csvString = utf8.decode(file.bytes!);
      List<List<dynamic>> csvData = const CsvToListConverter().convert(csvString);

      if (csvData.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('CSV file is empty')),
        );
        return;
      }

      if (csvData.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('CSV must have at least a header row and one data row')),
        );
        return;
      }

      // Navigate to column mapping screen
      final glossary = await Navigator.push<GlossaryItem>(
        context,
        MaterialPageRoute(
          builder: (context) => CsvColumnMappingScreen(
            csvData: csvData,
            parentFolderId: _currentFolder!.id,
          ),
        ),
      );

      // If glossary was created, add it to current folder
      if (glossary != null) {
        setState(() {
          _currentFolder!.addChild(glossary);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully imported ${glossary.entries.length} entries'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error importing CSV: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Show dialog to choose between folder and glossary
  void _showCreateDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Create New'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.folder),
              title: Text(_currentFolder == null ? 'Folder' : 'Subfolder'),
              onTap: () {
                Navigator.pop(context);
                _createFolder();
              },
            ),
            // Only show glossary option when inside a folder
            if (_currentFolder != null)
              ListTile(
                leading: Icon(Icons.book),
                title: Text('Glossary'),
                onTap: () {
                  Navigator.pop(context);
                  _createGlossary();
                },
              ),
            // CSV import option (only when inside a folder)
            if (_currentFolder != null)
              ListTile(
                leading: Icon(Icons.upload_file),
                title: Text('Import from CSV'),
                onTap: () {
                  Navigator.pop(context);
                  _importFromCSV();
                },
              ),
          ],
        ),
      ),
    );
  }

  // Rename item
  void _renameItem(dynamic item) {
    final TextEditingController nameController = TextEditingController(text: item.name);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Rename ${item is FolderItem ? "Folder" : "Glossary"}'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                setState(() {
                  item.name = nameController.text.trim();
                });
                Navigator.pop(context);
              }
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
  }

  // Toggle checkbox
  void _toggleCheckbox(dynamic item, bool newValue) {
    setState(() {
      item.isChecked = newValue;
    });
  }

  // Handle item tap
  void _handleItemTap(dynamic item) {
    if (item is FolderItem) {
      // Navigate into folder
      _navigateToFolder(item);
    } else if (item is GlossaryItem) {
      // Navigate to GlossaryScreen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GlossaryScreen(glossaryItem: item),
        ),
      );
    }
  }

  // Build breadcrumb
  String _buildBreadcrumb() {
    if (_folderStack.isEmpty) {
      return 'Library';
    }
    return _folderStack.map((f) => f.name).join(' / ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[300],
      appBar: AppBar(
        title: Text(
          _buildBreadcrumb(),
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: _navigateBack,
        ),
      ),
      body: Column(
        children: [
          // Cards section - show folders and glossaries
          if (_currentItems.isNotEmpty)
            Expanded(
              child: GridView.builder(
                padding: EdgeInsets.all(16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.2,
                ),
                itemCount: _currentItems.length,
                itemBuilder: (context, index) {
                  final item = _currentItems[index];
                  return LibraryItemCard(
                    item: item,
                    onTap: () => _handleItemTap(item),
                    onRename: () => _renameItem(item),
                    onCheckboxChanged: (value) => _toggleCheckbox(item, value),
                  );
                },
              ),
            )
          else
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.folder_open,
                      size: 64,
                      color: Colors.grey[600],
                    ),
                    SizedBox(height: 16),
                    Text(
                      _currentFolder == null
                          ? 'No folders yet'
                          : 'No Subfolders or glossary yet',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Tap the + button to create',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_currentFolder == null) {
            // At root: go straight to folder creation
            _createFolder();
          } else {
            // Inside folder: show dialog to choose between subfolder or glossary
            _showCreateDialog();
          }
        },
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        child: Icon(Icons.add),
      ),
    );
  }
}
