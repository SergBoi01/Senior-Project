import 'package:flutter/material.dart';
import 'package:senior_project/screens/main_page.dart';
import 'package:senior_project/screens/registration_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:senior_project/screens/glossary_backend.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  String errorMessage = '';
  bool _isPasswordVisible = false;

  void login() async {
    String email = emailController.text.trim();
    String password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        errorMessage = 'Please enter both email and password';
      });
      return;
    }

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create and load the glossary
      final glossary = Glossary();
      await glossary.loadFromFirestore();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (context) => MainPage(
                  glossary: glossary,
                )),
      );
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Error: ${e.code} - ${e.message}');
      setState(() {
        errorMessage = 'Login failed. Check console for details.';
      });
    } 
    catch (e) {
      print('An unexpected error occurred: $e');
      setState(() {
        errorMessage = 'An unexpected error occurred.';
      });
    }
  }
  void bypassLogin() async {
    // Create and load the glossary
    final glossary = Glossary();
    await glossary.loadFromFirestore();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
          builder: (context) => MainPage(
                glossary: glossary,
              )),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
      ),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),
            TextField(
              controller: passwordController,
              decoration: InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                ),
              ),
              obscureText: !_isPasswordVisible,
            ),
            SizedBox(height: 10),
            if (errorMessage.isNotEmpty)
              Text(
                errorMessage,
                style: TextStyle(color: Colors.red),
              ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: login,
              child: const Text('Login'),
            ),
            SizedBox(height: 10),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => RegistrationScreen()),
                );
              },
              child: Text('Don\'t have an account? Create one'),
            ),
            SizedBox(height: 10),
            TextButton(
              onPressed: bypassLogin,
              child: const Text('Bypass Login (Dev)'),
            ),
          ],
        ),
      ),
    );
  }
}