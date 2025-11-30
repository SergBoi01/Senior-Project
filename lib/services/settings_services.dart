// ------------------------------------------------ //
//  What it does: load/save DetectionSettings
// ------------------------------------------------ //

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/settings_model.dart';

class SettingsService {
  Settings detectionSettings = Settings();
  double penWidth = 10.0;

  Future<SharedPreferences> get _prefs async => await SharedPreferences.getInstance();

  Future<void> saveSettings() async {
    final prefs = await _prefs;
    await prefs.setString('detectionSettings', jsonEncode(detectionSettings.toJson()));
    await prefs.setDouble('penWidth', penWidth);
  }

  Future<void> loadSettings() async {
    final prefs = await _prefs;
    final saved = prefs.getString('detectionSettings');
    detectionSettings = saved != null ? Settings.fromJson(jsonDecode(saved)) : Settings();
    penWidth = prefs.getDouble('penWidth') ?? 10.0;
  }
}