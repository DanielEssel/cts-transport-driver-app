// Release v5: open Delivery and Gas requests come from delivery_offers /
// gas_order_offers (functions/order_offers.js), never from the order
// documents, which unassigned drivers can no longer read.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cts_transport_driver_app/features/driver/presentation/widgets/requests_section.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final created = Timestamp.fromDate(DateTime(2026, 10, 27, 9));

  test('a delivery offer gives areas, rounded points and the fare; no contacts', () {
    final r = AvailableRequest.fromDeliveryOffer({
      'schema': 1,
      'service': 'delivery',
      'pickupArea': 'Osu, Accra',
      'pickupPoint': const GeoPoint(5.56, -0.18),
      'dropoffArea': 'Adabraka, Accra',
      'dropoffPoint': const GeoPoint(5.6, -0.19),
      'fare': 30,
      'paymentMethod': 'cash',
      'parcelType': 'Documents',
      'weightTier': 'Small',
      'vehicleType': 'Okada',
      'createdAt': created,
    }, 'd1');
    expect(r.id, 'd1');
    expect(r.collection, 'deliveries');
    expect(r.pickupAddress, 'Osu, Accra');
    expect(r.dropoffLocation, const GeoPoint(5.6, -0.19));
    expect(r.fare, 30.0);
    expect(r.weightTier, 'Small');
    expect(r.bookedVehicle, 'Okada');
    expect(r.recipientName, isNull);
    expect(r.recipientPhone, isNull);
    expect(r.photoUrl, isNull);
    expect(r.passengerId, isEmpty);
    expect(r.createdAt, created.toDate());
  });

  test('a gas offer shows the verified order total as its fare', () {
    final r = AvailableRequest.fromGasOffer({
      'service': 'gas',
      'pickupArea': '',
      'pickupPoint': const GeoPoint(5.56, -0.18),
      'dropoffArea': '',
      'dropoffPoint': const GeoPoint(5.56, -0.18),
      'fare': 62,
      'totalPrice': 62,
      'deliveryFee': 12,
      'refillType': 'exchangeEmpty',
      'cylinderSize': 'kg3',
      'quantity': 2,
      'createdAt': created,
    }, 'g1');
    expect(r.collection, 'gas_orders');
    expect(r.fare, 62.0);
    expect(r.deliveryFee, 12.0);
    expect(r.cylinderQuantity, 2);
    expect(r.pickupAddress, 'Exact address after you accept');
    expect(acceptCallableFor(r.collection), ('acceptGasOrder', 'orderId'));
  });
}
