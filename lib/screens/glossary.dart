// glossary.dart
class GlossaryEntry {
  String english;
  String spanish;
  String definition;
  String symbol;

GlossaryEntry({
    required this.english,
    required this.spanish,
    required this.definition,
    required this.symbol,
  });
}

  GlossaryEntry({required this.symbol, required this.word})
      : english = word,
        spanish = "",
        definition = "";
class Glossary {
  // we only have one glossary 
  static final Glossary _instance = Glossary._internal();
  factory Glossary() => _instance;
  Glossary._internal();

  // Default glossary entries
  final List<GlossaryEntry> _entries = [
    GlossaryEntry(symbol: "@", word: "at"),
    GlossaryEntry(symbol: "&", word: "and"),
    GlossaryEntry(symbol: "#", word: "number"),
    GlossaryEntry(symbol: "%", word: "percent"),
    GlossaryEntry(symbol: "\$", word: "dollar"),
    GlossaryEntry(symbol: "*", word: "star"),
    GlossaryEntry(word: "Information", symbol: "ℹ"),
    GlossaryEntry(word: "Help", symbol: "?"),
    GlossaryEntry(word: "Warning", symbol: "!"),
    GlossaryEntry(word: "Check", symbol: "✓"),
    GlossaryEntry(word: "Violence", symbol: "⚠"),
    GlossaryEntry(word: "No", symbol: "🚫"),
  ];

  List<GlossaryEntry> get entries => _entries;

  void addEntry(String symbol, String word) {
    _entries.add(GlossaryEntry(symbol: symbol, word: word));
  }

  void deleteEntry(int index) {
    if (index >= 0 && index < _entries.length) {
      _entries.removeAt(index);
    }
  }
}
