import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main_page.dart'; // For Stroke class

class NotebookPage {
  List<Stroke> strokes;

  NotebookPage({List<Stroke>? strokes})
      : strokes = strokes ?? [];

  Map<String, dynamic> toJson() => {
        'strokes': strokes
            .map((s) => {
                  'points': s.points
                      .map((p) => {'dx': p.dx, 'dy': p.dy})
                      .toList(),
                  'startTime': s.startTime.millisecondsSinceEpoch,
                  'endTime': s.endTime.millisecondsSinceEpoch,
                })
            .toList(),
      };

  factory NotebookPage.fromJson(Map<String, dynamic> json) {
    List<Stroke> strokes = [];
    if (json['strokes'] != null) {
      for (var s in json['strokes']) {
        List<Offset> points = (s['points'] as List)
            .map((p) => Offset(p['dx'], p['dy']))
            .toList();
        strokes.add(Stroke(
          points: points,
          startTime: DateTime.fromMillisecondsSinceEpoch(s['startTime']),
          endTime: DateTime.fromMillisecondsSinceEpoch(s['endTime']),
        ));
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
    pages.add(NotebookPage()); // start with one page
  }

  NotebookPage get currentPage => pages[currentIndex];

  void newPageAfterCurrent() {
    pages.insert(currentIndex + 1, NotebookPage());
    currentIndex++;
    saveToPrefs();
  }

  void nextPage() {
    if (currentIndex == pages.length - 1) {
      // At last page → create new one
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
    if (pages.isNotEmpty) {
      deletedPages.insert(0, pages.removeAt(currentIndex));
      if (currentIndex >= pages.length && pages.isNotEmpty) {
        currentIndex = pages.length - 1;
      } else if (pages.isEmpty) {
        pages.add(NotebookPage());
        currentIndex = 0;
      }
      saveToPrefs();
    }
  }

  void restoreLastDeleted() {
    if (deletedPages.isNotEmpty) {
      pages.insert(currentIndex, deletedPages.removeAt(0));
      saveToPrefs();
    }
  }

  Future<void> saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'pages': pages.map((p) => p.toJson()).toList(),
      'currentIndex': currentIndex,
    };
    await prefs.setString('notebook_data', jsonEncode(data));
  }

  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('notebook_data');
    if (saved != null) {
      final decoded = jsonDecode(saved);
      pages = (decoded['pages'] as List)
          .map((p) => NotebookPage.fromJson(p))
          .toList();
      currentIndex = decoded['currentIndex'] ?? 0;
    } else {
      pages = [NotebookPage()];
      currentIndex = 0;
    }
  }


}
