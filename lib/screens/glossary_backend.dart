import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'main_page.dart'; // import Stroke class

class GlossaryEntry {

  String english;
  String spanish;
  String definition;
  String synonym;  
  Uint8List? symbolImage; // For display
  List<Stroke> strokes;   // For comparison 

  GlossaryEntry({
    required this.english,
    required this.spanish,
    required this.definition,
    required this.synonym,
    this.symbolImage,
    List<Stroke>? strokes,  // Accept nullable in constructor
  }) : strokes = strokes ?? []; // But initialize to empty list

  GlossaryEntry.short({required String word})
      : english = word,
        spanish = "",
        definition = "",
        synonym = "",
        symbolImage = null,
        strokes = []; // Initialize to empty list
}

class Glossary {
  bool isChecked;   // Decided by user
  String name;      // User can change the name

  final List<GlossaryEntry> _entries = [];

  List<GlossaryEntry> get entries => _entries;

  Glossary({
    this.name = "Untitled Glossary",
    this.isChecked = true,
  });

  void addEntry(String english, String spanish, String definition, String synonym, [Uint8List? symbolImage, List<Stroke>? strokes]) {
    _entries.add(GlossaryEntry(
      english: english,
      spanish: spanish,
      definition: definition,
      synonym: synonym,
      symbolImage: symbolImage,
      strokes: strokes ?? [],
    ));
  }

  void deleteEntry(int index) {
    if (index >= 0 && index < _entries.length) _entries.removeAt(index);
  }

  // Simple save for now. Will be updated.
  Future<void> saveToPrefs() async {
    
    final prefs = await SharedPreferences.getInstance();
    List<String> serialized = [];
    
    for (var e in _entries) {
      // Serialize strokes to JSON
      List<Map<String, dynamic>> strokesJson = e.strokes.map((stroke) {
        return {
          'points': stroke.points.map((p) => {'dx': p.dx, 'dy': p.dy}).toList(),
          'startTime': stroke.startTime.millisecondsSinceEpoch,
          'endTime': stroke.endTime.millisecondsSinceEpoch,
        };
      }).toList();

      serialized.add(jsonEncode({
        'english': e.english,
        'spanish': e.spanish,
        'definition': e.definition,
        'synonym': e.synonym,
        'symbolImage': e.symbolImage != null ? base64Encode(e.symbolImage!) : null,
        'strokes': strokesJson, // ADDED: Save strokes
      }));
    }
    
    await prefs.setStringList('glossary_entries', serialized);
    print('Saved ${_entries.length} entries to SharedPreferences');
  }

  // Simple load for now. Will be updated.
  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList('glossary_entries');
    
    if (stored != null) {
      _entries.clear();
      for (var s in stored) {
        var data = jsonDecode(s);
        
        // Deserialize strokes from JSON
        List<Stroke> loadedStrokes = [];
        if (data['strokes'] != null) {
          for (var strokeJson in data['strokes']) {
            List<Offset> points = (strokeJson['points'] as List)
                .map((p) => Offset(p['dx'], p['dy']))
                .toList();
            
            loadedStrokes.add(Stroke(
              points: points,
              startTime: DateTime.fromMillisecondsSinceEpoch(strokeJson['startTime']),
              endTime: DateTime.fromMillisecondsSinceEpoch(strokeJson['endTime']),
            ));
          }
        }

        _entries.add(GlossaryEntry(
          english: data['english'] ?? '',
          spanish: data['spanish'] ?? '',
          definition: data['definition'] ?? '',
          synonym: data['synonym'] ?? '',
          symbolImage: data['symbolImage'] != null ? base64Decode(data['symbolImage']) : null,
          strokes: loadedStrokes, // ADDED: Load strokes
        ));
      }
      print('Loaded ${_entries.length} entries from SharedPreferences');
    } else {
      print('No saved entries found');
    }
  }
  
  void printAllEntries() {
    print("========== GLOSSARY LIST (${_entries.length} entries) ==========");
    for (int i = 0; i < _entries.length; i++) {
      print("[$i] English: '${_entries[i].english}' | Spanish: '${_entries[i].spanish}' | "
            "Has Image: ${_entries[i].symbolImage != null} | Strokes: ${_entries[i].strokes.length}");
    }
    print("==========================================================");
  }
}