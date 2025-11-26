import 'notebook_models.dart';
import 'library_models.dart';
import 'strokes_models.dart';
import 'detection_settings_models.dart';

import '../services/glossary_service.dart';
import '../services/drawing_settings.dart';
import '../services/preferences_service.dart';

class UserDataManager {
  // Singleton pattern
  static final UserDataManager _instance = UserDataManager._internal();
  factory UserDataManager() => _instance;
  UserDataManager._internal();

  final PreferencesService _prefsService = PreferencesService();

  // User data
  NotebookManager notebook = NotebookManager();
  List<UserCorrection> corrections = [];
  List<FolderItem> libraryRootFolders = [];
  DetectionSettings detectionSettings = DetectionSettings();
  double penWidth = 10.0;

  // Flags
  bool isLoaded = false;

  /// Load all user data from SharedPreferences
  Future<void> loadUserData(String userID) async {
    try {
      print('[UDM] loadUserData: start for user=$userID');
      
      // Load corrections
      corrections = await _prefsService.loadUserCorrections(userID);
      print('[UDM] loaded ${corrections.length} corrections');

      // Load detection settings
      detectionSettings = await _prefsService.loadDetectionSettings(userID);
      print('[UDM] loaded detection settings');

      // Load pen width
      penWidth = await _prefsService.loadPenWidth(userID);
      print('[UDM] loaded pen width: $penWidth');

      // Load library structure
      libraryRootFolders = await _prefsService.loadRootFolders(userID);
      print('[UDM] loaded ${libraryRootFolders.length} root folders');

      // IMPORTANT: hydrate global drawing settings
      drawingSettings.setPenWidth(penWidth);

      isLoaded = true;
      print('[UDM] loadUserData: complete');
    } catch (e) {
      print('[UDM] loadUserData FAILED: $e');
      rethrow;
    }
  }

  /// Load library structure when needed
  Future<List<FolderItem>> loadLibraryStructure(String userId) async {
    try {
      final glossaryService = GlossaryService();
      return await glossaryService.loadRootFolders();
    } catch (e) {
      print('[UDM] loadLibraryStructure FAILED: $e');
      return [];
    }
  }

  /// Save all user data to SharedPreferences
  Future<void> saveUserData(String userID) async {
    try {
      print('[UDM] saveUserData: start for user=$userID');
      
      // Save corrections
      await _prefsService.saveUserCorrections(userID, corrections);
      print('[UDM] saved corrections');

      // Save detection settings
      await _prefsService.saveDetectionSettings(userID, detectionSettings);
      print('[UDM] saved detection settings');

      // Save pen width
      await _prefsService.savePenWidth(userID, penWidth);
      print('[UDM] saved pen width');

      // Save library structure
      await _prefsService.saveRootFolders(userID, libraryRootFolders);
      print('[UDM] saved library structure');

      print('[UDM] saveUserData: complete');
    } catch (e) {
      print('[UDM] saveUserData FAILED: $e');
      rethrow;
    }
  }

  /// Clear all data for a user
  Future<void> clearUserData(String userID) async {
    try {
      await _prefsService.clearAllData(userID);
      
      // Reset in-memory data
      corrections.clear();
      libraryRootFolders.clear();
      detectionSettings = DetectionSettings();
      penWidth = 10.0;
      isLoaded = false;
      
      print('[UDM] cleared all data for user=$userID');
    } catch (e) {
      print('[UDM] clearUserData FAILED: $e');
      rethrow;
    }
  }
}