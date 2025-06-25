import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'edit_item_page.dart';

class ItemDetailPage extends StatelessWidget {
  final String docId;

  const ItemDetailPage({super.key, required this.docId});

  void _confirmDelete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this item?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('inventory').doc(docId).delete();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item deleted successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting item: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Item Details')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('inventory').doc(docId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading item.'));
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Item not found.'));
          }

          final item = snapshot.data!.data() as Map<String, dynamic>;

          final itemName = item['itemName'] ?? 'Unnamed';
          final location = item['location'] ?? 'Unknown';
          final category = item['category'] ?? 'Uncategorized';
          final label = item['label'] ?? '-';
          final priceMYR = item['priceMYR']?.toStringAsFixed(2) ?? '0.00';
          final targetCurrency = item['targetCurrency'] ?? 'USD';
          final convertedPrice = item['convertedPrice']?.toStringAsFixed(2) ?? '0.00';
          final base64Image = item['imageBase64'];

          Widget imageWidget;
          if (base64Image != null && base64Image.isNotEmpty) {
            try {
              final imageBytes = base64Decode(base64Image);
              imageWidget = ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  imageBytes,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                ),
              );
            } catch (e) {
              imageWidget = const Icon(Icons.broken_image, size: 100);
            }
          } else {
            imageWidget = const Icon(Icons.image_not_supported, size: 100);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                imageWidget,
                const SizedBox(height: 16),
                Text('Item Name: $itemName', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Location: $location', style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                Text('Category: $category', style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                Text('Label(s): $label', style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                Text('Price (MYR): RM $priceMYR', style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                Text('Converted: $targetCurrency ≈ $convertedPrice', style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EditItemPage(
                              docId: docId,
                              currentLocation: location,
                              currentPrice: item['priceMYR'] ?? 0.0,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _confirmDelete(context),
                      icon: const Icon(Icons.delete),
                      label: const Text('Delete'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                )
              ],
            ),
          );
        },
      ),
    );
  }
}
