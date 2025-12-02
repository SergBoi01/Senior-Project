import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/library_models.dart';

/// Service class to handle library data persistence using SharedPreferences
class LibraryStorage {
  static const String _storageKey = 'library_folders';

  /// Save the list of root folders to SharedPreferences
  static Future<void> saveFolders(List<FolderItem> folders) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = folders.map((folder) => folder.toJson()).toList();
    final jsonString = jsonEncode(jsonList);
    await prefs.setString(_storageKey, jsonString);
  }

  /// Load the list of root folders from SharedPreferences
  static Future<List<FolderItem>> loadFolders() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_storageKey);
    
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    try {
      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      return jsonList
          .map((json) => FolderItem.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // If there's an error parsing, return empty list
      print('Error loading library data: $e');
      return [];
    }
  }

  /// Clear all library data
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}

