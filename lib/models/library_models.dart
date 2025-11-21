import 'dart:typed_data';
import 'strokes_models.dart';

/// Represents a glossary entry with text fields and optional symbol image + strokes
class GlossaryEntry {
  String? id; // Firestore document ID (null for new entries)
  String english;
  String spanish;
  String definition;
  String synonym;  
  Uint8List? symbolImage; // for displaying symbols
  List<Stroke>? strokes; // for symbol comparison/detection

  // Main constructor
  GlossaryEntry({
    this.id,
    required this.english,
    required this.spanish,
    required this.definition,
    required this.synonym,
    this.symbolImage,
    this.strokes,
  });

  // Short constructor for word initialization
  GlossaryEntry.short({required String word})
      : english = word,
        spanish = "",
        definition = "",
        synonym = "",
        symbolImage = null,
        strokes = null;
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


extension FolderItemFirestore on FolderItem {
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'isChecked': isChecked,
      'parentId': parentId,
      'children': children.map((c) {
        if (c is FolderItem) return c.toJson();
        if (c is GlossaryItem) return c.toJson();
        return {};
      }).toList(),
    };
  }

  static FolderItem fromJson(Map<String, dynamic> json) {
    return FolderItem(
      id: json['id'],
      name: json['name'],
      isChecked: json['isChecked'] ?? false,
      parentId: json['parentId'],
      children: (json['children'] as List<dynamic>?)
              ?.map((c) {
                if (c.containsKey('entries')) {
                  return GlossaryItemFirestore.fromJson(c);
                }
                return FolderItemFirestore.fromJson(c);
              })
              .toList() ??
          [],
    );
  }
}

extension GlossaryItemFirestore on GlossaryItem {
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'isChecked': isChecked,
      'parentId': parentId,
      'entries': entries.map((e) => {
            'english': e.english,
            'spanish': e.spanish,
            'definition': e.definition,
            'synonym': e.synonym,
          }).toList(),
    };
  }

  static GlossaryItem fromJson(Map<String, dynamic> json) {
    return GlossaryItem(
      id: json['id'],
      name: json['name'],
      isChecked: json['isChecked'] ?? false,
      parentId: json['parentId'],
      entries: (json['entries'] as List<dynamic>?)
              ?.map((e) => GlossaryEntry(
                    english: e['english'],
                    spanish: e['spanish'],
                    definition: e['definition'],
                    synonym: e['synonym'],
                  ))
              .toList() ??
          [],
    );
  }
}