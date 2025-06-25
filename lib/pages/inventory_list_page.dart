import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'item_detail_page.dart';

class InventoryListPage extends StatefulWidget {
  const InventoryListPage({super.key});

  @override
  State<InventoryListPage> createState() => _InventoryListPageState();
}

class _InventoryListPageState extends State<InventoryListPage> {
  String _searchQuery = '';
  String _selectedCurrency = 'All';
  DateTime? _selectedDate;
  String _sortType = 'Latest';

  final Map<String, String> _currencyWithFlags = {
    'All': '🌐 All',
    'USD': '🇺🇸 USD',
    'EUR': '🇪🇺 EUR',
    'GBP': '🇬🇧 GBP',
    'SGD': '🇸🇬 SGD',
    'AUD': '🇦🇺 AUD',
    'CAD': '🇨🇦 CAD',
    'JPY': '🇯🇵 JPY',
    'INR': '🇮🇳 INR',
    'THB': '🇹🇭 THB',
    'CNY': '🇨🇳 CNY',
    'KRW': '🇰🇷 KRW',
    'IDR': '🇮🇩 IDR',
    'PHP': '🇵🇭 PHP',
    'VND': '🇻🇳 VND',
    'NZD': '🇳🇿 NZD',
    'CHF': '🇨🇭 CHF',
    'HKD': '🇭🇰 HKD',
    'SEK': '🇸🇪 SEK',
    'MYR': '🇲🇾 MYR',
    'BDT': '🇧🇩 BDT',
  };

  final List<String> _sortOptions = [
    'Latest',
    'Oldest',
    'Name A–Z',
    'Name Z–A',
    'Price Low–High',
    'Price High–Low',
  ];

  void _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(2022),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _clearDateFilter() {
    setState(() => _selectedDate = null);
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final dateText = _selectedDate == null
        ? 'Filter by Date'
        : 'Date: ${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}';

    return Scaffold(
      appBar: AppBar(title: const Text('My Inventory')),
      body: currentUser == null
          ? const Center(child: Text('Please login to view inventory'))
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search by name or label...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) =>
                  setState(() => _searchQuery = val.toLowerCase()),
            ),
          ),
          Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedCurrency,
                    items: _currencyWithFlags.entries.map((entry) {
                      return DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      );
                    }).toList(),
                    onChanged: (val) =>
                        setState(() => _selectedCurrency = val!),
                    decoration:
                    const InputDecoration(labelText: 'Currency'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _pickDate,
                        icon: const Icon(Icons.calendar_today),
                        label: Text(dateText),
                      ),
                      if (_selectedDate != null)
                        TextButton(
                          onPressed: _clearDateFilter,
                          child: const Text('Clear Date Filter'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButtonFormField<String>(
              value: _sortType,
              items: _sortOptions
                  .map((s) =>
                  DropdownMenuItem(value: s, child: Text('Sort: $s')))
                  .toList(),
              onChanged: (val) => setState(() => _sortType = val!),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('inventory')
                  .where('userId', isEqualTo: currentUser.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                      child: Text('Error loading data'));
                }

                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator());
                }

                List<QueryDocumentSnapshot> items =
                snapshot.data!.docs.where((doc) {
                  final item =
                  doc.data() as Map<String, dynamic>;
                  final name = (item['itemName'] ?? '')
                      .toString()
                      .toLowerCase();
                  final label = (item['label'] ?? '')
                      .toString()
                      .toLowerCase();
                  final currency =
                      item['targetCurrency'] ?? 'USD';
                  final timestamp = item['timestamp'];

                  final matchSearch = name.contains(_searchQuery) ||
                      label.contains(_searchQuery);
                  final matchCurrency = _selectedCurrency == 'All' ||
                      _selectedCurrency == currency;

                  bool matchDate = true;
                  if (_selectedDate != null &&
                      timestamp is Timestamp) {
                    final itemDate = timestamp.toDate();
                    matchDate =
                        itemDate.year == _selectedDate!.year &&
                            itemDate.month ==
                                _selectedDate!.month &&
                            itemDate.day == _selectedDate!.day;
                  }

                  return matchSearch &&
                      matchCurrency &&
                      matchDate;
                }).toList();

                // Sorting Logic
                items.sort((a, b) {
                  final aData =
                  a.data() as Map<String, dynamic>;
                  final bData =
                  b.data() as Map<String, dynamic>;
                  switch (_sortType) {
                    case 'Oldest':
                      return (aData['timestamp'] as Timestamp)
                          .compareTo(bData['timestamp'] as Timestamp);
                    case 'Name A–Z':
                      return (aData['itemName'] ?? '')
                          .toString()
                          .compareTo(
                          (bData['itemName'] ?? '').toString());
                    case 'Name Z–A':
                      return (bData['itemName'] ?? '')
                          .toString()
                          .compareTo(
                          (aData['itemName'] ?? '').toString());
                    case 'Price Low–High':
                      return (aData['priceMYR'] ?? 0.0)
                          .compareTo(bData['priceMYR'] ?? 0.0);
                    case 'Price High–Low':
                      return (bData['priceMYR'] ?? 0.0)
                          .compareTo(aData['priceMYR'] ?? 0.0);
                    default:
                      return (bData['timestamp'] as Timestamp)
                          .compareTo(aData['timestamp'] as Timestamp);
                  }
                });

                if (items.isEmpty) {
                  return const Center(
                      child:
                      Text('No items match your filters.'));
                }

                return ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) =>
                  const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final doc = items[index];
                    final item =
                    doc.data() as Map<String, dynamic>;

                    final itemName =
                        item['itemName'] ?? 'Unnamed';
                    final location =
                        item['location'] ?? 'Unknown';
                    final category =
                        item['category'] ?? 'Uncategorized';
                    final label = item['label'] ?? '-';
                    final priceMYR = item['priceMYR']
                        ?.toStringAsFixed(2) ??
                        '0.00';
                    final targetCurrency =
                        item['targetCurrency'] ?? 'USD';
                    final convertedPrice = item['convertedPrice']
                        ?.toStringAsFixed(2) ??
                        '0.00';
                    final base64Image =
                    item['imageBase64'];

                    Widget imageWidget;
                    if (base64Image != null &&
                        base64Image.isNotEmpty) {
                      try {
                        final imageBytes =
                        base64Decode(base64Image);
                        imageWidget = ClipRRect(
                          borderRadius:
                          BorderRadius.circular(8),
                          child: Image.memory(
                            imageBytes,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                          ),
                        );
                      } catch (e) {
                        imageWidget = const Icon(
                            Icons.broken_image);
                      }
                    } else {
                      imageWidget = const Icon(
                          Icons.image_not_supported);
                    }

                    return ListTile(
                      leading: imageWidget,
                      title: Text(itemName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold)),
                      subtitle: Padding(
                        padding:
                        const EdgeInsets.only(top: 4.0),
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text('Location: $location'),
                            Text('Category: $category'),
                            Text('Label(s): $label'),
                            Text('Price: RM $priceMYR'),
                            Text(
                                '$targetCurrency ≈ $convertedPrice'),
                          ],
                        ),
                      ),
                      isThreeLine: true,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ItemDetailPage(docId: doc.id),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
