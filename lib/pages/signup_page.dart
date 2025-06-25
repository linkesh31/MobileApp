import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/email_service.dart';
import 'verify_otp_page.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  /// Generates a 6-digit OTP
  String _generateOtp() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  void _showSnack(String message, [Color color = Colors.red]) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _sendOtpAndRedirect() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final name = _nameController.text.trim();
      final email = _emailController.text.trim().toLowerCase();
      final password = _passwordController.text.trim();

      // Basic validation
      if (name.isEmpty || email.isEmpty || password.length < 6) {
        _showSnack("Please fill all fields. Password must be at least 6 characters.");
        return;
      }

      final emailRegex = RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$");
      if (!emailRegex.hasMatch(email)) {
        _showSnack("Enter a valid email address.");
        return;
      }

      // Check if email already exists in FirebaseAuth
      final existingMethods =
      await FirebaseAuth.instance.fetchSignInMethodsForEmail(email);
      if (existingMethods.isNotEmpty) {
        _showSnack("Email already registered. Try logging in.");
        return;
      }

      final otp = _generateOtp();
      final emailService = EmailService();

      // Send OTP via SMTP
      await emailService.sendOtpEmail(
        recipientEmail: email,
        otp: otp,
      );

      // Save to Firestore
      await FirebaseFirestore.instance
          .collection('otp_verification')
          .doc(email)
          .set({
        'otp': otp,
        'expiresAt': DateTime.now().add(const Duration(minutes: 5)),
        'verified': false,
        'name': name,
        'email': email,
        'password': password,
      });

      if (!mounted) return;

      _showSnack("OTP sent to $email", Colors.green);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VerifyOtpPage(email: email),
        ),
      );
    } catch (e) {
      _showSnack("Failed to send OTP: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign Up')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const Text(
                "Create Account",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton.icon(
                onPressed: _sendOtpAndRedirect,
                icon: const Icon(Icons.email),
                label: const Text('Send OTP & Register'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
