import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isLoading = false;

  void _showSnack(String message, [Color color = Colors.red]) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _resetPassword() async {
    setState(() {
      _isLoading = true;
    });

    final email = _emailController.text.trim().toLowerCase();
    final newPassword = _passwordController.text.trim();
    final confirmPassword = _confirmController.text.trim();

    if (email.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
      _showSnack('All fields are required.');
      setState(() => _isLoading = false);
      return;
    }

    if (newPassword.length < 6) {
      _showSnack('Password must be at least 6 characters.');
      setState(() => _isLoading = false);
      return;
    }

    if (newPassword != confirmPassword) {
      _showSnack('Passwords do not match.');
      setState(() => _isLoading = false);
      return;
    }

    try {
      final docRef =
      FirebaseFirestore.instance.collection('otp_verification').doc(email);
      final snapshot = await docRef.get();

      if (!snapshot.exists || !(snapshot.data()?['verified'] == true)) {
        _showSnack('Account with this email does not exist or is not verified.');
        setState(() => _isLoading = false);
        return;
      }

      final currentPassword = snapshot.data()?['password'];

      // Step 1: Sign in with old password
      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: currentPassword);

      // Step 2: Update password in FirebaseAuth
      await userCredential.user?.updatePassword(newPassword);

      // Step 3: Update Firestore password for consistency
      await docRef.update({'password': newPassword});

      _showSnack('Password updated successfully. You may now log in.', Colors.green);

      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
      }
    } catch (e) {
      _showSnack('Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Reset Password")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text("Enter your email and new password."),
            const SizedBox(height: 20),

            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: "Email",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "New Password",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _confirmController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Confirm Password",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton.icon(
              onPressed: _resetPassword,
              icon: const Icon(Icons.lock_reset),
              label: const Text("Submit"),
            ),
          ],
        ),
      ),
    );
  }
}
