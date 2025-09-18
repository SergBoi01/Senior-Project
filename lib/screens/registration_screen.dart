import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RegistrationScreen extends StatefulWidget {
  @override
  _RegistrationScreenState createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  // Real-time password validation state
  bool _hasUppercase = false;
  bool _hasSpecialChar = false;
  bool _hasStartedTyping = false;

  void _checkPasswordStrength(String password) {
    setState(() {
      _hasStartedTyping = true;
      _hasUppercase = false;
      _hasSpecialChar = false;
      
      // Check for uppercase
      for (int i = 0; i < password.length; i++) {
        if (password[i] == password[i].toUpperCase() && password[i] != password[i].toLowerCase()) {
          _hasUppercase = true;
          break;
        }
      }
      
      // Check for special character
      String specialChars = "!@#\$%^&*()_+-=[]{}|;':\",./<>?";
      for (int i = 0; i < password.length; i++) {
        if (specialChars.contains(password[i])) {
          _hasSpecialChar = true;
          break;
        }
      }
    });
  }

  void _register() async {
    // Check if password meets requirements
    if (!_hasUppercase || !_hasSpecialChar) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please meet all password requirements')),
      );
      return;
    }

    // Check if passwords match
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    try {
      // Create user account with Firebase
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Account created successfully!')),
      );

    } catch (e) {
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
              onChanged: _checkPasswordStrength,
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

            // Password strength indicators - only show when user is typing and has text
            if (_hasStartedTyping && _passwordController.text.isNotEmpty)
              Padding(
              padding: EdgeInsets.only(left: 16, top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _hasUppercase ? Icons.check_circle : Icons.cancel,
                        color: _hasUppercase ? Colors.green : Colors.red,
                        size: 16,
                      ),
                      SizedBox(width: 8),
                      Text(
                        _hasUppercase ? 'Has uppercase letter' : 'Needs uppercase letter',
                        style: TextStyle(
                          color: _hasUppercase ? Colors.green : Colors.red,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        _hasSpecialChar ? Icons.check_circle : Icons.cancel,
                        color: _hasSpecialChar ? Colors.green : Colors.red,
                        size: 16,
                      ),
                      SizedBox(width: 8),
                      Text(
                        _hasSpecialChar ? 'Has special character' : 'Needs at least one special character',
                        style: TextStyle(
                          color: _hasSpecialChar ? Colors.green : Colors.red,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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