import 'dart:typed_data';

/// Represents a glossary entry with text fields and optional symbol image
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

/// Represents a folder in the library system
class FolderItem {
  final String id;
  String name;
  bool isChecked;
  String? parentId; // null for root level
  List<dynamic> children; // Can contain FolderItem or GlossaryItem

  FolderItem({
    required this.id,
    required this.name,
    this.isChecked = false,
    this.parentId,
    List<dynamic>? children,
  }) : children = children ?? [];

  /// Add a child folder or glossary
  void addChild(dynamic item) {
    children.add(item);
  }

  /// Remove a child by id
  void removeChild(String id) {
    children.removeWhere((item) {
      if (item is FolderItem) return item.id == id;
      if (item is GlossaryItem) return item.id == id;
      return false;
    });
  }

  /// Get all folders in children
  List<FolderItem> get folders {
    return children.whereType<FolderItem>().toList();
  }

  /// Get all glossaries in children
  List<GlossaryItem> get glossaries {
    return children.whereType<GlossaryItem>().toList();
  }
}

/// Represents a glossary in the library system
class GlossaryItem {
  final String id;
  String name;
  bool isChecked;
  String? parentId; // Reference to parent folder
  List<GlossaryEntry> entries;

  GlossaryItem({
    required this.id,
    required this.name,
    this.isChecked = false,
    this.parentId,
    List<GlossaryEntry>? entries,
  }) : entries = entries ?? [];

  /// Add an entry to the glossary
  void addEntry(GlossaryEntry entry) {
    entries.add(entry);
  }

  /// Delete entry by index
  void deleteEntry(int index) {
    if (index >= 0 && index < entries.length) {
      entries.removeAt(index);
    }
  }
}

