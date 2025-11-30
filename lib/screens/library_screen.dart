import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

import '../models/library_model.dart';
import '../widgets/library_item_card_widget.dart';
import '../services/library_services.dart';
import 'glossary_screen.dart';

class LibraryScreen extends StatefulWidget {

  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<FolderItem> _rootFolders = [];
  final List<FolderItem> _folderStack = [];

  final LibraryService _libraryService = LibraryService();
  bool _isLoading = false;

  FolderItem? get _currentFolder =>
      _folderStack.isEmpty ? null : _folderStack.last;

  List<dynamic> get _currentItems =>
      _currentFolder?.children ?? _rootFolders;

  @override
  void initState() {
    super.initState();
    
      _loadLibrary();
    
  }

  // Load the library
  Future<void> _loadLibrary() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      await _libraryService.loadLibrary();

      if (!mounted) return;
      setState(() {
        _rootFolders = _libraryService.rootFolders;
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

  // Save folder or glossary
  Future<void> _saveLibrary() async {
    try {
      if (_currentFolder == null) {
        await _libraryService.saveLibrary();
      } else {
        await _libraryService.saveFolderChildren(_currentFolder!);
      }

      debugPrint('[LibraryScreen] Saved changes');
    } catch (e) {
      debugPrint('[LibraryScreen] Failed to save: $e');
    }
  }

  String _generateId() =>
      DateTime.now().millisecondsSinceEpoch.toString() +
      Random().nextInt(1000).toString();

  void _navigateToFolder(FolderItem folder) async {
    debugPrint('[LibraryScreen] Navigating to folder: ${folder.name}');

    // Load children from disk if not loaded yet
    await _libraryService.loadChildrenForFolder(folder);

    setState(() {
      _folderStack.add(folder);
    });

    debugPrint('[LibraryScreen] Loaded ${folder.children.length} items for ${folder.name}');
  }

  void _navigateBack() {
    debugPrint('[LibraryScreen] _navigateBack called, stack size: ${_folderStack.length}');
    
    if (_folderStack.isNotEmpty) {
      final folder = _folderStack.last;
      setState(() => _folderStack.removeLast());
      debugPrint('[LibraryScreen] Navigated back from: ${folder.name}, new stack size: ${_folderStack.length}');
      debugPrint('[LibraryScreen] Current items count: ${_currentItems.length}');
    } else {
      debugPrint('[LibraryScreen] Stack empty, going back to main');
      Navigator.pop(context);
    }
  }

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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a name')),
                );
                return;
              }

              final folder = FolderItem(
                id: _generateId(),
                name: name,
                parentId: _currentFolder?.id,
              );

              setState(() {
                if (_currentFolder == null) {
                  _rootFolders.add(folder);
                } else {
                  _currentFolder!.addChild(folder);
                }
              });

              await _saveLibrary();

              final prefs = await SharedPreferences.getInstance();
              final str = prefs.getString('libraryRootFolders');

              debugPrint('Saved library: $str');
              debugPrint('Library saved: ${prefs.getString('libraryRootFolders')}');

              Navigator.pop(context);
              
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _createGlossary() {
    if (_currentFolder == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Glossaries must be inside a folder')),
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a glossary name')),
                );
                return;
              }

              final glossary = GlossaryItem(
                id: _generateId(),
                name: name,
                parentId: _currentFolder!.id,
              );

              setState(() => _currentFolder!.addChild(glossary));
              Navigator.pop(context);
              await _saveLibrary();

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Glossary created. Add entries inside.')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

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
              subtitle: Text(_currentFolder == null ? 'Organize your glossaries' : 'Create a subfolder'),
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              if (newName.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a name')),
                );
                return;
              }
              setState(() => item.name = newName);
              Navigator.pop(context);

              if (item is FolderItem) {
                await _saveLibrary();
              } else if (item is GlossaryItem) {
                await _saveLibrary();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _toggleCheckbox(dynamic item, bool newValue) async {
    setState(() => item.isChecked = newValue);

    // Update SharedPreferences
    if (item is GlossaryItem) {
      final prefs = await SharedPreferences.getInstance();
      List<String> checkedIds = prefs.getStringList('checkedGlossaries') ?? [];

      if (newValue) {
        if (!checkedIds.contains(item.id)) checkedIds.add(item.id);
        // Optionally load entries now
        item.entries = await _libraryService.loadEntries(item.id);
      } else {
        checkedIds.remove(item.id);
        item.entries = []; // unload entries
      }

      await prefs.setStringList('checkedGlossaries', checkedIds);
    }

    // Save folder structure too
    await _libraryService.saveLibrary();
  }


  Future<void> _handleItemTap(dynamic item) async {
    if (item is FolderItem) {
      _navigateToFolder(item);
    } else if (item is GlossaryItem) {
      debugPrint('[LibraryScreen] Opening glossary: ${item.name}');
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => GlossaryScreen(glossaryItem: item)),
      );
    }
  }

  String _buildBreadcrumb() =>
      _folderStack.isEmpty ? 'Library' : _folderStack.map((f) => f.name).join(' / ');

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
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
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
                      Icon(Icons.folder_open, size: 64, color: Colors.grey[600]),
                      const SizedBox(height: 16),
                      Text(
                        _currentFolder == null
                            ? 'No folders yet'
                            : 'No subfolders or glossaries yet',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap the + button to create',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
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
