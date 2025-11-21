import 'package:flutter/material.dart';
import 'dart:math';

import '../models/library_models.dart';
import '../widgets/library_item_card.dart';
import '../services/glossary_service.dart';
import '../services/preferences_service.dart';
import 'glossary_screen.dart';

class LibraryScreen extends StatefulWidget {
  final FolderItem? initialFolder; // For navigating into a specific folder

  const LibraryScreen({super.key, this.initialFolder});

  @override
  _LibraryScreenState createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  // Root level storage - only folders (glossaries are inside folders)
  List<FolderItem> _rootFolders = [];

  // Folder navigation stack to track current location
  final List<FolderItem> _folderStack = [];

  // Firestore service
  final GlossaryService _glossaryService = GlossaryService();
  
  // SharedPreferences service
  final PreferencesService _preferencesService = PreferencesService();
  
  // Loading state
  bool _isLoading = false;

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
    } else {
      // Load library structure from Firestore
      _loadLibrary();
    }
  }

  /// Load library structure from SharedPreferences and Firestore
  Future<void> _loadLibrary() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      // First, try to load from SharedPreferences for fast local access
      try {
        final cachedFolders = await _preferencesService.loadRootFolders();
        if (cachedFolders.isNotEmpty && mounted) {
          setState(() {
            _rootFolders = cachedFolders;
            _isLoading = false;
          });
          debugPrint('Loaded library from SharedPreferences');
        }
      } catch (e) {
        debugPrint('Error loading from SharedPreferences: $e');
      }

      // Then sync with Firestore in the background
      try {
        final rootFolders = await _glossaryService.loadRootFolders();
        if (mounted) {
          setState(() {
            _rootFolders = rootFolders;
            _isLoading = false;
          });
          // Save to SharedPreferences for next time
          await _preferencesService.saveRootFolders(rootFolders);
          debugPrint('Synced library with Firestore and saved to SharedPreferences');
        }
      } catch (e) {
        debugPrint('Error loading from Firestore: $e');
        // If Firestore fails but we have cached data, that's okay
        if (_rootFolders.isEmpty && mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to sync with server. Using cached data.')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error loading library: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load library: $e')),
        );
      }
    }
  }

  /// Save library structure to Firestore and SharedPreferences
  Future<void> _saveLibrary() async {
    try {
      // Save all root folders to Firestore (which will recursively save their children)
      for (var folder in _rootFolders) {
        await _saveFolderRecursive(folder);
      }
      
      // Also save to SharedPreferences for local caching
      await _preferencesService.saveRootFolders(_rootFolders);
      debugPrint('Saved library to Firestore and SharedPreferences');
    } catch (e) {
      debugPrint('Error saving library: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save library: $e')),
        );
      }
    }
  }

  /// Recursively save a folder and all its children
  Future<void> _saveFolderRecursive(FolderItem folder) async {
    // Save the folder itself
    await _glossaryService.saveFolder(folder);
    
    // Save all children
    for (var child in folder.children) {
      if (child is FolderItem) {
        // Recursively save subfolders
        await _saveFolderRecursive(child);
      } else if (child is GlossaryItem) {
        // Save glossary (already handled when created, but ensure it's saved)
        await _glossaryService.saveGlossary(child);
      }
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
            onPressed: () async {
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
                
                // Save folder to Firestore and SharedPreferences
                try {
                  await _glossaryService.saveFolder(folder);
                  await _preferencesService.saveFolder(folder);
                  // Save entire library structure to ensure consistency
                  await _saveLibrary();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to save folder: $e')),
                    );
                  }
                }
                
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
            onPressed: () async {
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
              
              // Save glossary to Firestore and SharedPreferences
              try {
                await _glossaryService.saveGlossary(glossary);
                await _preferencesService.saveGlossary(glossary);
                setState(() {
                  _currentFolder!.addChild(glossary);
                });
                // Save parent folder to update its children list
                await _preferencesService.saveFolder(_currentFolder!);
                Navigator.pop(context);
                // Show success message
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Glossary created successfully')),
                );
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to create glossary: $e')),
                );
              }
            },
            child: Text('Create'),
          ),
        ],
      ),
    );
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
            onPressed: () async {
              if (nameController.text.trim().isNotEmpty) {
                setState(() {
                  item.name = nameController.text.trim();
                });
                
                // Save to Firestore and SharedPreferences
                try {
                  if (item is GlossaryItem) {
                    await _glossaryService.saveGlossary(item);
                    await _preferencesService.saveGlossary(item);
                  } else if (item is FolderItem) {
                    await _glossaryService.saveFolder(item);
                    await _preferencesService.saveFolder(item);
                    // Save entire library to ensure consistency
                    await _saveLibrary();
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to save: $e')),
                  );
                }
                
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
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
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
