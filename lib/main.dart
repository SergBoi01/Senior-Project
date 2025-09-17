import 'package:flutter/material.dart';
import 'package:senior_project/screens/main_page.dart';
import 'package:senior_project/screens/splash_screen.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      // SWITCHED TO MAIN PAGE CAUSE IM TOO LAZY
      // TO INPUT MY USERNAE EVERYTIME
      home: MainPage(),
    );
  }
}