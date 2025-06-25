import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  String? _message;

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

  Future<void> _updateName() async {
    if (_nameController.text.trim().isEmpty) {
      _showPopup('Please enter a name.');
      return;
    }

    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      await FirebaseFirestore.instance
          .collection('otp_verification')
          .doc(user.email)
          .update({'name': _nameController.text.trim()});

      setState(() {
        _isEditing = false;
        _message = 'Name updated successfully.';
      });
    } catch (e) {
      setState(() {
        _message = 'Error: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _changePassword() async {
    final currentPassword = _currentPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();

    if (currentPassword.isEmpty || newPassword.isEmpty) {
      _showPopup('Please fill in both password fields.');
      return;
    }

    if (newPassword.length < 6) {
      _showPopup('New password must be at least 6 characters.');
      return;
    }

    setState(() {
      _isLoading = true;
      _message = null;
    });

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

      setState(() {
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _message = 'Password updated successfully.';
      });
    } catch (e) {
      setState(() => _message = 'Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete your account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
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

        await user.delete();
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
        }
      } catch (e) {
        setState(() => _message = 'Error deleting account: $e');
      }
    }
  }

  void _showPopup(String msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Validation'),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_message!, style: const TextStyle(color: Colors.red)),
              ),
            const Text('Profile Info', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            TextField(
              controller: _nameController,
              enabled: _isEditing,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: TextEditingController(text: user.email),
              enabled: false,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () {
                    if (_isEditing) {
                      _updateName();
                    } else {
                      setState(() => _isEditing = true);
                    }
                  },
                  child: Text(_isEditing ? 'Save' : 'Edit Name'),
                ),
                if (_isEditing)
                  TextButton(
                    onPressed: () => setState(() {
                      _isEditing = false;
                      _loadUserData();
                    }),
                    child: const Text('Cancel'),
                  ),
              ],
            ),
            const Divider(height: 40),
            const Text('Change Password', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            TextField(
              controller: _currentPasswordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current Password'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _newPasswordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New Password'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _changePassword,
              child: const Text('Update Password'),
            ),
            const Divider(height: 40),
            Center(
              child: ElevatedButton.icon(
                onPressed: _deleteAccount,
                icon: const Icon(Icons.delete),
                label: const Text('Delete Account'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              ),
            )
          ],
        ),
      ),
    );
  }
}
