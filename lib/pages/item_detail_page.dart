import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'edit_item_page.dart';

class ItemDetailPage extends StatelessWidget {
  final String docId;

  const ItemDetailPage({super.key, required this.docId});

  void _showSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 260,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, size: 50, color: Colors.green),
                const SizedBox(height: 12),
                Text('Success',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 8),
                Text('Item deleted successfully.',
                    style: GoogleFonts.poppins(fontSize: 14),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );

    Future.delayed(const Duration(seconds: 2), () {
      Navigator.of(context).pop(); // Close dialog
      Navigator.of(context).pop(); // Go back to inventory list
    });
  }

  void _confirmDelete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Confirm Delete', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete this item?', style: GoogleFonts.poppins()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Delete', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('inventory').doc(docId).delete();
        _showSuccessDialog(context);
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
      backgroundColor: const Color(0xFFFFEFEB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFEFEB),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text('Item Details',
            style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.w600)),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('inventory').doc(docId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Error loading item.'));
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Item not found.'));
          }

          final item = snapshot.data!.data() as Map<String, dynamic>;
          final itemName = item['itemName'] ?? 'Unnamed';
          final location = item['location'] ?? 'Unknown';
          final category = item['category'] ?? '-';
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
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  imageBytes,
                  width: double.infinity,
                  height: 220,
                  fit: BoxFit.cover,
                ),
              );
            } catch (_) {
              imageWidget = const Icon(Icons.broken_image, size: 100);
            }
          } else {
            imageWidget = const Icon(Icons.image_not_supported, size: 100);
          }

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      imageWidget,
                      const SizedBox(height: 20),
                      Text(itemName,
                          style: GoogleFonts.poppins(
                              fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black)),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              const Icon(Icons.location_on_outlined, size: 20),
                              const SizedBox(width: 8),
                              Text("Location: $location", style: GoogleFonts.poppins()),
                            ]),
                            const SizedBox(height: 8),
                            Row(children: [
                              const Icon(Icons.category_outlined, size: 20),
                              const SizedBox(width: 8),
                              Text("Category: $category", style: GoogleFonts.poppins()),
                            ]),
                            const SizedBox(height: 8),
                            Row(children: [
                              const Icon(Icons.label_outline, size: 20),
                              const SizedBox(width: 8),
                              Text("Label(s): $label", style: GoogleFonts.poppins()),
                            ]),
                            const Divider(height: 24),
                            Text("Price (MYR): RM $priceMYR",
                                style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold, color: Colors.red)),
                            const SizedBox(height: 6),
                            Text("Converted: $targetCurrency ≈ $convertedPrice",
                                style: GoogleFonts.poppins(color: Colors.green)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
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
                        icon: const Icon(Icons.edit, color: Colors.deepPurple),
                        label: Text('Edit', style: GoogleFonts.poppins()),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.black,
                          backgroundColor: const Color(0xFFF3E8FF),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _confirmDelete(context),
                        icon: const Icon(Icons.delete),
                        label: Text('Delete', style: GoogleFonts.poppins(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
