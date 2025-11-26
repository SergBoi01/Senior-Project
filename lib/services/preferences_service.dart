import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/library_models.dart';
import '../models/notebook_models.dart';
import '../models/strokes_models.dart';
import '../models/detection_settings_models.dart';

/// Complete local storage service using SharedPreferences
class PreferencesService {
  // Keys for different data types
  static const String _keyRootFolders = 'root_folders_';
  static const String _keyUserCorrections = 'user_corrections_';
  static const String _keyDetectionSettings = 'detection_settings_';
  static const String _keyPenWidth = 'pen_width_';
  static const String _keyGlossaryEntries = 'glossary_entries_';
  static const String _keyLastSyncTime = 'last_sync_time_';
  static const String _keyNotebookPages = 'notebook_pages_';

  Future<SharedPreferences> get _prefs async => await SharedPreferences.getInstance();

  // ==================== USER CORRECTIONS ====================
  
  Future<List<UserCorrection>> loadUserCorrections(String userId) async {
    try {
      final prefs = await _prefs;
      final saved = prefs.getString('$_keyUserCorrections$userId');
      if (saved == null) return [];
      
      final List<dynamic> jsonList = jsonDecode(saved);
      return jsonList.map((json) => UserCorrection.fromJson(json)).toList();
    } catch (e) {
      print('[PrefsService] Failed to load corrections: $e');
      return [];
    }
  }

  Future<void> saveUserCorrections(String userId, List<UserCorrection> corrections) async {
    try {
      final prefs = await _prefs;
      final jsonList = corrections.map((c) => c.toJson()).toList();
      await prefs.setString('$_keyUserCorrections$userId', jsonEncode(jsonList));
    } catch (e) {
      print('[PrefsService] Failed to save corrections: $e');
      rethrow;
    }
  }

  // ==================== DETECTION SETTINGS ====================
  
  Future<DetectionSettings> loadDetectionSettings(String userId) async {
    try {
      final prefs = await _prefs;
      final saved = prefs.getString('$_keyDetectionSettings$userId');
      if (saved == null) return DetectionSettings();
      
      return DetectionSettings.fromJson(jsonDecode(saved));
    } catch (e) {
      print('[PrefsService] Failed to load detection settings: $e');
      return DetectionSettings();
    }
  }

  Future<void> saveDetectionSettings(String userId, DetectionSettings settings) async {
    try {
      final prefs = await _prefs;
      await prefs.setString('$_keyDetectionSettings$userId', jsonEncode(settings.toJson()));
    } catch (e) {
      print('[PrefsService] Failed to save detection settings: $e');
      rethrow;
    }
  }

  // ==================== PEN WIDTH ====================
  
  Future<double> loadPenWidth(String userId) async {
    try {
      final prefs = await _prefs;
      return prefs.getDouble('$_keyPenWidth$userId') ?? 10.0;
    } catch (e) {
      print('[PrefsService] Failed to load pen width: $e');
      return 10.0;
    }
  }

  Future<void> savePenWidth(String userId, double width) async {
    try {
      final prefs = await _prefs;
      await prefs.setDouble('$_keyPenWidth$userId', width);
    } catch (e) {
      print('[PrefsService] Failed to save pen width: $e');
      rethrow;
    }
  }
  
  // ==================== LIBRARY STRUCTURE (FOLDERS) ====================
  
