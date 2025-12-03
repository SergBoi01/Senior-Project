import 'dart:convert';
import 'dart:typed_data';

// =============================================================================
// GLOSSARY ENTRY MODEL
// =============================================================================

/// Represents a single glossary entry with text fields and optional symbol image.
/// 
/// Each entry contains:
/// - [english]: The English term
/// - [spanish]: The Spanish translation
/// - [definition]: A text definition of the term
/// - [synonym]: Related synonyms
/// - [symbolImage]: Optional drawn symbol stored as PNG bytes
class GlossaryEntry {
  String english;
  String spanish;
  String definition;
  String synonym;
  Uint8List? symbolImage;

  /// Creates a new glossary entry with all fields.
  GlossaryEntry({
    required this.english,
    required this.spanish,
    required this.definition,
    required this.synonym,
    this.symbolImage,
  });

  /// Creates a minimal entry with just an English word.
  /// Useful for quick word initialization.
  GlossaryEntry.short({required String word})
      : english = word,
        spanish = '',
        definition = '',
        synonym = '',
        symbolImage = null;

  // ---------------------------------------------------------------------------
  // JSON Serialization
  // ---------------------------------------------------------------------------

  /// Converts the entry to a JSON map for storage.
  Map<String, dynamic> toJson() {
    return {
      'english': english,
      'spanish': spanish,
      'definition': definition,
      'synonym': synonym,
      'symbolImage': symbolImage != null ? base64Encode(symbolImage!) : null,
    };
  }

  /// Creates an entry from a JSON map.
  factory GlossaryEntry.fromJson(Map<String, dynamic> json) {
    return GlossaryEntry(
      english: json['english'] ?? '',
      spanish: json['spanish'] ?? '',
      definition: json['definition'] ?? '',
      synonym: json['synonym'] ?? '',
      symbolImage:
          json['symbolImage'] != null ? base64Decode(json['symbolImage']) : null,
    );
  }
}

// =============================================================================
// FOLDER ITEM MODEL
// =============================================================================

/// Represents a folder in the library hierarchy.
/// 
/// Folders can contain:
/// - Other [FolderItem]s (subfolders)
/// - [GlossaryItem]s (glossaries)
/// 
/// Root-level folders have [parentId] set to null.
class FolderItem {
  final String id;
  String name;
  bool isChecked;
  String? parentId;
  List<dynamic> children;

  FolderItem({
    required this.id,
    required this.name,
    this.isChecked = false,
    this.parentId,
    List<dynamic>? children,
  }) : children = children ?? [];

  // ---------------------------------------------------------------------------
  // Child Management
  // ---------------------------------------------------------------------------

  /// Adds a child (folder or glossary) to this folder.
  void addChild(dynamic item) {
    children.add(item);
  }

  /// Removes a child by its ID.
  void removeChild(String id) {
    children.removeWhere((item) {
      if (item is FolderItem) return item.id == id;
      if (item is GlossaryItem) return item.id == id;
      return false;
    });
  }

  // ---------------------------------------------------------------------------
  // Child Accessors
  // ---------------------------------------------------------------------------

  /// Returns only folder children.
  List<FolderItem> get folders => children.whereType<FolderItem>().toList();

  /// Returns only glossary children.
  List<GlossaryItem> get glossaries => children.whereType<GlossaryItem>().toList();

  // ---------------------------------------------------------------------------
  // JSON Serialization
  // ---------------------------------------------------------------------------

  /// Converts the folder (including children) to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'type': 'folder',
      'id': id,
      'name': name,
      'isChecked': isChecked,
      'parentId': parentId,
      'children': children.map((child) {
        if (child is FolderItem) return child.toJson();
        if (child is GlossaryItem) return child.toJson();
        return null;
      }).where((item) => item != null).toList(),
    };
  }

  /// Creates a folder from a JSON map, recursively parsing children.
  factory FolderItem.fromJson(Map<String, dynamic> json) {
    final folder = FolderItem(
      id: json['id'],
      name: json['name'],
      isChecked: json['isChecked'] ?? false,
      parentId: json['parentId'],
    );

    // Recursively parse children
    if (json['children'] != null) {
      for (var childJson in json['children']) {
        if (childJson['type'] == 'folder') {
          folder.children.add(FolderItem.fromJson(childJson));
        } else if (childJson['type'] == 'glossary') {
          folder.children.add(GlossaryItem.fromJson(childJson));
        }
      }
    }

    return folder;
  }
}

// =============================================================================
// GLOSSARY ITEM MODEL
// =============================================================================

/// Represents a glossary containing multiple [GlossaryEntry] items.
/// 
/// Glossaries must be placed inside a folder (referenced by [parentId]).
class GlossaryItem {
  final String id;
  String name;
  bool isChecked;
  String? parentId;
  List<GlossaryEntry> entries;

  GlossaryItem({
    required this.id,
    required this.name,
    this.isChecked = false,
    this.parentId,
    List<GlossaryEntry>? entries,
  }) : entries = entries ?? [];

  // ---------------------------------------------------------------------------
  // Entry Management
  // ---------------------------------------------------------------------------

  /// Adds an entry to the glossary.
  void addEntry(GlossaryEntry entry) {
    entries.add(entry);
  }

  /// Deletes an entry at the specified index.
  /// Does nothing if the index is out of bounds.
  void deleteEntry(int index) {
    if (index >= 0 && index < entries.length) {
      entries.removeAt(index);
    }
  }

  // ---------------------------------------------------------------------------
  // JSON Serialization
  // ---------------------------------------------------------------------------

  /// Converts the glossary to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'type': 'glossary',
      'id': id,
      'name': name,
      'isChecked': isChecked,
      'parentId': parentId,
      'entries': entries.map((e) => e.toJson()).toList(),
    };
  }

  /// Creates a glossary from a JSON map.
  factory GlossaryItem.fromJson(Map<String, dynamic> json) {
    return GlossaryItem(
      id: json['id'],
      name: json['name'],
      isChecked: json['isChecked'] ?? false,
      parentId: json['parentId'],
      entries: (json['entries'] as List<dynamic>?)
              ?.map((e) => GlossaryEntry.fromJson(e))
              .toList() ??
          [],
    );
  }
}
