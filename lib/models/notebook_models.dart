import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'strokes_models.dart';

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

  void newPageAfterCurrent(String userId) {
    pages.insert(currentIndex + 1, NotebookPage());
    currentIndex++;
    saveToPrefs(userId);
  }

  void nextPage(String userId) {
    if (currentIndex == pages.length - 1) {
      pages.add(NotebookPage());
    }
    currentIndex++;
    saveToPrefs(userId);
  }

  void prevPage(String userId) {
    if (currentIndex > 0) {
      currentIndex--;
      saveToPrefs(userId);
    }
  }

  void deleteCurrentPage(String userId) {
    if (pages.isEmpty) return;

    deletedPages.insert(0, pages.removeAt(currentIndex));

    if (pages.isEmpty) {
      pages = [NotebookPage()];
      currentIndex = 0;
    } else if (currentIndex >= pages.length) {
      currentIndex = pages.length - 1;
    }

    saveToPrefs(userId);
  }

  void restoreLastDeleted(String userId) {
    if (deletedPages.isEmpty) return;

    pages.insert(currentIndex, deletedPages.removeAt(0));
    saveToPrefs(userId);
  }

  // --- SHARED PREFERENCES STORAGE ------------------------------------------

  Future<void> saveToPrefs(String userId) async {
    final prefs = await SharedPreferences.getInstance();

    final data = {
      'pages': pages.map((p) => p.toJson()).toList(),
      'currentIndex': currentIndex,
    };

    await prefs.setString(
      'user_${userId}_notebook',
      jsonEncode(data),
    );
  }

  Future<void> loadFromPrefs(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('user_${userId}_notebook');

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
