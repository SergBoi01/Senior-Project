import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:senior_project/services/firestore_service.dart';
import 'main_page.dart'; // import Stroke class

class GlossaryEntry {
  String english;
  String spanish;
  String definition;
  String synonym;  
  Uint8List? symbolImage; // For display
  List<Stroke> strokes;   // For comparison (CHANGED: removed nullable)

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
  bool isChecked;      
  String name;         

  final List<GlossaryEntry> _entries = [];
  final FirestoreService _firestoreService = FirestoreService();

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
    saveToFirestore();
  }

  void deleteEntry(int index) {
    if (index >= 0 && index < _entries.length) {
      _entries.removeAt(index);
      saveToFirestore();
    }
  }

  Future<void> saveToFirestore() async {
    await _firestoreService.saveGlossary(_entries);
    print('Saved ${_entries.length} entries to Firestore');
  }

  Future<void> loadFromFirestore() async {
    final loadedEntries = await _firestoreService.loadGlossary();
    _entries.clear();
    _entries.addAll(loadedEntries);
    print('Loaded ${_entries.length} entries from Firestore');
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