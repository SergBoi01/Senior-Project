// screens/library_screen.dart
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

  Future<void> _loadLibrary() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      debugPrint('[LIB] _loadLibrary: start');
      final rootFolders = await _glossaryService.loadRootFolders();
      if (!mounted) return;
      setState(() {
        _rootFolders = rootFolders;
        _isLoading = false;
      });
      debugPrint('[LIB] _loadLibrary: loaded ${_rootFolders.length} root folders');
    } catch (e) {
      debugPrint('[LIB] _loadLibrary FAILED: $e');
      if (mounted) setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load library: $e')),
      );
    }
  }

  Future<void> _saveFolderRecursive(FolderItem folder) async {
    // Ensure folder metadata saved (should already be saved when created/renamed)
    await _glossary_service_saveFolderSafe(folder);
    for (var child in folder.children) {
      if (child is FolderItem) {
        await _saveFolderRecursive(child);
      } else if (child is GlossaryItem) {
        // Ensure glossary metadata saved if needed
        await _glossary_service_saveGlossarySafe(child);
      }
    }
  }

  Future<void> _glossary_service_saveFolderSafe(FolderItem folder) async {
    try {
      await _glossaryService.saveFolder(folder);
      debugPrint('[LIB] saved folder ${folder.id}');
    } catch (e) {
      debugPrint('[LIB] saveFolder FAILED for ${folder.id}: $e');
    }
  }

  Future<void> _glossary_service_saveGlossarySafe(GlossaryItem g) async {
    try {
      await _glossaryService.saveGlossary(g);
      debugPrint('[LIB] saved glossary ${g.id}');
    } catch (e) {
      debugPrint('[LIB] saveGlossary FAILED for ${g.id}: $e');
    }
  }

  String _generateId() => DateTime.now().millisecondsSinceEpoch.toString() + Random().nextInt(1000).toString();

  void _navigateToFolder(FolderItem folder) {
    setState(() => _folderStack.add(folder));
  }

  void _navigateBack() {
    if (_folderStack.isNotEmpty) {
      setState(() => _folderStack.removeLast());
    } else {
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
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;

              final folder = FolderItem(
                id: _generateId(),
                name: nameController.text.trim(),
                parentId: _currentFolder?.id,
              );

              setState(() {
                if (_currentFolder == null) _rootFolders.add(folder);
                else _currentFolder!.addChild(folder);
              });

              Navigator.pop(context);

              // Persist immediately
              try {
                debugPrint('[LIB] createFolder: saving folder id=${folder.id}');
                await _glossaryService.saveFolder(folder);
                debugPrint('[LIB] createFolder: saved folder id=${folder.id}');
              } catch (e) {
                debugPrint('[LIB] createFolder FAILED: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save folder: $e')));
                }
              }
            },
            child: Text('Create'),
          ),
        ],
      ),
    );
  }

  void _createGlossary() {
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
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please enter a glossary name')));
                return;
              }

              final glossary = GlossaryItem(
                id: _generateId(),
                name: nameController.text.trim(),
                parentId: _currentFolder!.id,
              );

              setState(() => _currentFolder!.addChild(glossary));
              Navigator.pop(context);

              // Persist glossary metadata immediately
              try {
                debugPrint('[LIB] createGlossary: saving glossary id=${glossary.id}');
                await _glossaryService.saveGlossary(glossary);
                debugPrint('[LIB] createGlossary: saved glossary id=${glossary.id}');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Glossary created. Remember to Save inside the Glossary screen.')),
                );
              } catch (e) {
                debugPrint('[LIB] createGlossary FAILED: $e');
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save glossary: $e')));
              }
            },
            child: Text('Create'),
          ),
        ],
      ),
    );
  }

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
            if (_currentFolder != null)
              ListTile(
                leading: Icon(Icons.book),
                title: Text('Glossary'),
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
          decoration: InputDecoration(
            labelText: 'Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;

              setState(() => item.name = nameController.text.trim());
              Navigator.pop(context);

              // Persist rename immediately
              try {
                if (item is FolderItem) {
                  debugPrint('[LIB] renameItem: saving folder ${item.id}');
                  await _glossaryService.saveFolder(item);
                } else if (item is GlossaryItem) {
                  debugPrint('[LIB] renameItem: saving glossary ${item.id}');
                  await _glossaryService.saveGlossary(item);
                }
                debugPrint('[LIB] renameItem: saved ${item.id}');
              } catch (e) {
                debugPrint('[LIB] renameItem FAILED: $e');
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
              }
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
  }

  void _toggleCheckbox(dynamic item, bool newValue) {
    setState(() => item.isChecked = newValue);
    // Immediately persist checkbox change
    if (item is FolderItem) {
      _glossaryService.saveFolder(item).catchError((e) => debugPrint('[LIB] toggleCheckbox saveFolder FAILED: $e'));
    } else if (item is GlossaryItem) {
      _glossaryService.saveGlossary(item).catchError((e) => debugPrint('[LIB] toggleCheckbox saveGlossary FAILED: $e'));
    }
  }

  Future<void> _handleItemTap(dynamic item) async {
    if (item is FolderItem) {
      _navigateToFolder(item);
    } else if (item is GlossaryItem) {
      // Pass the glossary to GlossaryScreen; GlossaryScreen will perform entry saves itself.
      final updated = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => GlossaryScreen(glossaryItem: item)),
      );

      if (updated != null && updated is GlossaryItem) {
        setState(() {
          final idx = _currentItems.indexWhere((c) => (c is GlossaryItem) && c.id == updated.id);
          if (idx != -1) _currentItems[idx] = updated;
        });
      }
    }
  }

  String _buildBreadcrumb() => _folderStack.isEmpty ? 'Library' : _folderStack.map((f) => f.name).join(' / ');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[300],
      appBar: AppBar(
        title: Text(_buildBreadcrumb(), style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back, color: Colors.black), onPressed: _navigateBack),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _currentItems.isNotEmpty
              ? GridView.builder(
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
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.folder_open, size: 64, color: Colors.grey[600]),
                      SizedBox(height: 16),
                      Text(
                        _currentFolder == null ? 'No folders yet' : 'No subfolders or glossaries yet',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                      SizedBox(height: 8),
                      Text('Tap the + button to create', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _currentFolder == null ? _createFolder : _showCreateDialog,
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        child: Icon(Icons.add),
      ),
    );
  }
}
