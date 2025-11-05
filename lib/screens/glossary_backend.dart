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
  List<Stroke>? strokes;  // For comparison

  GlossaryEntry({
    required this.english,
    required this.spanish,
    required this.definition,
    required this.synonym,
    this.symbolImage,
    this.strokes,
  });

  GlossaryEntry.short({required String word})
      : english = word,
        spanish = "",
        definition = "",
        synonym = "",
        symbolImage = null,
        strokes = null;
}

class Glossary {
  bool isChecked;      // Is glossary checked? I compare with it
  String name;         // Name for Glossary, by User

  final List<GlossaryEntry> _entries = [
    GlossaryEntry.short(word: "Texas"),
    GlossaryEntry.short(word: "Up"),
    GlossaryEntry.short(word: "Notes"),
    GlossaryEntry.short(word: "Happy"),
    GlossaryEntry.short(word: "Sad"),
    GlossaryEntry.short(word: "Oppose"),
  ];

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
      strokes: strokes,
    ));
  }

  void deleteEntry(int index) {
    if (index >= 0 && index < _entries.length) _entries.removeAt(index);
  }

  Future<void> saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> serialized = [];
    for (var e in _entries) {
      serialized.add(jsonEncode({
        'english': e.english,
        'spanish': e.spanish,
        'definition': e.definition,
        'synonym': e.synonym,
        'symbolImage': e.symbolImage != null ? base64Encode(e.symbolImage!) : null,
      }));
    }
    await prefs.setStringList('glossary_entries', serialized);
  }

  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList('glossary_entries');
    if (stored != null) {
      _entries.clear();
      for (var s in stored) {
        var data = jsonDecode(s);
        _entries.add(GlossaryEntry(
          english: data['english'] ?? '',
          spanish: data['spanish'] ?? '',
          definition: data['definition'] ?? '',
          synonym: data['synonym'] ?? '',
          symbolImage: data['symbolImage'] != null ? base64Decode(data['symbolImage']) : null,
        ));
      }
    }
  }
  
  /// Print all entries for testing
  void printAllEntries() {
    print("========== GLOSSARY LIST (${_entries.length} entries) ==========");
    for (int i = 0; i < _entries.length; i++) {
      print("[$i] English: '${_entries[i].english}' | Spanish: '${_entries[i].spanish}' | Has Image: ${_entries[i].symbolImage != null}");
    }
    print("==========================================================");
  }
}