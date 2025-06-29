// your imports...
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/image_labeling_service.dart';
import '../services/firestore_service.dart';

class AddItemPage extends StatefulWidget {
  const AddItemPage({super.key});

  @override
  State<AddItemPage> createState() => _AddItemPageState();
}

class _AddItemPageState extends State<AddItemPage> {
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _priceController = TextEditingController();
  final _categoryController = TextEditingController();

  final _labelService = ImageLabelService();
  final _firestoreService = FirestoreService();

  File? _image;
  List<String> _labels = [];
  String _selectedCurrency = 'USD';
  double? _convertedAmount;

  final Map<String, String> _currencyWithFlags = {
    'USD': '🇺🇸 USD', 'EUR': '🇪🇺 EUR', 'GBP': '🇬🇧 GBP', 'SGD': '🇸🇬 SGD',
    'AUD': '🇦🇺 AUD', 'CAD': '🇨🇦 CAD', 'JPY': '🇯🇵 JPY', 'INR': '🇮🇳 INR',
    'THB': '🇹🇭 THB', 'CNY': '🇨🇳 CNY', 'KRW': '🇰🇷 KRW', 'IDR': '🇮🇩 IDR',
    'PHP': '🇵🇭 PHP', 'VND': '🇻🇳 VND', 'NZD': '🇳🇿 NZD', 'CHF': '🇨🇭 CHF',
    'HKD': '🇭🇰 HKD', 'SEK': '🇸🇪 SEK', 'MYR': '🇲🇾 MYR', 'BDT': '🇧🇩 BDT',
  };

  Future<void> _showImageSourcePicker() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take a Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source);
    if (picked != null) {
      final file = File(picked.path);
      setState(() => _image = file);

      final labels = await _labelService.labelImage(file);
      if (labels.isNotEmpty) {
        setState(() {
          _labels = labels;
          _categoryController.text = labels.first;
        });
      }
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
        throw Exception("Invalid currency");
      }
    } else {
      throw Exception("Failed to fetch rates");
    }
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

  Future<void> _saveItem() async {
    final name = _nameController.text.trim();
    final location = _locationController.text.trim();
    final category = _categoryController.text.trim();
    final price = double.tryParse(_priceController.text.trim()) ?? 0.0;

    if (name.isEmpty || location.isEmpty || category.isEmpty || price <= 0 || _image == null) {
      _showErrorDialog('Please fill all fields and upload an image.');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showErrorDialog('User not logged in.');
      return;
    }

    try {
      final imageBytes = await _image!.readAsBytes();
      final base64Image = base64Encode(imageBytes);
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
        'timestamp': DateTime.now(),
        'imageBase64': base64Image,
      });

      if (mounted) _showSuccessDialog();
    } catch (e) {
      _showErrorDialog("Failed to save item: $e");
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, size: 60, color: Colors.deepOrangeAccent),
            const SizedBox(height: 10),
            Text('Success', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Item successfully saved!', textAlign: TextAlign.center, style: GoogleFonts.poppins()),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pop(context);
              },
              child: Text('OK', style: GoogleFonts.poppins()),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrangeAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            )
          ],
        ),
      ),
    );
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
    return Scaffold(
      backgroundColor: const Color(0xFFFDECE8),
      appBar: AppBar(
        leading: const BackButton(),
        title: Text('Add Inventory Item', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFFFDECE8),
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInputCard(),
            const SizedBox(height: 16),
            Text('Convert to Currency', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
            DropdownButtonFormField<String>(
              value: _selectedCurrency,
              items: _currencyWithFlags.entries.map((entry) {
                return DropdownMenuItem(
                  value: entry.key,
                  child: Text(entry.value, style: GoogleFonts.poppins()),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedCurrency = value);
                  _updateLiveConversion();
                }
              },
              decoration: const InputDecoration(border: UnderlineInputBorder()),
            ),
            const SizedBox(height: 8),
            if (_convertedAmount != null)
              Text('≈ $_convertedAmount $_selectedCurrency',
                  style: GoogleFonts.poppins(fontSize: 16, color: Colors.green)),
            const SizedBox(height: 16),
            _buildImageCard(),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _showImageSourcePicker,
              icon: const Icon(Icons.add_a_photo),
              label: Text("Upload or Take Photo", style: GoogleFonts.poppins()),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFCDDC3),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                minimumSize: const Size.fromHeight(50),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _saveItem,
              child: Text("Save", style: GoogleFonts.poppins()),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5E5E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                minimumSize: const Size.fromHeight(50),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          TextField(
            controller: _nameController,
            decoration: InputDecoration(labelText: 'Item Name', labelStyle: GoogleFonts.poppins()),
            style: GoogleFonts.poppins(),
          ),
          TextField(
            controller: _locationController,
            decoration: InputDecoration(labelText: 'Location', labelStyle: GoogleFonts.poppins()),
            style: GoogleFonts.poppins(),
          ),
          TextField(
            controller: _categoryController,
            decoration: InputDecoration(labelText: 'Category', labelStyle: GoogleFonts.poppins()),
            style: GoogleFonts.poppins(),
          ),
          TextField(
            controller: _priceController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: 'Price (MYR)', labelStyle: GoogleFonts.poppins()),
            onChanged: (_) => _updateLiveConversion(),
            style: GoogleFonts.poppins(),
          ),
        ],
      ),
    );
  }

  Widget _buildImageCard() {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: _image != null
          ? ClipRRect(borderRadius: BorderRadius.circular(18), child: Image.file(_image!, fit: BoxFit.cover))
          : Center(child: Text('No image selected', style: GoogleFonts.poppins())),
    );
  }
}
