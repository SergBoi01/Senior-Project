import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/library_models.dart';

class GlossaryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _userId {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('User not logged in');
    return uid;
  }

  // COLLECTION PATH HELPERS
  CollectionReference<Map<String, dynamic>> _foldersRef() =>
      _firestore.collection('users').doc(_userId).collection('folders');

  CollectionReference<Map<String, dynamic>> _glossariesRef() =>
      _firestore.collection('users').doc(_userId).collection('glossaries');

  CollectionReference<Map<String, dynamic>> _entriesRef(String glossaryId) =>
      _glossariesRef().doc(glossaryId).collection('entries');

  // -------------------------
  // FOLDERS / GLOSSARIES (real-time writes)
  // -------------------------

  /// Save (create or update) a folder immediately.
  Future<void> saveFolder(FolderItem folder) async {
    try {
      final docRef = _foldersRef().doc(folder.id);
      print('[GS] saveFolder: saving folder id=${folder.id} name="${folder.name}" parent=${folder.parentId}');
      await docRef.set({
        'name': folder.name,
        'parentId': folder.parentId,
        'isChecked': folder.isChecked,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('[GS] saveFolder FAILED: $e');
      rethrow;
    }
  }

  /// Delete folder (will not cascade children automatically here).
  Future<void> deleteFolder(String folderId) async {
    try {
      print('[GS] deleteFolder: id=$folderId');
      await _foldersRef().doc(folderId).delete();
    } catch (e) {
      print('[GS] deleteFolder FAILED: $e');
      rethrow;
    }
  }

  /// Save (create or update) a glossary metadata immediately.
  Future<void> saveGlossary(GlossaryItem glossary) async {
    try {
      final docRef = _glossariesRef().doc(glossary.id);
      print('[GS] saveGlossary: saving glossary id=${glossary.id} name="${glossary.name}" parent=${glossary.parentId}');
      await docRef.set({
        'name': glossary.name,
        'parentId': glossary.parentId,
        'isChecked': glossary.isChecked,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('[GS] saveGlossary FAILED: $e');
      rethrow;
    }
  }

  /// Delete glossary (also deletes entries and symbol images if your entry code does that).
  Future<void> deleteGlossary(String glossaryId) async {
    try {
      print('[GS] deleteGlossary: id=$glossaryId');
      // delete entries first
      final entries = await _entriesRef(glossaryId).get();
      for (var d in entries.docs) {
        await _entriesRef(glossaryId).doc(d.id).delete();
      }
      // delete glossary doc
      await _glossariesRef().doc(glossaryId).delete();
    } catch (e) {
      print('[GS] deleteGlossary FAILED: $e');
      rethrow;
    }
  }

  // -------------------------
  // LIBRARY LOADER (build tree)
  // -------------------------

  /// Loads folders and glossaries for the user and assembles a tree.
  /// This returns root-level FolderItems (those with parentId == null), each
  /// containing child FolderItems and GlossaryItems in their `children` list.
  Future<List<FolderItem>> loadRootFolders() async {
    try {
      print('[GS] loadRootFolders: start for user=$_userId');

      final folderSnap = await _foldersRef().get();
      final glossarySnap = await _glossariesRef().get();

      // Map id -> FolderItem
      final Map<String, FolderItem> foldersById = {};
      for (var doc in folderSnap.docs) {
        final data = doc.data();
        final f = FolderItem(
          id: doc.id,
          name: data['name'] ?? '',
          isChecked: data['isChecked'] ?? false,
          parentId: data['parentId'],
          children: [],
        );
        foldersById[f.id] = f;
      }

      // Map id -> GlossaryItem
      final Map<String, GlossaryItem> glossById = {};
      for (var doc in glossarySnap.docs) {
        final data = doc.data();
        final g = GlossaryItem(
          id: doc.id,
          name: data['name'] ?? '',
          isChecked: data['isChecked'] ?? false,
          parentId: data['parentId'],
          entries: [], // entries load later when user opens glossary
        );
        glossById[g.id] = g;
      }

      // Attach glossaries to their parent folders (or keep unattached)
      for (var g in glossById.values) {
        if (g.parentId != null && foldersById.containsKey(g.parentId)) {
          foldersById[g.parentId]!.children.add(g);
        }
      }

      // Attach folders as children to parent folders
      for (var f in foldersById.values) {
        if (f.parentId != null && foldersById.containsKey(f.parentId)) {
          foldersById[f.parentId]!.children.add(f);
        }
      }

      // Collect root folders (parentId == null)
      final rootFolders = foldersById.values.where((f) => f.parentId == null).toList();

      // If there are glossaries sitting at root (parentId == null), convert them into a
      // synthetic root container? For now, attach glossaries with parentId==null to a single root folder list
      final rootGlossaries = glossById.values.where((g) => g.parentId == null).toList();
      if (rootGlossaries.isNotEmpty) {
        // If there are glossaries at root, create a "Unfiled" folder container OR
        // return them separately. We'll add an "Unfiled" folder to keep UI consistent.
        final unfiled = FolderItem(id: '_unfiled', name: 'Unfiled', parentId: null);
        unfiled.children.addAll(rootGlossaries);
        rootFolders.add(unfiled);
      }

      print('[GS] loadRootFolders: loaded ${rootFolders.length} root folders');
      return rootFolders;
    } catch (e) {
      print('[GS] loadRootFolders FAILED: $e');
      rethrow;
    }
  }

  // -------------------------
  // GLOSSARY ENTRIES (saved by Save button in GlossaryScreen)
  // -------------------------

  /// Load entries for a glossary
  Future<List<GlossaryEntry>> loadEntries(String glossaryId) async {
    try {
      final snapshot = await _entriesRef(glossaryId).orderBy('updatedAt', descending: true).get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return GlossaryEntry(
          id: doc.id,
          english: data['english'] ?? '',
          spanish: data['spanish'] ?? '',
          definition: data['definition'] ?? '',
          synonym: data['synonym'] ?? '',
          // symbolImage & strokes are intentionally not hydrated here (large blobs)
        );
      }).toList();
    } catch (e) {
      print('[GS] loadEntries FAILED: $e');
      rethrow;
    }
  }

  /// Save all entries for a glossary (called when user clicks Save in GlossaryScreen)
  Future<void> saveAllEntries(String glossaryId, List<GlossaryEntry> entries) async {
    try {
      final batch = _firestore.batch();
      final entriesRef = _entriesRef(glossaryId);

      for (var entry in entries) {
        final docRef = entry.id != null ? entriesRef.doc(entry.id) : entriesRef.doc();
        entry.id ??= docRef.id;

        final data = {
          'english': entry.english,
          'spanish': entry.spanish,
          'definition': entry.definition,
          'synonym': entry.synonym,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        batch.set(docRef, data, SetOptions(merge: true));
      }

      print('[GS] saveAllEntries: committing ${entries.length} entries for glossary=$glossaryId');
      await batch.commit();
    } catch (e) {
      print('[GS] saveAllEntries FAILED: $e');
      rethrow;
    }
  }

  /// Delete a single entry
  Future<void> deleteEntry(String glossaryId, String entryId) async {
    try {
      await _entriesRef(glossaryId).doc(entryId).delete();
    } catch (e) {
      print('[GS] deleteEntry FAILED: $e');
      rethrow;
    }
  }
}
