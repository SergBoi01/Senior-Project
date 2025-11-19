import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import '../models/library_models.dart';

/// Service class for managing glossary data in Firestore
class GlossaryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get current user ID
  String? get _userId => _auth.currentUser?.uid;

  /// Get the path to user's glossaries in Firestore
  String _getGlossaryPath(String glossaryId) {
    if (_userId == null) throw Exception('User not logged in');
    return 'users/$_userId/glossaries/$glossaryId';
  }

  /// Get the path to entries collection
  String _getEntriesPath(String glossaryId) {
    return '${_getGlossaryPath(glossaryId)}/entries';
  }

  /// Get the path to symbol image in Storage
  String _getSymbolPath(String glossaryId, String entryId) {
    if (_userId == null) throw Exception('User not logged in');
    return 'users/$_userId/glossaries/$glossaryId/entries/$entryId/symbol.png';
  }

  /// Save a glossary entry to Firestore
  Future<void> saveEntry(String glossaryId, GlossaryEntry entry, int index) async {
    if (_userId == null) throw Exception('User not logged in');
    
    try {
      // Generate entry ID if it doesn't exist (for new entries)
      String entryId = entry.id ?? 'entry_${DateTime.now().millisecondsSinceEpoch}_$index';
      
      // Upload symbol image to Storage if it exists
      String? symbolImageUrl;
      if (entry.symbolImage != null) {
        symbolImageUrl = await _uploadSymbolImage(glossaryId, entryId, entry.symbolImage!);
      } else {
        // If symbol was deleted, remove from Storage
        await _deleteSymbolImage(glossaryId, entryId);
      }

      // Save entry data to Firestore
      await _firestore
          .collection(_getEntriesPath(glossaryId))
          .doc(entryId)
          .set({
        'english': entry.english,
        'spanish': entry.spanish,
        'definition': entry.definition,
        'synonym': entry.synonym,
        'symbolImageUrl': symbolImageUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Update entry ID in the model
      entry.id = entryId;
    } catch (e) {
      throw Exception('Failed to save entry: $e');
    }
  }

  /// Load all entries for a glossary from Firestore
  Future<List<GlossaryEntry>> loadEntries(String glossaryId) async {
    if (_userId == null) throw Exception('User not logged in');
    
    try {
      final querySnapshot = await _firestore
          .collection(_getEntriesPath(glossaryId))
          .orderBy('updatedAt', descending: true)
          .get();

      List<GlossaryEntry> entries = [];
      
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        
        // Download symbol image if URL exists
        Uint8List? symbolImage;
        if (data['symbolImageUrl'] != null && data['symbolImageUrl'] is String) {
          try {
            symbolImage = await _downloadSymbolImage(data['symbolImageUrl'] as String);
          } catch (e) {
            debugPrint('Failed to download symbol image: $e');
          }
        }

        entries.add(GlossaryEntry(
          id: doc.id,
          english: data['english'] ?? '',
          spanish: data['spanish'] ?? '',
          definition: data['definition'] ?? '',
          synonym: data['synonym'] ?? '',
          symbolImage: symbolImage,
        ));
      }

      return entries;
    } catch (e) {
      throw Exception('Failed to load entries: $e');
    }
  }

  /// Delete an entry from Firestore
  Future<void> deleteEntry(String glossaryId, String entryId) async {
    if (_userId == null) throw Exception('User not logged in');
    
    try {
      // Delete entry document
      await _firestore
          .collection(_getEntriesPath(glossaryId))
          .doc(entryId)
          .delete();

      // Delete symbol image from Storage
      await _deleteSymbolImage(glossaryId, entryId);
    } catch (e) {
      throw Exception('Failed to delete entry: $e');
    }
  }

  /// Upload symbol image to Firebase Storage
  Future<String> _uploadSymbolImage(String glossaryId, String entryId, Uint8List imageData) async {
    try {
      final ref = _storage.ref().child(_getSymbolPath(glossaryId, entryId));
      await ref.putData(imageData, SettableMetadata(contentType: 'image/png'));
      return await ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload symbol image: $e');
    }
  }

  /// Download symbol image from Firebase Storage
  Future<Uint8List> _downloadSymbolImage(String imageUrl) async {
    try {
      final ref = _storage.refFromURL(imageUrl);
      return await ref.getData() ?? Uint8List(0);
    } catch (e) {
      throw Exception('Failed to download symbol image: $e');
    }
  }

  /// Delete symbol image from Firebase Storage
  Future<void> _deleteSymbolImage(String glossaryId, String entryId) async {
    try {
      final ref = _storage.ref().child(_getSymbolPath(glossaryId, entryId));
      await ref.delete();
    } catch (e) {
      // Ignore error if file doesn't exist
      debugPrint('Error deleting symbol image (may not exist): $e');
    }
  }

  /// Save glossary metadata (name, parentId) to Firestore
  Future<void> saveGlossary(GlossaryItem glossary) async {
    if (_userId == null) throw Exception('User not logged in');
    
    try {
      await _firestore
          .collection('users/$_userId/glossaries')
          .doc(glossary.id)
          .set({
        'name': glossary.name,
        'parentId': glossary.parentId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to save glossary: $e');
    }
  }

  /// Load a glossary from Firestore
  Future<GlossaryItem?> loadGlossary(String glossaryId) async {
    if (_userId == null) throw Exception('User not logged in');
    
    try {
      final doc = await _firestore
          .collection('users/$_userId/glossaries')
          .doc(glossaryId)
          .get();

      if (!doc.exists) return null;

      final data = doc.data()!;
      
      // Load entries
      final entries = await loadEntries(glossaryId);

      return GlossaryItem(
        id: glossaryId,
        name: data['name'] ?? '',
        parentId: data['parentId'],
        entries: entries,
      );
    } catch (e) {
      throw Exception('Failed to load glossary: $e');
    }
  }
}

