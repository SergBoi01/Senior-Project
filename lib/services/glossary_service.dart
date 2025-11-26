import 'package:firebase_auth/firebase_auth.dart';
import '../models/library_models.dart';
import 'preferences_service.dart';

class GlossaryService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final PreferencesService _prefsService = PreferencesService();

  String get _userId {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('User not logged in');
    return uid;
  }

  // -------------------------
  // FOLDERS / GLOSSARIES (instant saves via SharedPreferences)
  // -------------------------

  /// Save (create or update) a folder immediately.
  Future<void> saveFolder(FolderItem folder) async {
    try {
      print('[GS] saveFolder: saving folder id=${folder.id} name="${folder.name}" parent=${folder.parentId}');
      await _prefsService.saveFolder(_userId, folder);
      print('[GS] saveFolder: success');
    } catch (e) {
      print('[GS] saveFolder FAILED: $e');
      rethrow;
    }
  }

  /// Delete folder from SharedPreferences
  Future<void> deleteFolder(String folderId) async {
    try {
      print('[GS] deleteFolder: id=$folderId');
      final rootFolders = await _prefsService.loadRootFolders(_userId);
      _removeFolderFromTree(folderId, rootFolders);
      await _prefsService.saveRootFolders(_userId, rootFolders);
      print('[GS] deleteFolder: success');
    } catch (e) {
      print('[GS] deleteFolder FAILED: $e');
      rethrow;
    }
  }

  /// Save (create or update) a glossary metadata immediately.
  Future<void> saveGlossary(GlossaryItem glossary) async {
    try {
      print('[GS] saveGlossary: saving glossary id=${glossary.id} name="${glossary.name}" parent=${glossary.parentId}');
      await _prefsService.saveGlossary(_userId, glossary);
      print('[GS] saveGlossary: success');
    } catch (e) {
      print('[GS] saveGlossary FAILED: $e');
      rethrow;
    }
  }

  /// Delete glossary and its entries
  Future<void> deleteGlossary(String glossaryId) async {
    try {
      print('[GS] deleteGlossary: id=$glossaryId');
      
      // Remove glossary from tree
      final rootFolders = await _prefsService.loadRootFolders(_userId);
      _removeGlossaryFromTree(glossaryId, rootFolders);
      await _prefsService.saveRootFolders(_userId, rootFolders);
      
      // Clear its entries (optional, could keep for recovery)
      // Note: SharedPreferences keys will remain but won't be accessible
      
      print('[GS] deleteGlossary: success');
    } catch (e) {
      print('[GS] deleteGlossary FAILED: $e');
      rethrow;
    }
  }

  // -------------------------
  // LIBRARY LOADER (build tree)
  // -------------------------

  /// Loads folders and glossaries from SharedPreferences
  Future<List<FolderItem>> loadRootFolders() async {
    try {
      print('[GS] loadRootFolders: start for user=$_userId');
      
      final rootFolders = await _prefsService.loadRootFolders(_userId);
      
      print('[GS] loadRootFolders: loaded ${rootFolders.length} root folders');
      return rootFolders;
    } catch (e) {
      print('[GS] loadRootFolders FAILED: $e');
      rethrow;
    }
  }

  // -------------------------
  // GLOSSARY ENTRIES (saved by Save button in GlossaryScreen)
  // -------------------------

  /// Load entries for a glossary from SharedPreferences
  Future<List<GlossaryEntry>> loadEntries(String glossaryId) async {
    try {
      print('[GS] loadEntries: loading for glossary=$glossaryId');
      final entries = await _prefsService.loadEntries(_userId, glossaryId);
      print('[GS] loadEntries: loaded ${entries.length} entries');
      return entries;
    } catch (e) {
      print('[GS] loadEntries FAILED: $e');
      rethrow;
    }
  }

  /// Save all entries for a glossary (called when user clicks Save in GlossaryScreen)
  Future<void> saveAllEntries(String glossaryId, List<GlossaryEntry> entries) async {
    try {
      print('[GS] saveAllEntries: saving ${entries.length} entries for glossary=$glossaryId');
      
      // Assign IDs to new entries
      for (var entry in entries) {
        entry.id ??= '${glossaryId}_entry_${DateTime.now().millisecondsSinceEpoch}';
      }
      
      await _prefsService.saveAllEntries(_userId, glossaryId, entries);
      print('[GS] saveAllEntries: success');
    } catch (e) {
      print('[GS] saveAllEntries FAILED: $e');
      rethrow;
    }
  }

  /// Delete a single entry
  Future<void> deleteEntry(String glossaryId, String entryId) async {
    try {
      print('[GS] deleteEntry: glossary=$glossaryId entry=$entryId');
      
      // Load all entries, remove the one, save back
      final entries = await loadEntries(glossaryId);
      entries.removeWhere((e) => e.id == entryId);
      await saveAllEntries(glossaryId, entries);
      
      print('[GS] deleteEntry: success');
    } catch (e) {
      print('[GS] deleteEntry FAILED: $e');
      rethrow;
    }
  }

  // -------------------------
  // HELPER METHODS
  // -------------------------

  void _removeFolderFromTree(String folderId, List<FolderItem> folders) {
    folders.removeWhere((f) => f.id == folderId);
    
    for (var folder in folders) {
      folder.children.removeWhere((c) => c is FolderItem && c.id == folderId);
      
      // Recursively search subfolders
      final subfolders = folder.children.whereType<FolderItem>().toList();
      if (subfolders.isNotEmpty) {
        _removeFolderFromTree(folderId, subfolders);
      }
    }
  }

  void _removeGlossaryFromTree(String glossaryId, List<FolderItem> folders) {
    for (var folder in folders) {
      folder.children.removeWhere((c) => c is GlossaryItem && c.id == glossaryId);
      
      // Recursively search subfolders
      final subfolders = folder.children.whereType<FolderItem>().toList();
      if (subfolders.isNotEmpty) {
        _removeGlossaryFromTree(glossaryId, subfolders);
      }
    }
  }
}