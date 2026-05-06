import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth/presentation/auth_providers.dart';
import 'matches/data/match_repository.dart';
import 'orders/data/order_repository.dart';
import 'payments/data/payment_repository.dart';
import 'profile/data/contact_repository.dart';
import 'profile/data/trust_repository.dart';
import 'shipments/data/shipment_repository.dart';
import 'trips/data/trip_offer_repository.dart';
import 'trips/data/trip_repository.dart';

final shipmentRepositoryProvider = Provider<ShipmentRepository>((ref) {
  return ShipmentRepository(ref.watch(authNotifierProvider).dio);
});

final tripRepositoryProvider = Provider<TripRepository>((ref) {
  return TripRepository(ref.watch(authNotifierProvider).dio);
});

final tripOfferRepositoryProvider = Provider<TripOfferRepository>((ref) {
  return TripOfferRepository(ref.watch(authNotifierProvider).dio);
});

final matchRepositoryProvider = Provider<MatchRepository>((ref) {
  return MatchRepository(ref.watch(authNotifierProvider).dio);
});

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return OrderRepository(ref.watch(authNotifierProvider).dio);
});

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepository(ref.watch(authNotifierProvider).dio);
});

final trustRepositoryProvider = Provider<TrustRepository>((ref) {
  return TrustRepository(ref.watch(authNotifierProvider).dio);
});

final contactRepositoryProvider = Provider<ContactRepository>((ref) {
  return ContactRepository();
});