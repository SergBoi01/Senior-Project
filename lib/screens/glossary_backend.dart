import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class GlossaryEntry {
  String english;
  String spanish;
  String definition;
  String synonym;  
  Uint8List? symbolImage; // for drawn symbols

  // Main constructor
  GlossaryEntry({
    required this.english,
    required this.spanish,
    required this.definition,
    required this.synonym,
    this.symbolImage,
  });

  // Short constructor for word initialization
  GlossaryEntry.short({required String word})
      : english = word,
        spanish = "",
        definition = "",
        synonym = "",
        symbolImage = null;
}

class Glossary {
  /// Singleton pattern to ensure a single instance
  static final Glossary _instance = Glossary._internal();
  factory Glossary() => _instance;
  Glossary._internal();

  /// Default glossary entries
  final List<GlossaryEntry> _entries = [
    GlossaryEntry.short(word: "at"),
    GlossaryEntry.short(word: "and"),
    GlossaryEntry.short(word: "number"),
    GlossaryEntry.short(word: "percent"),
    GlossaryEntry.short(word: "dollar"),
    GlossaryEntry.short(word: "star"),
    GlossaryEntry.short(word: "Information"),
    GlossaryEntry.short(word: "Help"),
    GlossaryEntry.short(word: "Warning"),
    GlossaryEntry.short(word: "Check"),
    GlossaryEntry.short(word: "Violence"),
    GlossaryEntry.short(word: "No"),
  ];

  /// Expose entries list (read-only reference)
  List<GlossaryEntry> get entries => _entries;

  // Add entry
  void addEntry(String english, String spanish, String definition, String synonym, [Uint8List? symbolImage]) {
    _entries.add(GlossaryEntry(
      english: english,
      spanish: spanish,
      definition: definition,
      synonym: synonym,
      symbolImage: symbolImage,
    ));
  }

  /// Delete entry by index
  void deleteEntry(int index) {
    if (index >= 0 && index < _entries.length) {
      _entries.removeAt(index);
    }
  }

  /// Save glossary to SharedPreferences
  Future<void> saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> entries = [];
      
      for (var entry in _entries) {
        String entryJson = jsonEncode({
          'english': entry.english,
          'spanish': entry.spanish,
          'definition': entry.definition,
          'synonym': entry.synonym,
          'hasSymbol': entry.symbolImage != null,
          'symbolImage': entry.symbolImage != null ? base64Encode(entry.symbolImage!) : null,
        });
        entries.add(entryJson);
      }
      
      await prefs.setStringList('glossary_entries', entries);
      print('Glossary saved successfully');
    } catch (e) {
      print('Error saving glossary: $e');
    }
  }

  /// Load glossary from SharedPreferences
  Future<void> loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String>? entries = prefs.getStringList('glossary_entries');
      
      if (entries != null && entries.isNotEmpty) {
        _entries.clear();
        for (String entryJson in entries) {
          Map<String, dynamic> data = jsonDecode(entryJson);
          _entries.add(GlossaryEntry(
            english: data['english'] ?? '',
            spanish: data['spanish'] ?? '',
            definition: data['definition'] ?? '',
            synonym: data['synonym'] ?? '',
            symbolImage: data['symbolImage'] != null ? base64Decode(data['symbolImage']) : null,
          ));
        }
        print('Glossary loaded successfully');
      } else {
        print('No saved glossary found, using defaults');
      }
    } catch (e) {
      print('Error loading glossary: $e');
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