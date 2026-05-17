import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/delivery_models.dart';
import '../../core/network/dio_error_mapper.dart';
import '../repositories_providers.dart';

final myTripsProvider = FutureProvider.autoDispose<List<TripDto>>((ref) async {
  final r = ref.watch(tripRepositoryProvider);
  final p = await r.getMyTrips(size: 50);
  return p.content;
});

/// PLANNED only — same role as web `useTrips({ status: "PLANNED" })` on the shipment
/// detail page for resolving `matchingTrip` before Accept / Create trip.
final myPlannedTripsProvider =
    FutureProvider.autoDispose<List<TripDto>>((ref) async {
  final repo = ref.watch(tripRepositoryProvider);
  final page = await repo.getMyTrips(page: 0, size: 50, status: 'PLANNED');
  return page.content;
});

class TripsListScreen extends ConsumerWidget {
  const TripsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myTripsProvider);
    return SafeArea(
      child: async.when(
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('No trips yet'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myTripsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final t = list[i];
                return ListTile(
                  title: Text('${t.fromCity} → ${t.toCity}', maxLines: 1),
                  subtitle: Text('${t.status} · ${t.departAt}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/trip/${t.tripId}'),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(dioErrorMessage(e))),
      ),
    );
  }
}
