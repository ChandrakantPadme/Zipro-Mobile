import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:intl/intl.dart';

import '../../core/navigation/zipro_pop_or_home.dart';
import '../../core/models/delivery_models.dart';
import '../../core/network/dio_error_mapper.dart';
import '../../core/theme/app_theme.dart';
import '../../data/supported_cities.dart';
import '../repositories_providers.dart';

String _tripDateLabel(String iso) {
  if (iso.isEmpty) return '';
  try {
    return DateFormat('MMM dd, yyyy').format(DateTime.parse(iso).toLocal());
  } catch (_) {
    return iso;
  }
}

final availableTripsBrowseProvider =
    FutureProvider.autoDispose<List<TripDto>>((ref) async {
  final r = ref.watch(tripRepositoryProvider);
  final page = await r.getAvailableTrips(page: 0, size: 100);
  return page.content.where((t) => t.status == 'PLANNED').toList();
});

/// Parity with [zipro_website_new/app/(app)/trips/available/page.tsx].
///
/// When [showAppBar] is false, embed as a shell tab (shell provides the app bar).
class AvailableTripsScreen extends ConsumerWidget {
  const AvailableTripsScreen({
    super.key,
    this.showAppBar = true,
  });

  final bool showAppBar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(availableTripsBrowseProvider);

    final body = SafeArea(
      child: async.when(
        data: (trips) {
          if (trips.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: [
                Icon(Icons.flight, size: 56, color: AppColors.mutedForeground),
                const SizedBox(height: 16),
                Text(
                  'No active travellers yet',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.mutedForeground,
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Trips from travellers will show up here once they\'re available.',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(color: AppColors.mutedForeground, fontSize: 13),
                ),
              ],
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(availableTripsBrowseProvider);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: trips.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final t = trips[i];
                final route =
                    '${cityCountryLabel(t.fromCity, t.fromCountryCode)} → ${cityCountryLabel(t.toCity, t.toCountryCode)}';
                return Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => context.push('/trip/${t.tripId}'),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.place_outlined,
                                  size: 18, color: AppColors.mutedForeground),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  route,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Chip(
                                label: Text(t.status,
                                    style: const TextStyle(fontSize: 11)),
                                visualDensity: VisualDensity.compact,
                                side: BorderSide(color: AppColors.border),
                              ),
                              if (t.departAt.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Icon(Icons.calendar_today_outlined,
                                    size: 14, color: AppColors.mutedForeground),
                                const SizedBox(width: 4),
                                Text(
                                  _tripDateLabel(t.departAt),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.mutedForeground,
                                  ),
                                ),
                              ],
                            ],
                          ),
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

    return ZiproPopScope(
      child: Scaffold(
        appBar: AppBar(
          leading: ziproLeadingBackOrHome(context),
          title: const Text('Active travellers'),
        ),
        body: body,
      ),
    );
  }
}
