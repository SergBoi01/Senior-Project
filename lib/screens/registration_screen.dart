import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:senior_project/services/backend_manager.dart';
import 'package:senior_project/screens/main_screen.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  _RegistrationScreenState createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;
  String _errorMessage = '';

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Email is required';
    final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!regex.hasMatch(value)) return 'Enter a valid email';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value != _passwordController.text) return 'Passwords do not match';
    return null;
  }

  Future<void> _register() async {
    setState(() => _errorMessage = '');
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      UserCredential cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (cred.user != null) {
        await BackendManager().loadUserData();

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => MainPage(),
          ),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Welcome! Your account has been created.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMsg;
      switch (e.code) {
        case 'email-already-in-use':
          errorMsg = 'An account with this email already exists';
          break;
        case 'invalid-email':
          errorMsg = 'Invalid email address';
          break;
        case 'operation-not-allowed':
          errorMsg = 'Registration is currently disabled';
          break;
        case 'weak-password':
          errorMsg = 'Password is too weak';
          break;
        default:
          errorMsg = 'Registration failed: ${e.message}';
      }
      setState(() {
        _errorMessage = errorMsg;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        backgroundColor: Colors.grey[300],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Icon(Icons.person_add_outlined, size: 80, color: Colors.blue[700]),
              const SizedBox(height: 16),
              Text('Join Symbol Recognition',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey[800]),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('Create an account to get started',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]), textAlign: TextAlign.center),
              const SizedBox(height: 40),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                  helperText: 'We\'ll use this for login',
                ),
                validator: _validateEmail,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                  helperText: 'At least 6 characters',
                  suffixIcon: IconButton(
                    icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                  ),
                ),
                obscureText: !_isPasswordVisible,
                validator: _validatePassword,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                  helperText: 'Re-enter your password',
                  suffixIcon: IconButton(
                    icon: Icon(_isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
                  ),
                ),
                obscureText: !_isConfirmPasswordVisible,
                validator: _validateConfirmPassword,
              ),
              const SizedBox(height: 12),
              if (_errorMessage.isNotEmpty)
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
                      Expanded(child: Text(_errorMessage, style: TextStyle(color: Colors.red[700], fontSize: 14))),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Create Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _isLoading ? null : () => Navigator.pop(context),
                child: Text('Already have an account? Login', style: TextStyle(fontSize: 14, color: Colors.blue[700])),
              ),
              const SizedBox(height: 24),
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
                    Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your data is stored locally on your device. We only use Firebase for authentication.',
                        style: TextStyle(color: Colors.blue[900], fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