  Future<List<FolderItem>> loadRootFolders(String userId) async {
    try {
      final prefs = await _prefs;
      final jsonString = prefs.getString('$_keyRootFolders$userId');
      
      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }
      
      final List<dynamic> foldersJson = jsonDecode(jsonString);
      return foldersJson.map((json) => _folderFromJson(json)).toList();
    } catch (e) {
      print('[PrefsService] Failed to load root folders: $e');
      return [];
    }
  }

  Future<void> saveRootFolders(String userId, List<FolderItem> folders) async {
    try {
      final prefs = await _prefs;
      final foldersJson = folders.map((folder) => _folderToJson(folder)).toList();
      final jsonString = jsonEncode(foldersJson);
      
      await prefs.setString('$_keyRootFolders$userId', jsonString);
      await prefs.setString('$_keyLastSyncTime$userId', DateTime.now().toIso8601String());
    } catch (e) {
      print('[PrefsService] Failed to save root folders: $e');
      rethrow;
    }
  }

  // ==================== INDIVIDUAL FOLDER/GLOSSARY SAVES ====================
  
  Future<void> saveFolder(String userId, FolderItem folder) async {
    try {
      final rootFolders = await loadRootFolders(userId);
      _updateFolderInTree(folder, rootFolders);
      await saveRootFolders(userId, rootFolders);
    } catch (e) {
      print('[PrefsService] Failed to save folder: $e');
      rethrow;
    }
  }

  Future<void> saveGlossary(String userId, GlossaryItem glossary) async {
    try {
      final rootFolders = await loadRootFolders(userId);
      _updateGlossaryInTree(glossary, rootFolders);
      await saveRootFolders(userId, rootFolders);
    } catch (e) {
      print('[PrefsService] Failed to save glossary: $e');
      rethrow;
    }
  }

  // ==================== GLOSSARY ENTRIES ====================
  
  Future<List<GlossaryEntry>> loadEntries(String userId, String glossaryId) async {
    try {
      final prefs = await _prefs;
      final key = '$_keyGlossaryEntries${userId}_$glossaryId';
      final saved = prefs.getString(key);
      
      if (saved == null) return [];
      
      final List<dynamic> jsonList = jsonDecode(saved);
      return jsonList.map((json) => _entryFromJson(json)).toList();
    } catch (e) {
      print('[PrefsService] Failed to load entries: $e');
      return [];
    }
  }

  Future<void> saveAllEntries(String userId, String glossaryId, List<GlossaryEntry> entries) async {
    try {
      final prefs = await _prefs;
      final key = '$_keyGlossaryEntries${userId}_$glossaryId';
      final jsonList = entries.map((entry) => _entryToJson(entry)).toList();
      await prefs.setString(key, jsonEncode(jsonList));
      
      // Also update the glossary's entry count in the tree
      final rootFolders = await loadRootFolders(userId);
      final glossary = _findGlossaryById(glossaryId, rootFolders);
      if (glossary != null) {
        glossary.entries = entries;
        await saveRootFolders(userId, rootFolders);
      }
    } catch (e) {
      print('[PrefsService] Failed to save entries: $e');
      rethrow;
    }
  }

  // ==================== HELPER METHODS ====================
  
  void _updateFolderInTree(FolderItem folder, List<FolderItem> rootFolders) {
    if (folder.parentId == null) {
      // Root level folder
      final index = rootFolders.indexWhere((f) => f.id == folder.id);
      if (index >= 0) {
        rootFolders[index] = folder;
      } else {
        rootFolders.add(folder);
      }
    } else {
      // Find parent and update
      _updateFolderInParent(folder, rootFolders);
    }
  }

  void _updateFolderInParent(FolderItem folder, List<FolderItem> folders) {
    for (var parent in folders) {
      if (parent.id == folder.parentId) {
        final index = parent.children.indexWhere((c) => c is FolderItem && c.id == folder.id);
        if (index >= 0) {
          parent.children[index] = folder;
        } else {
          parent.children.add(folder);
        }
        return;
      }
      // Recursively search subfolders
      for (var child in parent.children) {
        if (child is FolderItem) {
          _updateFolderInParent(folder, [child]);
        }
      }
    }
  }

  void _updateGlossaryInTree(GlossaryItem glossary, List<FolderItem> rootFolders) {
    for (var folder in rootFolders) {
      if (folder.id == glossary.parentId) {
        final index = folder.children.indexWhere((c) => c is GlossaryItem && c.id == glossary.id);
        if (index >= 0) {
          folder.children[index] = glossary;
        } else {
          folder.children.add(glossary);
        }
        return;
      }
      // Recursively search subfolders
      for (var child in folder.children) {
        if (child is FolderItem) {
          _updateGlossaryInTree(glossary, [child]);
        }
      }
    }
  }

  GlossaryItem? _findGlossaryById(String glossaryId, List<FolderItem> folders) {
    for (var folder in folders) {
      for (var child in folder.children) {
        if (child is GlossaryItem && child.id == glossaryId) {
          return child;
        } else if (child is FolderItem) {
          final found = _findGlossaryById(glossaryId, [child]);
          if (found != null) return found;
        }
      }
    }
    return null;
  }

  // ==================== JSON CONVERSION ====================
  
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

  Map<String, dynamic> _glossaryToJson(GlossaryItem glossary) {
    return {
      'id': glossary.id,
      'name': glossary.name,
      'isChecked': glossary.isChecked,
      'parentId': glossary.parentId,
      'entriesCount': glossary.entries.length,
    };
  }

  GlossaryItem _glossaryFromJson(Map<String, dynamic> json) {
    return GlossaryItem(
      id: json['id'] as String,
      name: json['name'] as String,
      isChecked: json['isChecked'] as bool? ?? false,
      parentId: json['parentId'] as String?,
      entries: [], // Loaded separately when needed
    );
  }

  Map<String, dynamic> _entryToJson(GlossaryEntry entry) {
    return {
      'id': entry.id,
      'english': entry.english,
      'spanish': entry.spanish,
      'definition': entry.definition,
      'synonym': entry.synonym,
      'symbolImage': entry.symbolImage != null ? base64Encode(entry.symbolImage!) : null,
      'strokes': entry.strokes?.map((s) => s.toJson()).toList(),
    };
  }

  GlossaryEntry _entryFromJson(Map<String, dynamic> json) {
    return GlossaryEntry(
      id: json['id'] as String?,
      english: json['english'] as String,
      spanish: json['spanish'] as String,
      definition: json['definition'] as String,
      synonym: json['synonym'] as String,
      symbolImage: json['symbolImage'] != null ? base64Decode(json['symbolImage']) : null,
      strokes: (json['strokes'] as List<dynamic>?)?.map((s) => Stroke.fromJson(s)).toList(),
    );
  }

  // ==================== CLEANUP ====================
  
  Future<void> clearAllData(String userId) async {
    try {
      final prefs = await _prefs;
      final keys = prefs.getKeys().where((key) => key.contains(userId));
      for (var key in keys) {
        await prefs.remove(key);
      }
    } catch (e) {
      print('[PrefsService] Failed to clear data: $e');
      rethrow;
    }
  }

  Future<DateTime?> getLastSyncTime(String userId) async {
    try {
      final prefs = await _prefs;
      final timeString = prefs.getString('$_keyLastSyncTime$userId');
      if (timeString == null) return null;
      return DateTime.parse(timeString);
    } catch (e) {
      return null;
    }
  }
}