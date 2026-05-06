import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/delivery_models.dart';
import '../../core/network/dio_error_mapper.dart';
import '../repositories_providers.dart';

class ShipmentCarriersScreen extends ConsumerWidget {
  const ShipmentCarriersScreen({super.key, required this.shipmentId});

  final String shipmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_carriersProvider(shipmentId));

    return Scaffold(
      appBar: AppBar(title: const Text('Matchable carriers')),
      body: async.when(
        data: (carriers) {
          if (carriers.isEmpty) {
            return const Center(child: Text('No carriers found'));
          }
          return ListView.builder(
            itemCount: carriers.length,
            itemBuilder: (_, i) {
              final c = carriers[i];
              return ListTile(
                title: Text(c.carrierName),
                subtitle: Text(
                  '${c.fromCity} → ${c.toCity} · ${c.agreedFee} ${c.currency}',
                ),
                trailing: const Text('Match'),
                onTap: () async {
                  final matchRepo = ref.read(matchRepositoryProvider);
                  final res = await matchRepo.createMatch(
                    shipmentId: shipmentId,
                    tripId: c.tripId,
                  );
                  if (!context.mounted) return;
                  if (res.success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(res.message)),
                    );
                    context.pop();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(res.message)),
                    );
                  }
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(dioErrorMessage(e))),
      ),
    );
  }
}

final _carriersProvider = FutureProvider.family
    .autoDispose<List<MatchableCarrierDto>, String>((ref, shipmentId) async {
  final r = ref.watch(shipmentRepositoryProvider);
  return r.getMatchableCarriers(shipmentId);
});
