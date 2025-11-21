import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/library_models.dart';

/// Service for managing local storage using SharedPreferences
class PreferencesService {
  static const String _keyRootFolders = 'root_folders';
  static const String _keyLastSyncTime = 'last_sync_time';

  Future<List<dynamic>> loadUserCorrections(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('user_corrections_$userId');
    if (saved != null) {
      return List<dynamic>.from(jsonDecode(saved));
    }
    return [];
  }

  Future<void> saveUserCorrections(String userId, List<dynamic> corrections) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_corrections_$userId', jsonEncode(corrections));
  }

  Future<Map<String, dynamic>?> loadDetectionSettings(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('detection_settings_$userId');
    return saved != null ? jsonDecode(saved) : null;
  }

  Future<void> saveDetectionSettings(String userId, Map<String, dynamic> json) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('detection_settings_$userId', jsonEncode(json));
  }

  /// Get SharedPreferences instance
  Future<SharedPreferences> get _prefs async {
    return await SharedPreferences.getInstance();
  }

  /// Save root folders to SharedPreferences
  Future<void> saveRootFolders(List<FolderItem> folders) async {
    try {
      final prefs = await _prefs;
      
      // Convert folders to JSON
      final foldersJson = folders.map((folder) => _folderToJson(folder)).toList();
      final jsonString = jsonEncode(foldersJson);
      
      await prefs.setString(_keyRootFolders, jsonString);
      await prefs.setString(_keyLastSyncTime, DateTime.now().toIso8601String());
    } catch (e) {
      throw Exception('Failed to save folders to SharedPreferences: $e');
    }
  }

  /// Load root folders from SharedPreferences
  Future<List<FolderItem>> loadRootFolders() async {
    try {
      final prefs = await _prefs;
      final jsonString = prefs.getString(_keyRootFolders);
      
      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }
      
      final List<dynamic> foldersJson = jsonDecode(jsonString);
      return foldersJson.map((json) => _folderFromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to load folders from SharedPreferences: $e');
    }
  }

  /// Save a single folder to SharedPreferences
  Future<void> saveFolder(FolderItem folder) async {
    try {
      final rootFolders = await loadRootFolders();
      
      // Check if folder is a root folder
      if (folder.parentId == null) {
        // Update or add root folder
        final index = rootFolders.indexWhere((f) => f.id == folder.id);
        if (index >= 0) {
          rootFolders[index] = folder;
        } else {
          rootFolders.add(folder);
        }
        await saveRootFolders(rootFolders);
      } else {
        // Save folder in its parent's children
        await _saveFolderInParent(folder, rootFolders);
      }
    } catch (e) {
      throw Exception('Failed to save folder: $e');
    }
  }

  /// Recursively save folder in its parent
  Future<void> _saveFolderInParent(FolderItem folder, List<FolderItem> rootFolders) async {
    for (var rootFolder in rootFolders) {
      if (rootFolder.id == folder.parentId) {
        // Found parent, update or add folder
        final index = rootFolder.children.indexWhere((child) => 
          child is FolderItem && child.id == folder.id);
        if (index >= 0) {
          rootFolder.children[index] = folder;
        } else {
          rootFolder.children.add(folder);
        }
        await saveRootFolders(rootFolders);
        return;
      } else {
        // Recursively search in subfolders
        for (var child in rootFolder.children) {
          if (child is FolderItem) {
            await _saveFolderInParent(folder, [child]);
          }
        }
      }
    }
  }

  /// Save a glossary to SharedPreferences
  Future<void> saveGlossary(GlossaryItem glossary) async {
    try {
      final rootFolders = await loadRootFolders();
      
      if (glossary.parentId == null) {
        // Glossary must have a parent, skip if null
        return;
      }
      
      // Find parent folder and update glossary
      await _saveGlossaryInParent(glossary, rootFolders);
      await saveRootFolders(rootFolders);
    } catch (e) {
      throw Exception('Failed to save glossary: $e');
    }
  }

  /// Recursively save glossary in its parent
  Future<void> _saveGlossaryInParent(GlossaryItem glossary, List<FolderItem> folders) async {
    for (var folder in folders) {
      if (folder.id == glossary.parentId) {
        // Found parent, update or add glossary
        final index = folder.children.indexWhere((child) => 
          child is GlossaryItem && child.id == glossary.id);
        if (index >= 0) {
          folder.children[index] = glossary;
        } else {
          folder.children.add(glossary);
        }
        return;
      } else {
        // Recursively search in subfolders
        for (var child in folder.children) {
          if (child is FolderItem) {
            await _saveGlossaryInParent(glossary, [child]);
          }
        }
      }
    }
  }

  /// Get last sync time
  Future<DateTime?> getLastSyncTime() async {
    try {
      final prefs = await _prefs;
      final timeString = prefs.getString(_keyLastSyncTime);
      if (timeString == null) return null;
      return DateTime.parse(timeString);
    } catch (e) {
      return null;
    }
  }

  /// Clear all saved data
  Future<void> clearAll() async {
    try {
      final prefs = await _prefs;
      await prefs.remove(_keyRootFolders);
      await prefs.remove(_keyLastSyncTime);
    } catch (e) {
      throw Exception('Failed to clear SharedPreferences: $e');
    }
  }

  /// Convert FolderItem to JSON
  Map<String, dynamic> _folderToJson(FolderItem folder) {
    return {
      'id': folder.id,
      'name': folder.name,
      'isChecked': folder.isChecked,
      'parentId': folder.parentId,
      'children': folder.children.map((child) {
        if (child is FolderItem) {
          return {'type': 'folder', 'data': _folderToJson(child)};
        } else if (child is GlossaryItem) {
          return {'type': 'glossary', 'data': _glossaryToJson(child)};
        }
        return null;
      }).where((item) => item != null).toList(),
    };
  }

  /// Convert JSON to FolderItem
  FolderItem _folderFromJson(Map<String, dynamic> json) {
    final children = (json['children'] as List<dynamic>?)
        ?.map((childJson) {
          final type = childJson['type'] as String;
          final data = childJson['data'] as Map<String, dynamic>;
          if (type == 'folder') {
            return _folderFromJson(data) as dynamic;
          } else if (type == 'glossary') {
            return _glossaryFromJson(data) as dynamic;
          }
          return null;
        })
        .where((item) => item != null)
        .toList() ?? [];
    
    return FolderItem(
      id: json['id'] as String,
      name: json['name'] as String,
      isChecked: json['isChecked'] as bool? ?? false,
      parentId: json['parentId'] as String?,
      children: children,
    );
  }

  /// Convert GlossaryItem to JSON
  Map<String, dynamic> _glossaryToJson(GlossaryItem glossary) {
    return {
      'id': glossary.id,
      'name': glossary.name,
      'isChecked': glossary.isChecked,
      'parentId': glossary.parentId,
      'entriesCount': glossary.entries.length, // Only save count, not entries
    };
  }

  /// Convert JSON to GlossaryItem
  GlossaryItem _glossaryFromJson(Map<String, dynamic> json) {
    return GlossaryItem(
      id: json['id'] as String,
      name: json['name'] as String,
      isChecked: json['isChecked'] as bool? ?? false,
      parentId: json['parentId'] as String?,
      entries: [], // Entries will be loaded from Firestore when needed
    );
  }
}

