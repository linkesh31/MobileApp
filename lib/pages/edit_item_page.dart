import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditItemPage extends StatefulWidget {
  final String docId;
  final String currentLocation;
  final double currentPrice;

  const EditItemPage({
    super.key,
    required this.docId,
    required this.currentLocation,
    required this.currentPrice,
  });

  @override
  State<EditItemPage> createState() => _EditItemPageState();
}

class _EditItemPageState extends State<EditItemPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _locationController;
  late TextEditingController _priceController;

  @override
  void initState() {
    super.initState();
    _locationController = TextEditingController(text: widget.currentLocation);
    _priceController = TextEditingController(
      text: widget.currentPrice.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _locationController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (_formKey.currentState!.validate()) {
      final trimmedLocation = _locationController.text.trim();
      final price = double.tryParse(_priceController.text);

      if (price == null || price <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid price greater than 0')),
        );
        return;
      }

      try {
        await FirebaseFirestore.instance.collection('inventory').doc(widget.docId).update({
          'location': trimmedLocation,
          'priceMYR': price,
          'timestamp': FieldValue.serverTimestamp(), // optional: update time
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item updated successfully')),
        );
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating item: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Item')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  border: OutlineInputBorder(),
                ),
                validator: (val) =>
                val == null || val.isEmpty ? 'Please enter a location' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Price (MYR)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (val) {
                  final parsed = double.tryParse(val ?? '');
                  if (parsed == null || parsed <= 0) return 'Enter a valid price';
                  return null;
                },
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _saveChanges,
                icon: const Icon(Icons.save),
                label: const Text('Save Changes'),
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(45)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
