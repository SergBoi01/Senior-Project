// lib/models/library_model.dart
import 'dart:convert';
import 'dart:typed_data';
import 'strokes_model.dart';

/// Represents a glossary entry with text fields and symbol image + strokes
class GlossaryEntry {
  String? id;
  String english;
  String spanish;
  String definition;
  String synonym;
  Uint8List? symbolImage;
  List<Stroke>? strokes;

  GlossaryEntry({
    this.id,
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
        strokes = [];

  // Convert entry to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'english': english,
      'spanish': spanish,
      'definition': definition,
      'synonym': synonym,
      'strokes': strokes?.map((s) => s.toJson()).toList() ?? [],
      // write nullable base64 string or null
      'symbolImage': symbolImage != null ? base64Encode(symbolImage!) : null,
    };
  }

  // Create entry from JSON
  factory GlossaryEntry.fromJson(Map<String, dynamic> json) {
    return GlossaryEntry(
      id: json['id'],
      english: json['english'] ?? '',
      spanish: json['spanish'] ?? '',
      definition: json['definition'] ?? '',
      synonym: json['synonym'] ?? '',
      strokes: (json['strokes'] as List<dynamic>?)
              ?.map((s) => Stroke.fromJson(s))
              .toList(),
              
      // decode to Uint8List?; leave null if no image
      symbolImage: json['symbolImage'] != null
          ? base64Decode(json['symbolImage'])
          : null,
    );
  }
}

/// Represents a glossary in the library system
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

  void addEntry(GlossaryEntry entry) => entries.add(entry);

  void deleteEntry(int index) {
    if (index >= 0 && index < entries.length) entries.removeAt(index);
  }

  factory GlossaryItem.fromJson(Map<String, dynamic> json) {
    return GlossaryItem(
      id: json['id'],
      name: json['name'],
      isChecked: json['isChecked'] == true || json['isChecked'] == "true",
      parentId: json['parentId'],
      entries: (json['entries'] as List<dynamic>?)
              ?.map((e) => GlossaryEntry.fromJson(e))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'isChecked': isChecked,
      'parentId': parentId,
      'entries': entries.map((e) => e.toJson()).toList(),
    };
  }
}

/// Represents a folder in the library system
class FolderItem {
  final String id;
  String name;
  bool isChecked;
  String? parentId;
  bool childrenLoaded;
  List<dynamic> children; // Can be FolderItem or GlossaryItem

  FolderItem({
    required this.id,
    required this.name,
    this.isChecked = false,
    this.parentId,
    this.childrenLoaded = false,
    List<dynamic>? children,
  }) : children = children ?? [];

  void addChild(dynamic item) => children.add(item);

  void removeChild(String id) {
    children.removeWhere((item) {
      if (item is FolderItem) return item.id == id;
      if (item is GlossaryItem) return item.id == id;
      return false;
    });
  }

  List<FolderItem> get folders => children.whereType<FolderItem>().toList();

  List<GlossaryItem> get glossaries => children.whereType<GlossaryItem>().toList();

  /// NOTE: Accepts the "wrapped" children format produced by LibraryService
  factory FolderItem.fromJson(Map<String, dynamic> json) {
    final rawChildren = (json['children'] as List<dynamic>?) ?? [];

    final parsedChildren = rawChildren.map((child) {
      // child may be either:
      // 1) a wrapped object { type: 'folder'|'glossary', data: {...} }
      // 2) or already a raw folder/glossary shaped object (defensive)
      try {
        if (child is Map<String, dynamic> && child.containsKey('type') && child.containsKey('data')) {
          final type = child['type'] as String;
          final data = child['data'] as Map<String, dynamic>;
          if (type == 'folder') return FolderItem.fromJson(data);
          if (type == 'glossary') return GlossaryItem.fromJson(data);
        } else if (child is Map<String, dynamic>) {
          // try to determine by presence of 'entries'
          if (child.containsKey('entries')) {
            return GlossaryItem.fromJson(child);
          } else {
            return FolderItem.fromJson(child);
          }
        }
      } catch (_) {
        // fallthrough to null
      }
      return null;
    }).where((c) => c != null).toList();

    return FolderItem(
      id: json['id'],
      name: json['name'],
      isChecked: json['isChecked'] == true || json['isChecked'] == "true",
      parentId: json['parentId'],
      children: parsedChildren,
    );
  }

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
}
