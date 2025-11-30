// ------------------------------------------------ //
//  Classes: NotebookPage, 
//           NotebookManager
// ------------------------------------------------ //

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'strokes_model.dart';

class NotebookPage {
  List<Stroke> strokes;

  NotebookPage({List<Stroke>? strokes})
      : strokes = strokes ?? [];

  Map<String, dynamic> toJson() => {
        'strokes': strokes.map((s) => s.toJson()).toList(),
      };

  factory NotebookPage.fromJson(Map<String, dynamic> json) {
    List<Stroke> strokes = [];

    if (json['strokes'] != null) {
      for (var s in json['strokes']) {
        strokes.add(Stroke.fromJson(s));
      }
    }

    return NotebookPage(strokes: strokes);
  }
}

class NotebookManager {
  List<NotebookPage> pages = [];
  int currentIndex = 0;
  List<NotebookPage> deletedPages = [];

  NotebookManager() {
    pages = [NotebookPage()];
  }

  NotebookPage get currentPage => pages[currentIndex];

  // --- PAGE OPERATIONS -------------------------------------------------------

  void newPageAfterCurrent() {
    pages.insert(currentIndex + 1, NotebookPage());
    currentIndex++;
    saveToPrefs();
  }

  void nextPage() {
    if (currentIndex == pages.length - 1) {
      pages.add(NotebookPage());
    }
    currentIndex++;
    saveToPrefs();
  }

  void prevPage() {
    if (currentIndex > 0) {
      currentIndex--;
      saveToPrefs();
    }
  }

  void deleteCurrentPage() {
    if (pages.isEmpty) return;

    deletedPages.insert(0, pages.removeAt(currentIndex));

    if (pages.isEmpty) {
      pages = [NotebookPage()];
      currentIndex = 0;
    } else if (currentIndex >= pages.length) {
      currentIndex = pages.length - 1;
    }

    saveToPrefs();
  }

  void restoreLastDeleted() {
    if (deletedPages.isEmpty) return;

    pages.insert(currentIndex, deletedPages.removeAt(0));
    saveToPrefs();
  }

  // --- SHARED PREFERENCES STORAGE ------------------------------------------

  Future<void> saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    final data = {
      'pages': pages.map((p) => p.toJson()).toList(),
      'currentIndex': currentIndex,
    };

    await prefs.setString(
      'user__notebook',
      jsonEncode(data),
    );
  }

  Future<void> loadFromPrefs( ) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('user_notebook');

    if (saved == null) {
      pages = [NotebookPage()];
      currentIndex = 0;
      return;
    }

    try {
      final decoded = jsonDecode(saved);
      pages = (decoded['pages'] as List)
          .map((p) => NotebookPage.fromJson(p))
          .toList();

      currentIndex = decoded['currentIndex'] ?? 0;

      // Safety: ensure at least one page exists
      if (pages.isEmpty) {
        pages = [NotebookPage()];
        currentIndex = 0;
      }
    } catch (e) {
      // corrupted data fallback
      pages = [NotebookPage()];
      currentIndex = 0;
    }
  }
}
