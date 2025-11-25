import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:senior_project/models/user_data_manager_models.dart';
import 'package:senior_project/screens/main_screen.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  _RegistrationScreenState createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  void _register() async {
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    // Show a loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      UserCredential cred =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      String userID = cred.user!.uid;
      // Initialize user data, though it will be empty for a new user
      await UserDataManager().loadUserData(userID);

      if (!mounted) return;

      // Dismiss the loading indicator before navigating
      Navigator.pop(context);

      // Navigate to the main page
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
      // Dismiss the loading indicator
      Navigator.pop(context);
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration failed: ${e.toString()}')),
      );
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Create Account'),
      ),
      body: Padding(
  padding: EdgeInsets.all(16.0),
  child: Column(
    children: [
      TextField(
        controller: _emailController,
        decoration: InputDecoration(
          labelText: 'Email',
          border: OutlineInputBorder(),
        ),
        keyboardType: TextInputType.emailAddress,
      ),
      SizedBox(height: 16),
      TextField(
        controller: _passwordController,
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
      SizedBox(height: 16),
      TextField(
        controller: _confirmPasswordController,
      decoration: InputDecoration(
        labelText: 'Confirm Password',
        border: OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: Icon(
            _isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
          ),
          onPressed: () {
            setState(() {
              _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
            });
          },
        ),
      ),
      obscureText: !_isConfirmPasswordVisible,
  ),
      SizedBox(height: 24),
ElevatedButton(
  onPressed: _register,
  child: Text('Create Account'),
),
    ],
  ),
),
    );
  }
}