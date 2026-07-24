import 'package:cloud_firestore/cloud_firestore.dart';

class Drug {
  final String? id;
  final String name;
  final double pricePerUnit;
  final double? pricePerPacket;
  final int? packetSize;
  final String unitLabel;
  final int quantity;
  final String category;
  final DateTime? expiryDate;
  final String? imageUrl;
  final DocumentReference? reference;

  bool get inStock => quantity > 0;

  Drug({
    this.id,
    required this.name,
    required this.pricePerUnit,
    this.pricePerPacket,
    this.packetSize,
    this.unitLabel = 'unit',
    required this.quantity,
    this.category = '',
    this.expiryDate,
    this.imageUrl,
    this.reference,
  });

  /// Legacy compat — returns pricePerUnit
  double get price => pricePerUnit;

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'pricePerUnit': pricePerUnit,
      'pricePerPacket': pricePerPacket,
      'packetSize': packetSize,
      'unitLabel': unitLabel,
      'quantity': quantity,
      'category': category,
      'expiryDate': expiryDate?.toIso8601String(),
      'imageUrl': imageUrl,
    };
  }

  factory Drug.fromMap(String id, Map<String, dynamic> map,
      {DocumentReference? reference}) {
    DateTime? exp;
    if (map['expiryDate'] != null) {
      if (map['expiryDate'] is Timestamp) {
        exp = (map['expiryDate'] as Timestamp).toDate();
      } else {
        exp = DateTime.tryParse(map['expiryDate'].toString());
      }
    }

    // Handle legacy single 'price' field
    final ppu = (map['pricePerUnit'] ?? map['price'] ?? 0).toDouble();
    final pp = map['pricePerPacket'] != null
        ? (map['pricePerPacket'] as num).toDouble()
        : null;
    final ps = map['packetSize'] != null
        ? (map['packetSize'] as num).toInt()
        : null;

    return Drug(
      id: id,
      name: map['name'] ?? '',
      pricePerUnit: ppu,
      pricePerPacket: pp,
      packetSize: ps,
      unitLabel: map['unitLabel'] ?? 'unit',
      quantity: (map['quantity'] ?? 0).toInt(),
      category: map['category'] ?? '',
      expiryDate: exp,
      imageUrl: map['imageUrl'],
      reference: reference,
    );
  }
}
