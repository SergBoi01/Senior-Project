import 'dart:async';
import 'package:flutter/material.dart';
import 'package:senior_project/screens/login_screen.dart';
import 'package:senior_project/screens/main_page.dart';
import 'package:senior_project/screens/glossary_backend.dart';

class SplashScreen extends StatefulWidget {
  final Glossary glossary;
  final List<UserCorrection> userCorrections;

  const SplashScreen({
    super.key,
    required this.glossary,
    required this.userCorrections,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(
      const Duration(seconds: 2),
      () => Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => LoginScreen(
            glossary: widget.glossary,
            userCorrections: widget.userCorrections,
          ),
          transitionDuration: const Duration(milliseconds: 700),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Image.asset('assets/lingua_flow.png'),
      ),
    );
  }
}
