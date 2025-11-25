import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:senior_project/screens/main_screen.dart';
import 'package:senior_project/screens/registration_screen.dart';
import 'package:senior_project/models/user_data_manager_models.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  String errorMessage = '';
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  void onLoginSuccess(String userID) async {
    setState(() => _isLoading = true);
    
    await UserDataManager().loadUserData(userID);
    
    if (!mounted) return;
    
    setState(() => _isLoading = false);
    
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => MainPage(
          userID: userID,
          libraryStructure: UserDataManager().libraryRootFolders,
          userCorrections: UserDataManager().corrections,
        ),
      ),
    );
  }
  
  void login() async {
    String email = emailController.text.trim();
    String password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => errorMessage = 'Enter email & password');
      return;
    }

    setState(() => _isLoading = true);

    try {
      UserCredential cred = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      onLoginSuccess(cred.user!.uid);
    } catch (e) {
      setState(() {
        errorMessage = 'Invalid email or password';
        _isLoading = false;
      });
    }
  }


  void bypassLogin() async {
    setState(() => _isLoading = true);
    try {
      // Try to sign in the guest user.
      UserCredential cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: 'flutterdartguest123@gmail.com',
        password: 'flutterdartguest123',
      );
      onLoginSuccess(cred.user!.uid);
    } on FirebaseAuthException catch (e) {
      // If the user does not exist, create it.
      if (e.code == 'user-not-found') {
        try {
          UserCredential cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: 'flutterdartguest123@gmail.com',
            password: 'flutterdartguest123',
          );
          onLoginSuccess(cred.user!.uid);
        } catch (e) {
          setState(() {
            errorMessage = 'Failed to create guest user.';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          errorMessage = 'Bypass login failed.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'An unexpected error occurred during bypass login.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(
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
                    onPressed: _isLoading ? null : login,
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
                  ElevatedButton(
                    onPressed: _isLoading ? null : bypassLogin,
                    child: const Text('Bypass Login (Dev)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}