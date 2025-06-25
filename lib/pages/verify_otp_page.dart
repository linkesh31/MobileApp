import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class VerifyOtpPage extends StatefulWidget {
  final String email;

  const VerifyOtpPage({super.key, required this.email});

  @override
  State<VerifyOtpPage> createState() => _VerifyOtpPageState();
}

class _VerifyOtpPageState extends State<VerifyOtpPage> {
  final _otpController = TextEditingController();
  bool _isVerifying = false;

  void _showSnack(String message, [Color color = Colors.red]) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _verifyOtp() async {
    setState(() {
      _isVerifying = true;
    });

    final enteredOtp = _otpController.text.trim();
    final docRef = FirebaseFirestore.instance
        .collection('otp_verification')
        .doc(widget.email.toLowerCase());

    try {
      final snapshot = await docRef.get();
      if (!snapshot.exists) {
        _showSnack('No OTP found. Please try signing up again.');
        return;
      }

      final data = snapshot.data()!;
      final storedOtp = data['otp'];
      final expiry = data['expiresAt'].toDate();
      final email = data['email'];
      final password = data['password'];

      if (DateTime.now().isAfter(expiry)) {
        _showSnack('OTP has expired. Please try again.');
        return;
      }

      if (enteredOtp != storedOtp) {
        _showSnack('Incorrect OTP. Try again.');
        return;
      }

      // Check if already registered
      final existingMethods =
      await FirebaseAuth.instance.fetchSignInMethodsForEmail(email);
      if (existingMethods.isNotEmpty) {
        _showSnack('This email is already registered. Try logging in.');
        return;
      }

      // Mark as verified
      await docRef.update({'verified': true});

      // Register user in FirebaseAuth
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (!mounted) return;

      _showSnack('OTP verified! Account created.', Colors.green);

      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      _showSnack('An error occurred: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify OTP')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              'Enter the 6-digit OTP sent to your email.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),

            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'OTP Code',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),
            _isVerifying
                ? const CircularProgressIndicator()
                : ElevatedButton.icon(
              onPressed: _verifyOtp,
              icon: const Icon(Icons.verified),
              label: const Text('Verify'),
            ),
          ],
        ),
      ),
    );
  }
}
