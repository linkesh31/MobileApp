// No changes made to the logic, as the code you posted is already solid.
// Just confirming this is your finalized working version with everything in place:
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../services/image_labeling_service.dart';
import '../services/firestore_service.dart';

class AddItemPage extends StatefulWidget {
  const AddItemPage({super.key});

  @override
  State<AddItemPage> createState() => _AddItemPageState();
}

class _AddItemPageState extends State<AddItemPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();

  final ImageLabelService _labelService = ImageLabelService();
  final FirestoreService _firestoreService = FirestoreService();

  File? _image;
  List<String> _labels = [];
  String _selectedCurrency = 'USD';
  double? _convertedAmount;
  DateTime? _selectedDate;

  final Map<String, String> _currencyWithFlags = {
    'USD': '🇺🇸 USD', 'EUR': '🇪🇺 EUR', 'GBP': '🇬🇧 GBP', 'SGD': '🇸🇬 SGD',
    'AUD': '🇦🇺 AUD', 'CAD': '🇨🇦 CAD', 'JPY': '🇯🇵 JPY', 'INR': '🇮🇳 INR',
    'THB': '🇹🇭 THB', 'CNY': '🇨🇳 CNY', 'KRW': '🇰🇷 KRW', 'IDR': '🇮🇩 IDR',
    'PHP': '🇵🇭 PHP', 'VND': '🇻🇳 VND', 'NZD': '🇳🇿 NZD', 'CHF': '🇨🇭 CHF',
    'HKD': '🇭🇰 HKD', 'SEK': '🇸🇪 SEK', 'MYR': '🇲🇾 MYR', 'BDT': '🇧🇩 BDT',
  };

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final imageFile = File(pickedFile.path);
      setState(() => _image = imageFile);

      final labels = await _labelService.labelImage(imageFile);
      if (labels.isNotEmpty) {
        setState(() {
          _labels = labels;
          _categoryController.text = labels.first;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No labels detected')),
        );
      }
    }
  }

  Future<String> _convertImageToBase64(File image) async {
    final bytes = await image.readAsBytes();
    return base64Encode(bytes);
  }

  Future<void> _updateLiveConversion() async {
    final price = double.tryParse(_priceController.text.trim());
    if (price == null || price <= 0) {
      setState(() => _convertedAmount = null);
      return;
    }

    try {
      final converted = await _convertMYRToTargetCurrency(price, _selectedCurrency);
      setState(() => _convertedAmount = converted);
    } catch (_) {
      setState(() => _convertedAmount = null);
    }
  }

  Future<double> _convertMYRToTargetCurrency(double myrAmount, String targetCurrency) async {
    const apiKey = 'b285077c31c7acfea2a137fa';
    final url = 'https://v6.exchangerate-api.com/v6/$apiKey/latest/MYR';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final rate = data['conversion_rates'][targetCurrency.toUpperCase()];
      if (rate != null) {
        return double.parse((myrAmount * rate).toStringAsFixed(2));
      } else {
        throw Exception("Invalid currency: $targetCurrency");
      }
    } else {
      throw Exception("Failed to fetch rates");
    }
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: DateTime(2022),
      lastDate: DateTime(today.year + 2),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _confirmAndSaveItem() async {
    final name = _nameController.text.trim();
    final location = _locationController.text.trim();
    final category = _categoryController.text.trim();
    final price = double.tryParse(_priceController.text.trim()) ?? 0.0;

    if (name.isEmpty || location.isEmpty || category.isEmpty || price <= 0 || _image == null || _selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all fields including image, date, and price')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Save'),
        content: const Text('Are you sure you want to add this item to your inventory?'),
        actions: [
          TextButton(child: const Text('Cancel'), onPressed: () => Navigator.pop(context, false)),
          TextButton(child: const Text('Save'), onPressed: () => Navigator.pop(context, true)),
        ],
      ),
    );

    if (confirm != true) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not logged in')),
      );
      return;
    }

    try {
      final base64Image = await _convertImageToBase64(_image!);
      final convertedPrice = await _convertMYRToTargetCurrency(price, _selectedCurrency);

      await _firestoreService.addInventoryItem({
        'userId': user.uid,
        'itemName': name,
        'location': location,
        'category': category,
        'label': _labels.join(', '),
        'priceMYR': price,
        'targetCurrency': _selectedCurrency,
        'convertedPrice': convertedPrice,
        'timestamp': _selectedDate,
        'imageBase64': base64Image,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item saved successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error saving item: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to convert or save: $e')),
      );
    }
  }

  @override
  void dispose() {
    _labelService.dispose();
    _nameController.dispose();
    _locationController.dispose();
    _priceController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateText = _selectedDate == null
        ? 'Select Date'
        : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}';

    return Scaffold(
      appBar: AppBar(title: const Text('Add Inventory Item')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Item Name'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _locationController,
                decoration: const InputDecoration(labelText: 'Location'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _categoryController,
                decoration: const InputDecoration(labelText: 'Category (auto-filled)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Price (MYR)'),
                onChanged: (_) => _updateLiveConversion(),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _selectedCurrency,
                items: _currencyWithFlags.entries.map((entry) {
                  return DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedCurrency = value);
                    _updateLiveConversion();
                  }
                },
                decoration: const InputDecoration(labelText: 'Convert to Currency'),
              ),
              const SizedBox(height: 8),
              if (_convertedAmount != null)
                Text(
                  '≈ $_convertedAmount $_selectedCurrency',
                  style: const TextStyle(fontSize: 16, color: Colors.green),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Date: $dateText',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today),
                    label: const Text('Pick Date'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _image != null
                  ? Image.file(_image!, height: 150)
                  : const Text('No image selected'),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.image),
                label: const Text('Pick Image & Auto-Categorize'),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _confirmAndSaveItem,
                icon: const Icon(Icons.save),
                label: const Text('Save to Firebase'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
