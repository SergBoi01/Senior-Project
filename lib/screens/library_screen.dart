import 'package:flutter/material.dart';
import 'dart:math';

import '../models/library_models.dart';
import '../widgets/library_item_card_widget.dart';
import '../services/glossary_service.dart';
import 'glossary_screen.dart';

class LibraryScreen extends StatefulWidget {
  final FolderItem? initialFolder;

  const LibraryScreen({super.key, this.initialFolder});

  @override
  _LibraryScreenState createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<FolderItem> _rootFolders = [];
  final List<FolderItem> _folderStack = [];

  final GlossaryService _glossaryService = GlossaryService();

  bool _isLoading = false;

  FolderItem? get _currentFolder => _folderStack.isEmpty ? null : _folderStack.last;
  List<dynamic> get _currentItems => _currentFolder?.children ?? _rootFolders;

  @override
  void initState() {
    super.initState();
    if (widget.initialFolder != null) {
      _folderStack.add(widget.initialFolder!);
    } else {
      _loadLibrary();
    }
  }

  /// Load library structure from SharedPreferences
  Future<void> _loadLibrary() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      debugPrint('[LibraryScreen] Loading library structure...');
      
      final rootFolders = await _glossaryService.loadRootFolders();
      
      if (!mounted) return;
      
      setState(() {
        _rootFolders = rootFolders;
        _isLoading = false;
      });
      
      debugPrint('[LibraryScreen] Loaded ${_rootFolders.length} root folders');
    } catch (e) {
      debugPrint('[LibraryScreen] Failed to load library: $e');
      
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load library: $e')),
        );
      }
    }
  }

  /// Save folder with error handling
  Future<void> _saveFolderSafe(FolderItem folder) async {
    try {
      debugPrint('[LibraryScreen] Saving folder: ${folder.id} "${folder.name}"');
      await _glossaryService.saveFolder(folder);
      debugPrint('[LibraryScreen] Folder saved successfully');
    } catch (e) {
      debugPrint('[LibraryScreen] Failed to save folder ${folder.id}: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save folder: $e')),
        );
      }
    }
  }

  /// Save glossary with error handling
  Future<void> _saveGlossarySafe(GlossaryItem glossary) async {
    try {
      debugPrint('[LibraryScreen] Saving glossary: ${glossary.id} "${glossary.name}"');
      await _glossaryService.saveGlossary(glossary);
      debugPrint('[LibraryScreen] Glossary saved successfully');
    } catch (e) {
      debugPrint('[LibraryScreen] Failed to save glossary ${glossary.id}: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save glossary: $e')),
        );
      }
    }
  }

  /// Generate unique ID for new items
  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString() + 
           Random().nextInt(1000).toString();
  }

  /// Navigate into a folder
  void _navigateToFolder(FolderItem folder) {
    setState(() => _folderStack.add(folder));
    debugPrint('[LibraryScreen] Navigated to folder: ${folder.name}');
  }

  /// Navigate back
  void _navigateBack() {
    if (_folderStack.isNotEmpty) {
      final folder = _folderStack.last;
      setState(() => _folderStack.removeLast());
      debugPrint('[LibraryScreen] Navigated back from: ${folder.name}');
    } else {
      Navigator.pop(context);
    }
  }

  /// Create new folder
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
            border: const OutlineInputBorder(),
            hintText: 'Enter a name...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a name')),
                );
                return;
              }

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

              // Save immediately to SharedPreferences
              await _saveFolderSafe(folder);
              
              debugPrint('[LibraryScreen] Created folder: ${folder.name}');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  /// Create new glossary
  void _createGlossary() {
    if (_currentFolder == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Glossaries must be created inside a folder')),
      );
      return;
    }

    final TextEditingController nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Glossary'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Glossary Name *',
            border: OutlineInputBorder(),
            hintText: 'Enter a name...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a glossary name')),
                );
                return;
              }

              final glossary = GlossaryItem(
                id: _generateId(),
                name: nameController.text.trim(),
                parentId: _currentFolder!.id,
              );

              setState(() => _currentFolder!.addChild(glossary));
              Navigator.pop(context);

              // Save glossary metadata immediately to SharedPreferences
              await _saveGlossarySafe(glossary);
              
              debugPrint('[LibraryScreen] Created glossary: ${glossary.name}');
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Glossary created. Add entries inside the glossary.'),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  /// Show dialog to choose between folder/glossary creation
  void _showCreateDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.folder, color: Colors.orange),
              title: Text(_currentFolder == null ? 'Folder' : 'Subfolder'),
              subtitle: Text(_currentFolder == null 
                  ? 'Organize your glossaries'
                  : 'Create a subfolder'),
              onTap: () {
                Navigator.pop(context);
                _createFolder();
              },
            ),
            if (_currentFolder != null)
              ListTile(
                leading: const Icon(Icons.book, color: Colors.blue),
                title: const Text('Glossary'),
                subtitle: const Text('Add words and symbols'),
                onTap: () {
                  Navigator.pop(context);
                  _createGlossary();
                },
              ),
          ],
        ),
      ),
    );
  }

  /// Rename folder or glossary
  void _renameItem(dynamic item) {
    final TextEditingController nameController = TextEditingController(text: item.name);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Rename ${item is FolderItem ? "Folder" : "Glossary"}'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a name')),
                );
                return;
              }

              final oldName = item.name;
              setState(() => item.name = nameController.text.trim());
              Navigator.pop(context);

              // Save rename immediately to SharedPreferences
              if (item is FolderItem) {
                await _saveFolderSafe(item);
              } else if (item is GlossaryItem) {
                await _saveGlossarySafe(item);
              }
              
              debugPrint('[LibraryScreen] Renamed: "$oldName" → "${item.name}"');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  /// Toggle checkbox (for symbol detection)
  void _toggleCheckbox(dynamic item, bool newValue) {
    setState(() => item.isChecked = newValue);
    
    debugPrint('[LibraryScreen] Checkbox toggled: ${item.name} = $newValue');
    
    // Save checkbox state immediately to SharedPreferences
    if (item is FolderItem) {
      _glossaryService.saveFolder(item).catchError((e) {
        debugPrint('[LibraryScreen] Failed to save folder checkbox: $e');
      });
    } else if (item is GlossaryItem) {
      _glossaryService.saveGlossary(item).catchError((e) {
        debugPrint('[LibraryScreen] Failed to save glossary checkbox: $e');
      });
    }
  }

  /// Handle item tap (navigate or open glossary)
  Future<void> _handleItemTap(dynamic item) async {
    if (item is FolderItem) {
      _navigateToFolder(item);
    } else if (item is GlossaryItem) {
      debugPrint('[LibraryScreen] Opening glossary: ${item.name}');
      
      // Navigate to glossary screen
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GlossaryScreen(glossaryItem: item),
        ),
      );
      
      // Refresh library after returning from glossary screen
      // (in case entries were added/modified)
      debugPrint('[LibraryScreen] Returned from glossary, refreshing...');
    }
  }

  /// Build breadcrumb navigation path
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
          tooltip: 'Back',
        ),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Loading library...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
          : _currentItems.isNotEmpty
              ? GridView.builder(
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
                      onCheckboxChanged: (value) => _toggleCheckbox(item, value),
                    );
                  },
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.folder_open,
                        size: 64,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _currentFolder == null
                            ? 'No folders yet'
                            : 'No subfolders or glossaries yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
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
      floatingActionButton: FloatingActionButton(
        onPressed: _currentFolder == null ? _createFolder : _showCreateDialog,
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
        tooltip: _currentFolder == null ? 'Create Folder' : 'Create New',
      ),
    );
  }
}