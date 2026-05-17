import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/delivery_models.dart';
import '../../core/network/dio_error_mapper.dart';
import '../repositories_providers.dart';

final myShipmentsProvider =
    FutureProvider.autoDispose<List<ShipmentOrderDto>>((ref) async {
  final r = ref.watch(shipmentRepositoryProvider);
  final page = await r.getMyShipments(size: 50);
  return page.content;
});

class ShipmentsListScreen extends ConsumerWidget {
  const ShipmentsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myShipmentsProvider);

    return SafeArea(
      child: async.when(
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Text(
                'No orders yet. Create one from the dashboard.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(myShipmentsProvider);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final s = list[i];
                return ListTile(
                  title: Text(
                    '${s.originCity} → ${s.destinationCity}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text('${s.status} · ${s.description}', maxLines: 2),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/shipment/${s.primaryId}'),
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
