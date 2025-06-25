import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'add_item_page.dart';
import 'inventory_list_page.dart';
import 'profile_page.dart'; // <-- make sure this is imported

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _userName;

  @override
  void initState() {
    super.initState();
    _fetchUserName();
  }

  Future<void> _fetchUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('otp_verification')
          .doc(user.email?.toLowerCase())
          .get();

      if (doc.exists && doc.data() != null) {
        setState(() {
          _userName = doc.data()!['name'] ?? '';
        });
      }
    }
  }

  Stream<QuerySnapshot> _inventoryStream() {
    final user = FirebaseAuth.instance.currentUser;
    return FirebaseFirestore.instance
        .collection('inventory')
        .where('userId', isEqualTo: user?.uid)
        .snapshots();
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text('Logout'),
            onPressed: () async {
              Navigator.pop(context);
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),
    );
  }

  void _showSnack(String message, [Color color = Colors.red]) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initials = (_userName != null && _userName!.isNotEmpty)
        ? _userName![0].toUpperCase()
        : '?';
    final welcomeText = (_userName != null && _userName!.isNotEmpty)
        ? 'Welcome, $_userName!'
        : 'Welcome!';

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(welcomeText),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => _confirmLogout(context),
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfilePage()),
              ).then((_) {
                _fetchUserName(); // Reload name after returning from ProfilePage
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: CircleAvatar(
                backgroundColor: Colors.grey[300],
                child: Text(
                  initials,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _inventoryStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            _showSnack('Error loading inventory.');
            return const Center(child: Text('Something went wrong.'));
          }

          final docs = snapshot.data?.docs ?? [];
          final itemCount = docs.length;
          double totalMYR = 0.0;

          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            totalMYR += (data['priceMYR'] ?? 0).toDouble();
          }

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  elevation: 3,
                  child: ListTile(
                    title: const Text('Total Inventory Items'),
                    trailing: Text('$itemCount'),
                  ),
                ),
                const SizedBox(height: 10),
                Card(
                  elevation: 3,
                  child: ListTile(
                    title: const Text('Total Spendings (MYR)'),
                    trailing: Text('RM ${totalMYR.toStringAsFixed(2)}'),
                  ),
                ),
                const SizedBox(height: 30),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add Inventory'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddItemPage()),
                    );
                  },
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.inventory),
                  label: const Text('View Inventory'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const InventoryListPage()),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
