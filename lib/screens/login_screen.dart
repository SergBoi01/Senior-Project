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

  /// Called after successful Firebase Auth login
  /// Loads all user data from SharedPreferences
  void onLoginSuccess(String userID) async {
    setState(() => _isLoading = true);
    
    try {
      print('[LoginScreen] Loading user data for: $userID');
      
      // Load all data from SharedPreferences
      await UserDataManager().loadUserData(userID);
      
      if (!mounted) return;
      
      print('[LoginScreen] User data loaded successfully');
      print('[LoginScreen] - Corrections: ${UserDataManager().corrections.length}');
      print('[LoginScreen] - Root folders: ${UserDataManager().libraryRootFolders.length}');
      print('[LoginScreen] - Pen width: ${UserDataManager().penWidth}');
      
      setState(() => _isLoading = false);
      
      // Navigate to main screen
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
    } catch (e) {
      print('[LoginScreen] Failed to load user data: $e');
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          errorMessage = 'Failed to load user data. Please try again.';
        });
      }
    }
  }
  
  /// Standard login with email/password
  void login() async {
    String email = emailController.text.trim();
    String password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => errorMessage = 'Enter email & password');
      return;
    }

    setState(() {
      _isLoading = true;
      errorMessage = '';
    });

    try {
      print('[LoginScreen] Attempting login for: $email');
      
      UserCredential cred = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      
      print('[LoginScreen] Firebase Auth successful');
      onLoginSuccess(cred.user!.uid);
    } on FirebaseAuthException catch (e) {
      print('[LoginScreen] Firebase Auth failed: ${e.code}');
      
      setState(() {
        if (e.code == 'user-not-found') {
          errorMessage = 'No account found with this email';
        } else if (e.code == 'wrong-password') {
          errorMessage = 'Incorrect password';
        } else if (e.code == 'invalid-email') {
          errorMessage = 'Invalid email format';
        } else if (e.code == 'user-disabled') {
          errorMessage = 'This account has been disabled';
        } else {
          errorMessage = 'Login failed: ${e.message}';
        }
        _isLoading = false;
      });
    } catch (e) {
      print('[LoginScreen] Unexpected error: $e');
      
      setState(() {
        errorMessage = 'An unexpected error occurred';
        _isLoading = false;
      });
    }
  }

  /// Bypass login for development/testing
  /// Uses a shared guest account
  void bypassLogin() async {
    setState(() {
      _isLoading = true;
      errorMessage = '';
    });
    
    const String email = 'flutterdartguest123@gmail.com';
    const String password = 'flutterdartguest123';

    try {
      print('[LoginScreen] Attempting bypass login');
      
      // Try to sign in
      UserCredential cred = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      
      print('[LoginScreen] Bypass login successful');
      onLoginSuccess(cred.user!.uid);
      
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        // Guest account doesn't exist, create it
        try {
          print('[LoginScreen] Creating guest account');
          
          UserCredential cred = await FirebaseAuth.instance
              .createUserWithEmailAndPassword(email: email, password: password);
          
          print('[LoginScreen] Guest account created');
          onLoginSuccess(cred.user!.uid);
        } catch (e) {
          print('[LoginScreen] Failed to create guest account: $e');
          
          setState(() {
            errorMessage = 'Failed to create guest account';
            _isLoading = false;
          });
        }
      } else {
        print('[LoginScreen] Bypass login failed: ${e.code}');
        
        setState(() {
          errorMessage = 'Bypass login failed: ${e.message}';
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        backgroundColor: Colors.grey[300],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Loading your data...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  
                  // App title/logo area
                  Icon(
                    Icons.draw,
                    size: 80,
                    color: Colors.blue[700],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Symbol Recognition',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in to continue',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Email field
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Password field
                  TextField(
                    controller: passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible 
                              ? Icons.visibility 
                              : Icons.visibility_off,
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
                  
                  const SizedBox(height: 12),
                  
                  // Error message
                  if (errorMessage.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red[300]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red[700]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              errorMessage,
                              style: TextStyle(
                                color: Colors.red[700],
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  const SizedBox(height: 24),
                  
                  // Login button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Login',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Create account button
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const RegistrationScreen(),
                              ),
                            );
                          },
                    child: Text(
                      "Don't have an account? Create one",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue[700],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Divider
                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.grey[400])),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'OR',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.grey[400])),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Bypass login button (for development)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : bypassLogin,
                      icon: const Icon(Icons.engineering),
                      label: const Text('Guest Login (Development)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[700],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Info about guest login
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, 
                          color: Colors.blue[700], 
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Guest login uses a shared account for testing. Your data is stored locally on this device.',
                            style: TextStyle(
                              color: Colors.blue[900],
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}