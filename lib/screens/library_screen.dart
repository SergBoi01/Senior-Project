import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';

import '../models/library_models.dart';
import '../widgets/library_item_card.dart';
import '../services/library_storage.dart';
import 'glossary_screen.dart';
import 'csv_column_mapping_screen.dart';

// =============================================================================
// LIBRARY SCREEN
// =============================================================================

/// Main screen for managing the library folder/glossary hierarchy.
/// 
/// Features:
/// - Create, rename, and delete folders
/// - Create, rename, and delete glossaries (inside folders)
/// - Import glossaries from CSV files
/// - Navigate through folder hierarchy
/// - Checkbox selection for items
class LibraryScreen extends StatefulWidget {
  final FolderItem? initialFolder;

  const LibraryScreen({Key? key, this.initialFolder}) : super(key: key);

  @override
  _LibraryScreenState createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  // ===========================================================================
  // CONSTANTS
  // ===========================================================================

  static const Color primaryGreen = Color(0xFF5B8A51);
  static const Color backgroundColor = Color(0xFFE8E8E8);
  static const Color cardColor = Colors.white;
  static const Color darkText = Color(0xFF2D2D2D);
  static const Color subtleText = Color(0xFF6B6B6B);

  // ===========================================================================
  // STATE
  // ===========================================================================

  /// Root-level folders (glossaries must be inside folders).
  List<FolderItem> _rootFolders = [];

  /// Navigation stack for tracking current folder location.
  final List<FolderItem> _folderStack = [];

  /// Loading indicator state.
  bool _isLoading = true;

  // ===========================================================================
  // COMPUTED PROPERTIES
  // ===========================================================================

  /// Returns the current folder, or null if at root level.
  FolderItem? get _currentFolder =>
      _folderStack.isEmpty ? null : _folderStack.last;

  /// Returns items to display (folders at root, or folder contents).
  List<dynamic> get _currentItems {
    if (_currentFolder == null) {
      return _rootFolders;
    }
    return _currentFolder!.children;
  }

  // ===========================================================================
  // LIFECYCLE
  // ===========================================================================

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ===========================================================================
  // DATA OPERATIONS
  // ===========================================================================

  /// Loads folder data from persistent storage.
  Future<void> _loadData() async {
    final folders = await LibraryStorage.loadFolders();
    setState(() {
      _rootFolders = folders;
      _isLoading = false;

      // Navigate to initial folder if provided
      if (widget.initialFolder != null) {
        final folder = _findFolderById(widget.initialFolder!.id, _rootFolders);
        if (folder != null) {
          _folderStack.add(folder);
        }
      }
    });
  }

  /// Saves folder data to persistent storage.
  Future<void> _saveData() async {
    await LibraryStorage.saveFolders(_rootFolders);
  }

  /// Recursively finds a folder by ID.
  FolderItem? _findFolderById(String id, List<FolderItem> folders) {
    for (final folder in folders) {
      if (folder.id == id) return folder;
      final found = _findFolderById(id, folder.folders);
      if (found != null) return found;
    }
    return null;
  }

