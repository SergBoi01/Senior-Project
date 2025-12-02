import 'dart:convert';
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

  // JSON serialization
  Map<String, dynamic> toJson() {
    return {
      'english': english,
      'spanish': spanish,
      'definition': definition,
      'synonym': synonym,
      'symbolImage': symbolImage != null ? base64Encode(symbolImage!) : null,
    };
  }

  factory GlossaryEntry.fromJson(Map<String, dynamic> json) {
    return GlossaryEntry(
      english: json['english'] ?? '',
      spanish: json['spanish'] ?? '',
      definition: json['definition'] ?? '',
      synonym: json['synonym'] ?? '',
      symbolImage: json['symbolImage'] != null 
          ? base64Decode(json['symbolImage']) 
          : null,
    );
  }
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

  // JSON serialization
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

  factory FolderItem.fromJson(Map<String, dynamic> json) {
    final folder = FolderItem(
      id: json['id'],
      name: json['name'],
      isChecked: json['isChecked'] ?? false,
      parentId: json['parentId'],
    );
    
    // Parse children recursively
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

  // JSON serialization
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

  factory GlossaryItem.fromJson(Map<String, dynamic> json) {
    return GlossaryItem(
      id: json['id'],
      name: json['name'],
      isChecked: json['isChecked'] ?? false,
      parentId: json['parentId'],
      entries: (json['entries'] as List<dynamic>?)
          ?.map((e) => GlossaryEntry.fromJson(e))
          .toList() ?? [],
    );
  }
}

