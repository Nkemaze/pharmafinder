import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_web_app/models/drug.dart';
import 'package:pharmacy_web_app/services/pharmacy_hours.dart';

void main() {
  group('Drug.fromMap', () {
    test('parses modern fields', () {
      final drug = Drug.fromMap('drug1', {
        'name': 'Paracetamol',
        'pricePerUnit': 500,
        'pricePerPacket': 4500,
        'packetSize': 10,
        'unitLabel': 'tablet',
        'quantity': 25,
        'category': 'Pain Relief',
        'imageUrl': 'https://example.com/img.png',
      });
      expect(drug.name, 'Paracetamol');
      expect(drug.pricePerUnit, 500);
      expect(drug.pricePerPacket, 4500);
      expect(drug.packetSize, 10);
      expect(drug.unitLabel, 'tablet');
      expect(drug.quantity, 25);
      expect(drug.category, 'Pain Relief');
      expect(drug.imageUrl, 'https://example.com/img.png');
      expect(drug.inStock, isTrue);
    });

    test('supports legacy price field', () {
      final drug = Drug.fromMap('drug2', {
        'name': 'Ibuprofen',
        'price': 300,
        'quantity': 0,
      });
      expect(drug.pricePerUnit, 300);
      expect(drug.inStock, isFalse);
    });

    test('parses numeric values stored as strings', () {
      final drug = Drug.fromMap('drug-string-values', {
        'name': 'Vitamin C',
        'pricePerUnit': '750.50',
        'pricePerPacket': '7000',
        'packetSize': '10',
        'quantity': '12',
      });

      expect(drug.pricePerUnit, 750.50);
      expect(drug.pricePerPacket, 7000);
      expect(drug.packetSize, 10);
      expect(drug.quantity, 12);
    });

    test('parses expiry date from an ISO string', () {
      final drug = Drug.fromMap('drug3', {
        'name': 'Amoxicillin',
        'pricePerUnit': 1000,
        'quantity': 5,
        'expiryDate': '2027-12-31T00:00:00.000',
      });
      expect(drug.expiryDate, isNotNull);
      expect(drug.expiryDate!.year, 2027);
    });

    test('parses expiry date from a Firestore Timestamp', () {
      final drug = Drug.fromMap('drug4', {
        'name': 'Insulin',
        'pricePerUnit': 2000,
        'quantity': 3,
        'expiryDate': Timestamp.fromDate(DateTime(2026, 6, 1)),
      });
      expect(drug.expiryDate, isNotNull);
      expect(drug.expiryDate!.month, 6);
    });
  });

  group('PharmacyHours.isOpenNow', () {
    test('returns false when hours are missing', () {
      expect(PharmacyHours.isOpenNow({}), isFalse);
    });

    test('returns false for malformed times', () {
      expect(
        PharmacyHours.isOpenNow({
          'weekdayOpen': 'garbage',
          'weekdayClose': '9:00',
        }),
        isFalse,
      );
    });

    test('returns false when only one time is set', () {
      expect(
        PharmacyHours.isOpenNow({'weekdayOpen': '08:00'}),
        isFalse,
      );
    });

    test('manual override forces open regardless of schedule', () {
      expect(
        PharmacyHours.isOpenNow({
          'weekdayOpen': '00:00',
          'weekdayClose': '00:01',
          'hours': {'_manualOpen': true},
        }),
        isTrue,
      );
    });

    test('manual override forces closed regardless of schedule', () {
      expect(
        PharmacyHours.isOpenNow({
          'weekdayOpen': '00:00',
          'weekdayClose': '23:59',
          'hours': {'_manualOpen': false},
        }),
        isFalse,
      );
    });

    test('hasManualOverride reflects the flag', () {
      expect(PharmacyHours.hasManualOverride({}), isFalse);
      expect(
        PharmacyHours.hasManualOverride({
          'hours': {'_manualOpen': false},
        }),
        isTrue,
      );
      expect(PharmacyHours.manualOpen({'hours': <String, dynamic>{}}), isNull);
      expect(
        PharmacyHours.manualOpen({
          'hours': {'_manualOpen': true},
        }),
        isTrue,
      );
    });
  });
}
