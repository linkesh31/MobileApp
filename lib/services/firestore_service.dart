import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> addInventoryItem(Map<String, dynamic> itemData) async {
    await _db.collection('inventory').add(itemData);
  }

  Stream<QuerySnapshot> getInventoryItems() {
    return _db.collection('inventory').snapshots();
  }
}
