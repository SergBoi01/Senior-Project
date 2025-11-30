import 'library_services.dart';
import 'notebook_services.dart';
import 'correction_services.dart';
import 'settings_services.dart';

import '/models/library_model.dart';

class BackendManager {
  static final BackendManager _instance = BackendManager._internal();
  factory BackendManager() => _instance;
  BackendManager._internal();

  final LibraryService libraryService = LibraryService();
  final NotebookService notebookService = NotebookService();
  final CorrectionService correctionService = CorrectionService();
  final SettingsService settingsService = SettingsService();

  bool isLoaded = false;

  Future<void> loadUserData() async {
    try {
      // 1. Load corrections and settings first
      await correctionService.loadCorrections();
      await settingsService.loadSettings();

      // 2. Load library structure (folders + checked state + entries)
      await libraryService.loadLibrary();

      // 3. Collect all checked glossaries
      final List<GlossaryItem> checkedGlossaries = [];
      void findCheckedGlossaries(List<FolderItem> folders) {
        for (var f in folders) {
          for (var item in f.children) {
            if (item is GlossaryItem && item.isChecked) checkedGlossaries.add(item);
            else if (item is FolderItem) findCheckedGlossaries([item]);
          }
        }
      }
      findCheckedGlossaries(libraryService.rootFolders);

      // 4. Ensure all checked glossaries have entries loaded
      await Future.wait(
        checkedGlossaries.map((g) async {
          if (g.entries.isEmpty) g.entries = await libraryService.loadEntries(g.id);
        }),
      );

      // 5. Load notebook
      await notebookService.loadNotebook();

      isLoaded = true;
      print('[BackendManager] User data fully loaded.');
    } catch (e) {
      print('[BackendManager] loadUserData FAILED: $e');
      rethrow;
    }
  }

  Future<void> saveUserData() async {
    try {
      await correctionService.saveCorrections();
      await settingsService.saveSettings();
      await libraryService.saveLibrary();
      await notebookService.saveNotebook();
    } catch (e) {
      print('[BackendManager] saveUserData FAILED: $e');
      rethrow;
    }
  }
}
