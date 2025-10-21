import 'dart:typed_data';

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

  /// Print all entries for testing
  void printAllEntries() {
    print("========== GLOSSARY LIST (${_entries.length} entries) ==========");
    for (int i = 0; i < _entries.length; i++) {
      print("[$i] English: '${_entries[i].english}' | Spanish: '${_entries[i].spanish}' | Has Image: ${_entries[i].symbolImage != null}");
    }
    print("==========================================================");
  }
}