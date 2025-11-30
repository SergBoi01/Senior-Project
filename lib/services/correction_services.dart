// ------------------------------------------------ //
//  What it does: load/save user corrections
// ------------------------------------------------ //

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/strokes_model.dart';

class CorrectionService {
  List<UserCorrection> corrections = [];

  Future<SharedPreferences> get _prefs async => await SharedPreferences.getInstance();

  Future<void> saveCorrections() async {
    final prefs = await _prefs;
    await prefs.setString('userCorrections', jsonEncode(corrections.map((c) => c.toJson()).toList()));
  }

  Future<void> loadCorrections() async {
    final prefs = await _prefs;
    final saved = prefs.getString('userCorrections');
    if (saved == null) {
      corrections = [];
      return;
    }
    final list = jsonDecode(saved) as List<dynamic>;
    corrections = list.map((j) => UserCorrection.fromJson(j)).toList();
  }
}