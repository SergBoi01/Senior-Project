// ------------------------------------------------ //
//  What it does: load/save NotebookManager, autosave logic
// ------------------------------------------------ //

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notebook_model.dart';

class NotebookService {
  late NotebookManager notebookManager;

  Future<SharedPreferences> get _prefs async => await SharedPreferences.getInstance();

  Future<void> saveNotebook() async {
    final prefs = await _prefs;
    final data = {
      'pages': notebookManager.pages.map((p) => p.toJson()).toList(),
      'currentIndex': notebookManager.currentIndex,
    };
    await prefs.setString('notebook', jsonEncode(data));
  }

  Future<void> loadNotebook() async {
    final prefs = await _prefs;
    final saved = prefs.getString('notebook');
    if (saved == null) {
      notebookManager = NotebookManager();
      return;
    }
    final decoded = jsonDecode(saved);
    notebookManager = NotebookManager()
      ..pages = (decoded['pages'] as List).map((p) => NotebookPage.fromJson(p)).toList()
      ..currentIndex = decoded['currentIndex'] ?? 0;
  }
}
