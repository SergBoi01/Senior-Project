import 'package:flutter/material.dart';
import 'package:senior_project/screens/main_page.dart';
import 'package:senior_project/screens/splash_screen.dart';

import 'package:senior_project/screens/glossary_backend.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:convert';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Load glossary once at startup
  final glossary = Glossary();
  await glossary.loadFromPrefs();
  print('✅ Main: Loaded ${glossary.entries.length} glossary entries');
  
  // Load user corrections once at startup
  final userCorrections = await _loadUserCorrections();
  print('Main: Loaded ${userCorrections.length} user corrections');
  
  runApp(MainApp(
    glossary: glossary,
    userCorrections: userCorrections,
  ));
}

Future<List<UserCorrection>> _loadUserCorrections() async {
  final prefs = await SharedPreferences.getInstance();
  final stored = prefs.getStringList('user_corrections');
  if (stored != null) {
    return stored.map((s) => UserCorrection.fromJson(jsonDecode(s))).toList();
  }
  return [];
}

class MainApp extends StatelessWidget {
  final Glossary glossary;
  final List<UserCorrection> userCorrections;

  const MainApp({
    super.key,
    required this.glossary,
    required this.userCorrections,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MainPage(
        glossary: glossary,
        userCorrections: userCorrections,
      ),
    );
  }
}