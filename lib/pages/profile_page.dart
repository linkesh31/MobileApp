import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final user = FirebaseAuth.instance.currentUser!;
  final _nameController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();

  bool _isEditing = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final doc = await FirebaseFirestore.instance
        .collection('otp_verification')
        .doc(user.email)
        .get();

    final name = doc.data()?['name'] ?? '';
    setState(() {
      _nameController.text = name;
    });
  }

  void _showPopup(String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.all(20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline, color: Colors.blue, size: 48),
            const SizedBox(height: 12),
            Text(title,
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Future<void> _updateName() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection('otp_verification')
          .doc(user.email)
          .update({'name': _nameController.text.trim()});

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.email)
          .update({'name': _nameController.text.trim()});

      setState(() => _isEditing = false);
      _showPopup('Success', 'Name updated successfully.');
    } catch (_) {
      _showPopup('Error', 'Something went wrong while updating name.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _changePassword() async {
    final currentPassword = _currentPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    if (currentPassword.isEmpty || newPassword.isEmpty) {
      _showPopup('Input Required',
          'Please enter both current and new passwords.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newPassword);

      await FirebaseFirestore.instance
          .collection('otp_verification')
          .doc(user.email)
          .update({'password': newPassword});

      // ✅ ALSO update password in `users` collection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.email)
          .update({'password': newPassword});

      _currentPasswordController.clear();
      _newPasswordController.clear();
      _showPopup('Success', 'Password updated successfully.');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password') {
        _showPopup('Incorrect Password', 'Incorrect password, please try again.');
      } else {
        _showPopup('Error', 'Incorrect password, please try again.');
      }
    } catch (_) {
      _showPopup('Error', 'Something went wrong. Try again later.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Confirm Delete',
            style: GoogleFonts.poppins(
                color: const Color(0xFFFE0000), fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete your account?',
            style: GoogleFonts.poppins(
                color: const Color(0xFFFE0000), fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFE0000),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete',
                style:
                GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('otp_verification')
            .doc(user.email)
            .delete();

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.email)
            .delete();

        await user.delete();
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
        }
      } catch (_) {
        _showPopup('Error', 'Failed to delete account.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final initials = _nameController.text.isNotEmpty
        ? _nameController.text[0].toUpperCase()
        : '?';

    return Scaffold(
      backgroundColor: const Color(0xFFFFF0EB),
      appBar: AppBar(
        title: Text("My Profile", style: GoogleFonts.poppins()),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.red.shade200,
              child: Text(initials,
                  style: GoogleFonts.poppins(
                      fontSize: 30,
                      color: const Color(0xFF3E2723),
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 30),
            _buildCard(
              children: [
                _buildLabeledField('Name', _nameController, _isEditing),
                const SizedBox(height: 12),
                _buildLabeledField('Email',
                    TextEditingController(text: user.email), false),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _isEditing
                            ? _updateName()
                            : setState(() => _isEditing = true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade200,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                        ),
                        child: Text(
                          _isEditing ? 'Save Name' : 'Edit Name',
                          style: GoogleFonts.poppins(
                              color: const Color(0xFFFFEFE8)),
                        ),
                      ),
                    ),
                    if (_isEditing)
                      TextButton(
                        onPressed: () {
                          setState(() => _isEditing = false);
                          _loadUserData();
                        },
                        child: Text('Cancel',
                            style: GoogleFonts.poppins()),
                      ),
                  ],
                )
              ],
            ),
            const SizedBox(height: 20),
            _buildCard(
              children: [
                _buildLabeledField('Current Password',
                    _currentPasswordController, true,
                    obscure: true),
                const SizedBox(height: 12),
                _buildLabeledField(
                    'New Password', _newPasswordController, true,
                    obscure: true),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _changePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade200,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                  child: Text('Update Password',
                      style: GoogleFonts.poppins(
                          color: const Color(0xFFFFEFE8))),
                ),
              ],
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: _deleteAccount,
              icon: const Icon(Icons.delete, color: Colors.black),
              label: Text('Delete Account',
                  style: GoogleFonts.poppins(color: Colors.black)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildLabeledField(String label, TextEditingController controller,
      bool enabled, {bool obscure = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins()),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          enabled: enabled,
          obscureText: obscure,
          style: GoogleFonts.poppins(),
          decoration: InputDecoration(
            contentPadding:
            const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            filled: true,
            fillColor: const Color(0xFFF7F7F7),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.grey),
            ),
          ),
        ),
      ],
    );
  }
}
