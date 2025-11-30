import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/library_model.dart';

class LibraryService {
  static final LibraryService _instance = LibraryService._internal();
  factory LibraryService() => _instance;
  LibraryService._internal();

  List<FolderItem> rootFolders = [];
  Set<String> checkedGlossaryIds = {};
  static const _checkedGlossariesKey = 'checkedGlossaries';

  Future<SharedPreferences> get _prefs async => await SharedPreferences.getInstance();

  Future<void> loadLibrary() async {
    final prefs = await _prefs;

    // Load root folders
    final jsonStr = prefs.getString('libraryRootFolders');
    if (jsonStr != null && jsonStr.isNotEmpty) {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      rootFolders = list.map((json) => FolderItem.fromJson(json)).toList();
    }

    // Load checked glossary IDs
    final checkedIds = prefs.getStringList(_checkedGlossariesKey) ?? [];
    checkedGlossaryIds = checkedIds.toSet();

    void syncChecked(FolderItem folder) {
      for (var item in folder.children) {
        if (item is GlossaryItem) {
          item.isChecked = checkedGlossaryIds.contains(item.id);
        } else if (item is FolderItem) {
          syncChecked(item);
        }
      }
    }

    for (var folder in rootFolders) {
      syncChecked(folder);
    }
  }

  Future<void> saveLibrary() async {
    final prefs = await _prefs;
    final jsonList = rootFolders.map((f) => f.toJson()).toList();
    await prefs.setString('libraryRootFolders', jsonEncode(jsonList));
  }

  Future<List<GlossaryEntry>> loadEntries(String glossaryId) async {
    final prefs = await _prefs;
    final jsonStr = prefs.getString('glossary_entries_$glossaryId');
    if (jsonStr == null) return [];
    final list = jsonDecode(jsonStr) as List<dynamic>;
    return list.map((e) => GlossaryEntry.fromJson(e)).toList();
  }

  Future<void> updateGlossaryChecked(GlossaryItem glossary, bool isChecked) async {
    glossary.isChecked = isChecked;
    if (isChecked) {
      checkedGlossaryIds.add(glossary.id);
      glossary.entries = await loadEntries(glossary.id);
    } else {
      checkedGlossaryIds.remove(glossary.id);
      glossary.entries = [];
    }
    final prefs = await _prefs;
    await prefs.setStringList(_checkedGlossariesKey, checkedGlossaryIds.toList());
    await saveLibrary();
  }

  Future<void> toggleGlossaryChecked(GlossaryItem glossary, bool isChecked) async {
    await updateGlossaryChecked(glossary, isChecked);
  }

  Future<void> loadChildrenForFolder(FolderItem folder) async {
    if (folder.childrenLoaded) return;
    folder.childrenLoaded = true;
  }
}
