import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';


import 'notebook_models.dart';
import 'library_models.dart';
import 'strokes_models.dart';
import 'detection_settings_models.dart';

import '../services/glossary_service.dart';
import '../services/drawing_settings.dart';



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
  double penWidth = 10.0;

  // Flags
  bool isLoaded = false;

  /// Load all user data from Firestore
  Future<void> loadUserData(String userID) async {
    final doc = await _firestore.collection('users').doc(userID).get();
    if (!doc.exists) return;

    final data = doc.data()!;

    corrections = (data['corrections'] as List<dynamic>?)
            ?.map((e) => UserCorrection.fromJson(e))
            .toList() ??
        [];

    detectionSettings =
        DetectionSettings.fromJson(data['detectionSettings'] ?? {});

    penWidth = (data['penWidth'] ?? 10.0).toDouble();

    // IMPORTANT: hydrate global drawing settings
    drawingSettings.setPenWidth(penWidth);
  }


  // Load library structure when needed
  Future<List<FolderItem>> loadLibraryStructure(String userId) async {
    final glossaryService = GlossaryService();
    return await glossaryService.loadRootFolders();
  }
      
  
  /// Save all user data from Firestore
  Future<void> saveUserData(String userID) async {
    await _firestore.collection('users').doc(userID).set({
      'corrections': corrections.map((e) => e.toJson()).toList(),
      'detectionSettings': detectionSettings.toJson(),
      'penWidth': penWidth,
    }, SetOptions(merge: true));
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

