import 'package:cloud_firestore/cloud_firestore.dart';

import 'notebook_models.dart';
import 'library_models.dart';
import 'strokes_models.dart';
import 'detection_settings_models.dart';

import '../services/glossary_service.dart';



class UserDataManager {
  // Singleton pattern
  static final UserDataManager _instance = UserDataManager._internal();
  factory UserDataManager() => _instance;
  UserDataManager._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // User data
  NotebookManager notebook = NotebookManager();
  List<UserCorrection> corrections = [];
  List<FolderItem> libraryRootFolders = [];
  DetectionSettings detectionSettings = DetectionSettings();

  // Flags
  bool isLoaded = false;

  /// Load all user data from Firestore
  Future<void> loadUserData(String userId) async {
    try {
      await notebook.loadFromFirestore(userId);

      // Load user corrections
      final corrDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('corrections')
          .get();
      corrections = corrDoc.docs
          .map((d) => UserCorrection.fromJson(d.data()))
          .toList();

      // Load library
      final libraryDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('library')
          .get();
      libraryRootFolders = libraryDoc.docs
          .map((d) => FolderItemFirestore.fromJson(d.data()))
          .toList();

      // Load detection settings
      final settingsDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('settings')
          .doc('detection')
          .get();
      if (settingsDoc.exists) {
        detectionSettings = DetectionSettings.fromJson(settingsDoc.data()!);
      }

      isLoaded = true;
      print('User data loaded from Firestore.');
    } catch (e) {
      print('Failed to load user data: $e');
    }
  }
  
  // Load library structure when needed
  Future<List<FolderItem>> loadLibraryStructure(String userId) async {
    final glossaryService = GlossaryService();
    return await glossaryService.loadRootFolders();
  }
      
  
  /// Save all user data from Firestore
  Future<void> saveUserData(String userId) async {
    try {
      await notebook.saveToFirestore(userId);

      // Save corrections
      final batch = _firestore.batch();
      final corrRef = _firestore.collection('users').doc(userId).collection('corrections');
      for (var c in corrections) {
        final docRef = corrRef.doc();
        batch.set(docRef, c.toJson());
      }
      await batch.commit();

      // Save library
      final libRef = _firestore.collection('users').doc(userId).collection('library');
      for (var f in libraryRootFolders) {
        await libRef.doc(f.id).set(f.toJson());
      }

      // Save detection settings
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('settings')
          .doc('detection')
          .set(detectionSettings.toJson());

      print('User data saved to Firestore.');
    } catch (e) {
      print('Failed to save user data: $e');
    }
  }


  /// Recursive save for library folders
  Future<void> _saveFolderRecursive(FolderItem folder, String userId) async {
    final folderDoc = _firestore
        .collection('users')
        .doc(userId)
        .collection('library')
        .doc(folder.id);
    await folderDoc.set(folder.toJson());

    for (var child in folder.children) {
      if (child is FolderItem) {
        await _saveFolderRecursive(child, userId);
      } else if (child is GlossaryItem) {
        final glossaryDoc = _firestore
            .collection('users')
            .doc(userId)
            .collection('glossary')
            .doc(child.id);
        await glossaryDoc.set(child.toJson());
      }
    }
  }
}

