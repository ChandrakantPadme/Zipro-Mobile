import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/delivery_models.dart';
import '../../core/network/dio_error_mapper.dart';
import '../../core/theme/app_theme.dart';
import '../../data/supported_cities.dart';
import '../repositories_providers.dart';

final availableShipmentsBrowseProvider =
    FutureProvider.autoDispose<PaginatedShipmentPage>((ref) async {
  final r = ref.watch(shipmentRepositoryProvider);
  final page = await r.getAvailableShipments(page: 0, size: 50);
  return PaginatedShipmentPage(
    items: page.content,
    totalElements: page.totalElements,
    totalPages: page.totalPages,
  );
});

class PaginatedShipmentPage {
  const PaginatedShipmentPage({
    required this.items,
    required this.totalElements,
    required this.totalPages,
  });

  final List<ShipmentOrderDto> items;
  final int totalElements;
  final int totalPages;
}

/// Parity with [zipro_website_new/app/(app)/shipments/available/page.tsx].
///
/// When [showAppBar] is false, embed as a shell tab (shell provides the app bar).
class AvailableShipmentsScreen extends ConsumerWidget {
  const AvailableShipmentsScreen({
    super.key,
    this.showAppBar = true,
  });

  final bool showAppBar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(availableShipmentsBrowseProvider);

    final body = SafeArea(
      child: async.when(
        data: (data) {
          if (data.items.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: [
                Icon(Icons.inventory_2_outlined,
                    size: 56, color: AppColors.mutedForeground),
                const SizedBox(height: 16),
                Text(
                  'No live orders',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.mutedForeground,
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Parcel requests from others will appear here when posted.',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(color: AppColors.mutedForeground, fontSize: 13),
                ),
              ],
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(availableShipmentsBrowseProvider);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: data.items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final s = data.items[i];
                final origin =
                    cityCountryLabel(s.originCity, s.originCountryCode);
                final dest = cityCountryLabel(
                    s.destinationCity, s.destinationCountryCode);
                final route = '$origin → $dest';
                final fee = s.travelerFee?.toDouble();
                final curr = s.travelerFeeCurrency ?? s.currency ?? '';
                return Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => context.push('/shipment/${s.primaryId}'),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.secondary,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Icon(
                              Icons.inventory_2_outlined,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  route,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    Chip(
                                      label: Text(s.status,
                                          style: const TextStyle(fontSize: 11)),
                                      visualDensity: VisualDensity.compact,
                                      side: BorderSide(color: AppColors.border),
                                    ),
                                    if (fee != null && curr.isNotEmpty)
                                      Text(
                                        '$curr $fee',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.mutedForeground,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Text(
                            'View',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.accent,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.chevron_right,
                              color: AppColors.mutedForeground),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(dioErrorMessage(e))),
      ),
    );

    if (!showAppBar) {
      return body;
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Live orders'),
      ),
      body: body,
    );
  }
}