  /// Generates a unique ID using timestamp and random number.
  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString() +
        Random().nextInt(1000).toString();
  }

  // ===========================================================================
  // NAVIGATION
  // ===========================================================================

  /// Navigates into a folder.
  void _navigateToFolder(FolderItem folder) {
    setState(() {
      _folderStack.add(folder);
    });
  }

  /// Navigates back one level, or pops screen if at root.
  void _navigateBack() {
    if (_folderStack.isNotEmpty) {
      setState(() {
        _folderStack.removeLast();
      });
    } else {
      Navigator.pop(context);
    }
  }

  /// Builds breadcrumb string for current location.
  String _buildBreadcrumb() {
    if (_folderStack.isEmpty) {
      return 'Library';
    }
    return _folderStack.map((f) => f.name).join(' / ');
  }

  // ===========================================================================
  // ITEM TAP HANDLERS
  // ===========================================================================

  /// Handles tap on a folder or glossary item.
  void _handleItemTap(dynamic item) async {
    if (item is FolderItem) {
      _navigateToFolder(item);
    } else if (item is GlossaryItem) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GlossaryScreen(glossaryItem: item),
        ),
      );
      // Save changes made in glossary screen
      _saveData();
    }
  }

  /// Toggles checkbox state for an item.
  void _toggleCheckbox(dynamic item, bool newValue) {
    setState(() {
      item.isChecked = newValue;
    });
    _saveData();
  }

  // ===========================================================================
  // CREATE OPERATIONS
  // ===========================================================================

  /// Shows dialog to choose what to create (folder, glossary, or import).
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
              const Text(
                'Create New',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: darkText,
                ),
              ),
              const SizedBox(height: 20),
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

  /// Builds a create option row for the create dialog.
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

  /// Shows dialog to create a new folder.
  void _createFolder() {
    final nameController = TextEditingController();
    final isSubfolder = _currentFolder != null;

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

              // Name input
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
                  prefixIcon: Icon(Icons.folder_outlined, color: subtleText, size: 20),
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
                        style: TextStyle(color: subtleText, fontWeight: FontWeight.w600),
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

                          _saveData();
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

  /// Shows dialog to create a new glossary.
  void _createGlossary() {
    // Glossaries must be inside folders
    if (_currentFolder == null) {
      _showStyledSnackBar(
        'Glossaries must be created inside a folder',
        isWarning: true,
      );
      return;
    }

    final nameController = TextEditingController();

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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primaryGreen.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.book_outlined, color: primaryGreen, size: 24),
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

              // Name input
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
                  prefixIcon: Icon(Icons.edit_outlined, color: subtleText, size: 20),
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
                        style: TextStyle(color: subtleText, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (nameController.text.trim().isEmpty) {
                          _showStyledSnackBar('Please enter a glossary name', isError: true);
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

                        _saveData();
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

  // ===========================================================================
  // CSV IMPORT
  // ===========================================================================

  /// Imports a glossary from a CSV file.
  Future<void> _importFromCSV() async {
    // Must be inside a folder to import
    if (_currentFolder == null) {
      _showStyledSnackBar('CSV files must be imported inside a folder', isWarning: true);
      return;
    }

    try {
      // Pick CSV file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;

      if (file.bytes == null) {
        _showStyledSnackBar('Could not read file', isError: true);
        return;
      }

      // Check file size (5MB limit)
      const maxFileSize = 5 * 1024 * 1024;
      if (file.bytes!.length > maxFileSize) {
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

      // Add imported glossary to current folder
      if (glossary != null) {
        setState(() {
          _currentFolder!.addChild(glossary);
        });
        _saveData();
        _showStyledSnackBar('Successfully imported ${glossary.entries.length} entries');
      }
    } catch (e) {
      _showStyledSnackBar('Error importing CSV: ${e.toString()}', isError: true);
    }
  }

  // ===========================================================================
  // RENAME & DELETE OPERATIONS
  // ===========================================================================

  /// Shows dialog to rename an item.
  void _renameItem(dynamic item) {
    final nameController = TextEditingController(text: item.name);

    // Determine item type for display
    String itemType;
    IconData itemIcon;
    Color itemColor;

    if (item is FolderItem) {
      itemType = item.parentId != null ? 'Subfolder' : 'Folder';
      itemIcon = item.parentId != null ? Icons.folder_copy_outlined : Icons.folder_outlined;
      itemColor = Colors.amber[700]!;
    } else {
      itemType = 'Glossary';
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
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: itemColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(itemIcon, color: itemColor, size: 24),
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

              // Name input
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
                  prefixIcon: Icon(Icons.edit_outlined, color: subtleText, size: 20),
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
                        style: TextStyle(color: subtleText, fontWeight: FontWeight.w600),
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
                          _saveData();
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

  /// Shows confirmation dialog before deleting an item.
  void _deleteItem(dynamic item) {
    final itemName = item.name;
    final itemType = item is FolderItem
        ? (item.parentId != null ? 'Subfolder' : 'Folder')
        : 'Glossary';

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
                child: Icon(Icons.delete_forever, color: Colors.red[400], size: 40),
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

              // Warning message
              Text(
                'You are about to delete "$itemName" and all of its children, are you sure?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: subtleText, height: 1.4),
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
                        style: TextStyle(color: subtleText, fontWeight: FontWeight.w600),
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

  /// Performs the actual deletion of an item.
  void _performDelete(dynamic item) {
    setState(() {
      if (_currentFolder == null) {
        _rootFolders.removeWhere((folder) => folder.id == item.id);
      } else {
        _currentFolder!.children.removeWhere((child) => child.id == item.id);
      }
    });

    _saveData();
    _showStyledSnackBar('${item.name} deleted');
  }

  // ===========================================================================
  // UI HELPERS
  // ===========================================================================

  /// Shows a styled snackbar with icon.
  void _showStyledSnackBar(
    String message, {
    bool isError = false,
    bool isWarning = false,
  }) {
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

  // ===========================================================================
  // BUILD METHODS
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          _buildBreadcrumb(),
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: _navigateBack,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryGreen))
          : _buildContent(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_currentFolder == null) {
            _createFolder();
          } else {
            _showCreateDialog();
          }
        },
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  /// Builds the main content area.
  Widget _buildContent() {
    if (_currentItems.isEmpty) {
      return _buildEmptyState();
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
    );
  }

  /// Builds the empty state placeholder.
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.folder_open_outlined, size: 48, color: subtleText),
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
            style: TextStyle(fontSize: 14, color: subtleText),
          ),
        ],
      ),
    );
  }
}
