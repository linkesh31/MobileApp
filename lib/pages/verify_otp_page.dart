import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class VerifyOtpPage extends StatefulWidget {
  final String email;
  final String name;
  final String password;

  const VerifyOtpPage({
    super.key,
    required this.email,
    required this.name,
    required this.password,
  });

  @override
  State<VerifyOtpPage> createState() => _VerifyOtpPageState();
}

class _VerifyOtpPageState extends State<VerifyOtpPage>
    with SingleTickerProviderStateMixin {
  final List<TextEditingController> _controllers =
  List.generate(6, (_) => TextEditingController());
  bool _isVerifying = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    _animationController.dispose();
    super.dispose();
  }

  void _showPopup(String title, String message, Color color) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 15,
                  spreadRadius: 5,
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  color == Colors.green ? Icons.check_circle : Icons.error,
                  color: color,
                  size: 60,
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (Navigator.canPop(context)) Navigator.of(context).pop();
    });
  }

  Future<void> _verifyOtp() async {
    final enteredOtp = _controllers.map((c) => c.text).join();
    final cleanedEmail = widget.email.toLowerCase().trim();

    if (enteredOtp.length < 6) {
      _showPopup("Error", "Please enter the full 6-digit OTP.", Colors.red);
      return;
    }

    setState(() => _isVerifying = true);

    final docRef = FirebaseFirestore.instance
        .collection('otp_verification')
        .doc(cleanedEmail);

    try {
      final snapshot = await docRef.get();
      if (!snapshot.exists) {
        _showPopup("Error", "OTP record not found. Try signing up again.", Colors.red);
        return;
      }

      final data = snapshot.data()!;
      final storedOtp = data['otp'];
      final expiry = data['expiresAt'].toDate();
      final latestPassword = data['password'];

      if (enteredOtp != storedOtp) {
        _showPopup("Error", "Incorrect OTP. Try again.", Colors.red);
        return;
      }

      if (DateTime.now().isAfter(expiry)) {
        _showPopup("Error", "OTP expired. Please sign up again.", Colors.red);
        return;
      }

      final methods =
      await FirebaseAuth.instance.fetchSignInMethodsForEmail(cleanedEmail);
      if (methods.isEmpty) {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: cleanedEmail,
          password: latestPassword,
        );
      }

      await FirebaseFirestore.instance.collection('users').doc(cleanedEmail).set({
        'name': widget.name,
        'email': cleanedEmail,
        'isVerified': true,
        'password': latestPassword,
        'category': 'default',
        'createdAt': DateTime.now(),
      }, SetOptions(merge: true)); // ensure updated

      await docRef.update({'verified': true});

      if (!mounted) return;

      _showPopup("Success", "OTP verified! Account created.", Colors.green);
      await Future.delayed(const Duration(seconds: 2));
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      _showPopup("Error", "Error during verification: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Widget _buildOtpField(int index) {
    return Container(
      width: 45,
      height: 55,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: _controllers[index],
        keyboardType: TextInputType.number,
        maxLength: 1,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 20),
        decoration: const InputDecoration(
          border: InputBorder.none,
          counterText: "",
        ),
        onChanged: (value) {
          if (value.isNotEmpty && index < 5) {
            FocusScope.of(context).nextFocus();
          } else if (value.isEmpty && index > 0) {
            FocusScope.of(context).previousFocus();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFEFE8),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: BackButton(color: Colors.black87),
              ),
              const SizedBox(height: 20),
              const Text(
                'Verification Code',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                'We have sent the verification code to your email address',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, (index) => _buildOtpField(index)),
              ),
              const SizedBox(height: 40),
              _isVerifying
                  ? const CircularProgressIndicator()
                  : SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _verifyOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFE0000),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: const Text(
                    'Confirm',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
