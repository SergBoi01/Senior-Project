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
  // Design colors matching the CSV import screen
  static const Color primaryGreen = Color(0xFF5B8A51);
  static const Color backgroundColor = Color(0xFFE8E8E8);
  static const Color cardColor = Colors.white;
  static const Color darkText = Color(0xFF2D2D2D);
  static const Color subtleText = Color(0xFF6B6B6B);

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
    final bool isSubfolder = _currentFolder != null;
    
    showDialog(
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
              // Header with icon
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primaryGreen.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.create_new_folder_outlined,
                      color: primaryGreen,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isSubfolder ? 'Create Subfolder' : 'Create Folder',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: darkText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // Text field
              TextField(
                controller: nameController,
                autofocus: true,
                style: const TextStyle(fontSize: 16, color: darkText),
                decoration: InputDecoration(
                  hintText: isSubfolder ? 'Subfolder Name' : 'Folder Name',
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
                  prefixIcon: Icon(
                    Icons.folder_outlined,
                    color: subtleText,
                    size: 20,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: subtleText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (nameController.text.trim().isNotEmpty) {
                          final folder = FolderItem(
                            id: _generateId(),
                            name: nameController.text.trim(),
                            parentId: _currentFolder?.id,
                          );
                          
                          setState(() {
                            if (_currentFolder == null) {
                              _rootFolders.add(folder);
                            } else {
                              _currentFolder!.addChild(folder);
                            }
                          });
                          
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Create',
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

  // Create new glossary in current location
  void _createGlossary() {
    // Can't create glossary at root - must be inside a folder
    if (_currentFolder == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Text('Glossaries must be created inside a folder'),
            ],
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    final TextEditingController nameController = TextEditingController();
    
    showDialog(
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
              // Header with icon
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primaryGreen.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.book_outlined,
                      color: primaryGreen,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Create Glossary',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: darkText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // Text field
              TextField(
                controller: nameController,
                autofocus: true,
                style: const TextStyle(fontSize: 16, color: darkText),
                decoration: InputDecoration(
                  hintText: 'Glossary Name *',
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
                  prefixIcon: Icon(
                    Icons.edit_outlined,
                    color: subtleText,
                    size: 20,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: subtleText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (nameController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  Icon(Icons.error_outline, color: Colors.white, size: 20),
                                  const SizedBox(width: 12),
                                  Text('Please enter a glossary name'),
                                ],
                              ),
                              backgroundColor: Colors.red.shade400,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              margin: const EdgeInsets.all(16),
                            ),
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
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Create',
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

  // Import glossary from CSV file
  Future<void> _importFromCSV() async {
    // Can't import at root - must be inside a folder
    if (_currentFolder == null) {
      _showStyledSnackBar('CSV files must be imported inside a folder', isError: false, isWarning: true);
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
        _showStyledSnackBar('Could not read file', isError: true);
        return;
      }

      // Check file size (limit to 5MB for performance)
      const int maxFileSizeBytes = 5 * 1024 * 1024; // 5MB
      if (file.bytes!.length > maxFileSizeBytes) {
        _showStyledSnackBar('File is too large. Maximum size is 5MB', isError: true);
        return;
      }

      // Parse CSV
      String csvString = utf8.decode(file.bytes!);
      List<List<dynamic>> csvData = const CsvToListConverter().convert(csvString);

      if (csvData.isEmpty) {
        _showStyledSnackBar('CSV file is empty', isError: true);
        return;
      }

      if (csvData.length < 2) {
        _showStyledSnackBar('CSV must have at least a header row and one data row', isError: true);
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
        
        _showStyledSnackBar('Successfully imported ${glossary.entries.length} entries', isError: false);
      }
    } catch (e) {
      _showStyledSnackBar('Error importing CSV: ${e.toString()}', isError: true);
    }
  }

  void _showStyledSnackBar(String message, {bool isError = false, bool isWarning = false}) {
    Color bgColor;
    IconData icon;
    
    if (isError) {
      bgColor = Colors.red.shade400;
      icon = Icons.error_outline;
    } else if (isWarning) {
      bgColor = Colors.orange;
      icon = Icons.info_outline;
    } else {
      bgColor = primaryGreen;
      icon = Icons.check_circle_outline;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: bgColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // Show dialog to choose between folder and glossary
  void _showCreateDialog() {
    showDialog(
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
              const Text(
                'Create New',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: darkText,
                ),
              ),
              const SizedBox(height: 20),
              
              // Subfolder option
              _buildCreateOption(
                icon: Icons.folder_copy_outlined,
                label: 'Subfolder',
                color: Colors.amber[700]!,
                onTap: () {
                  Navigator.pop(context);
                  _createFolder();
                },
              ),
              const SizedBox(height: 12),
              
              // Glossary option
              _buildCreateOption(
                icon: Icons.book_outlined,
                label: 'Glossary',
                color: Colors.blue[700]!,
                onTap: () {
                  Navigator.pop(context);
                  _createGlossary();
                },
              ),
              const SizedBox(height: 12),
              
              // Import from CSV option
              _buildCreateOption(
                icon: Icons.upload_file_outlined,
                label: 'Import from CSV',
                color: primaryGreen,
                onTap: () {
                  Navigator.pop(context);
                  _importFromCSV();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreateOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: darkText,
                ),
              ),
              const Spacer(),
              Icon(Icons.chevron_right, color: subtleText, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  // Rename item
  void _renameItem(dynamic item) {
    final TextEditingController nameController = TextEditingController(text: item.name);
    
    // Determine item type
    String itemType;
    IconData itemIcon;
    Color itemColor;
    if (item is FolderItem) {
      itemType = item.parentId != null ? "Subfolder" : "Folder";
      itemIcon = item.parentId != null ? Icons.folder_copy_outlined : Icons.folder_outlined;
      itemColor = Colors.amber[700]!;
    } else {
      itemType = "Glossary";
      itemIcon = Icons.book_outlined;
      itemColor = Colors.blue[700]!;
    }
    
    showDialog(
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
              // Header with icon
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: itemColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      itemIcon,
                      color: itemColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Rename $itemType',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: darkText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // Text field
              TextField(
                controller: nameController,
                autofocus: true,
                style: const TextStyle(fontSize: 16, color: darkText),
                decoration: InputDecoration(
                  hintText: 'Name',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  filled: true,
                  fillColor: backgroundColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: itemColor, width: 2),
                  ),
                  prefixIcon: Icon(
                    Icons.edit_outlined,
                    color: subtleText,
                    size: 20,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: subtleText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (nameController.text.trim().isNotEmpty) {
                          setState(() {
                            item.name = nameController.text.trim();
                          });
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Save',
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

  // Delete item
  void _deleteItem(dynamic item) {
    final String itemName = item.name;
    
    // Determine item type
    String itemType;
    if (item is FolderItem) {
      itemType = item.parentId != null ? "Subfolder" : "Folder";
    } else {
      itemType = "Glossary";
    }

    showDialog(
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
            children: [
              // Warning icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.delete_forever,
                  color: Colors.red[400],
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              
              // Title
              Text(
                'Delete $itemType?',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: darkText,
                ),
              ),
              const SizedBox(height: 12),
              
              // Message
              Text(
                'You are about to delete "$itemName" and all of its children, are you sure?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: subtleText,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              
              // Buttons
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
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: subtleText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _performDelete(item);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[400],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Delete',
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

  // Actually perform the deletion
  void _performDelete(dynamic item) {
    setState(() {
      if (_currentFolder == null) {
        // At root level - remove from root folders
        _rootFolders.removeWhere((folder) => folder.id == item.id);
      } else {
        // Inside a folder - remove from current folder's children
        _currentFolder!.children.removeWhere((child) => child.id == item.id);
      }
    });

    _showStyledSnackBar('${item.name} deleted', isError: false);
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
      backgroundColor: backgroundColor,
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
                    onDelete: () => _deleteItem(item),
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
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.folder_open_outlined,
                        size: 48,
                        color: subtleText,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _currentFolder == null
                          ? 'No folders yet'
                          : 'No subfolders or glossaries yet',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: darkText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap the + button to create',
                      style: TextStyle(
                        fontSize: 14,
                        color: subtleText,
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
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        child: Icon(Icons.add),
      ),
    );
  }
}
