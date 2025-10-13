class GlossaryEntry {
  String english;
  String spanish;
  String definition;
  String symbol;

  // Main constructor (used by glossary_screen.dart)
  GlossaryEntry({
    required this.english,
    required this.spanish,
    required this.definition,
    required this.symbol,
  });

  // Optional short constructor for symbol/word initialization
  GlossaryEntry.short({required this.symbol, required String word})
      : english = word,
        spanish = "",
        definition = "";
}

class Glossary {
  /// Singleton pattern to ensure a single instance
  static final Glossary _instance = Glossary._internal();
  factory Glossary() => _instance;
  Glossary._internal();

  /// Default glossary entries
  final List<GlossaryEntry> _entries = [
    GlossaryEntry.short(symbol: "@", word: "at"),
    GlossaryEntry.short(symbol: "&", word: "and"),
    GlossaryEntry.short(symbol: "#", word: "number"),
    GlossaryEntry.short(symbol: "%", word: "percent"),
    GlossaryEntry.short(symbol: "\$", word: "dollar"),
    GlossaryEntry.short(symbol: "*", word: "star"),
    GlossaryEntry.short(symbol: "ℹ", word: "Information"),
    GlossaryEntry.short(symbol: "?", word: "Help"),
    GlossaryEntry.short(symbol: "!", word: "Warning"),
    GlossaryEntry.short(symbol: "✓", word: "Check"),
    GlossaryEntry.short(symbol: "⚠", word: "Violence"),
    GlossaryEntry.short(symbol: "🚫", word: "No"),
  ];

  /// Expose entries list (read-only reference)
  List<GlossaryEntry> get entries => _entries;

  /// Add entry — full version (used in your GlossaryScreen)
  void addEntry(String english, String spanish, String definition, String symbol) {
    _entries.add(GlossaryEntry(
      english: english,
      spanish: spanish,
      definition: definition,
      symbol: symbol,
    ));
  }

  /// Optional short add for symbol/word pairs
  void addShort(String symbol, String word) {
    _entries.add(GlossaryEntry.short(symbol: symbol, word: word));
  }

  /// Delete entry by index
  void deleteEntry(int index) {
    if (index >= 0 && index < _entries.length) {
      _entries.removeAt(index);
    }
  }

  /// Clear all entries (optional helper)
  void clear() {
    _entries.clear();
  }
}
