import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/models/delivery_models.dart';
import '../../core/models/pagination.dart';
import '../../core/theme/app_theme.dart';
import '../../data/supported_cities.dart';
import '../kyc/kyc_completion.dart';
import '../kyc/kyc_status_provider.dart';
import '../repositories_providers.dart';
import 'widgets/dashboard_cta_banner.dart';
import 'widgets/dashboard_preview_ribbon.dart';
import 'widgets/dashboard_stat_card.dart';

List<ShipmentOrderDto> _liveOrdersPreview(DashboardAggregate d) {
  return d.availableShipments.take(1).toList();
}

List<TripDto> _activeTripsPreview(DashboardAggregate d) {
  return d.availableTrips.take(1).toList();
}

String _tripDateLabel(String iso) {
  if (iso.isEmpty) return '';
  try {
    return DateFormat('MMM dd, yyyy').format(DateTime.parse(iso).toLocal());
  } catch (_) {
    return iso;
  }
}

class DashboardAggregate {
  DashboardAggregate({
    required this.myTrips,
    required this.buyerOrders,
    required this.travelerOrders,
    required this.availableShipments,
    required this.availableTrips,
  });

  final List<TripDto> myTrips;
  final List<ShipmentOrderDto> buyerOrders;
  final List<ShipmentOrderDto> travelerOrders;
  final List<ShipmentOrderDto> availableShipments;
  final List<TripDto> availableTrips;
}

final dashboardAggregateProvider =
    FutureProvider.autoDispose<DashboardAggregate>((ref) async {
  final tripRepo = ref.watch(tripRepositoryProvider);
  final orderRepo = ref.watch(orderRepositoryProvider);
  final shipmentRepo = ref.watch(shipmentRepositoryProvider);

  final results = await Future.wait([
    tripRepo.getMyTrips(size: 120),
    orderRepo.getMyOrdersBuyer(),
    orderRepo.getMyOrdersTraveler(),
    shipmentRepo.getAvailableShipments(page: 0, size: 50),
    tripRepo.getAvailableTrips(page: 0, size: 100),
  ]);

  final myTripsPage = results[0] as PaginatedResponse<TripDto>;
  final availableShipmentsPage =
      results[3] as PaginatedResponse<ShipmentOrderDto>;
  final availableTripsPage = results[4] as PaginatedResponse<TripDto>;

  return DashboardAggregate(
    myTrips: myTripsPage.content,
    buyerOrders: results[1] as List<ShipmentOrderDto>,
    travelerOrders: results[2] as List<ShipmentOrderDto>,
    availableShipments: availableShipmentsPage.content,
    availableTrips: availableTripsPage.content
        .where((t) => t.status == 'PLANNED')
        .toList(),
  );
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agg = ref.watch(dashboardAggregateProvider);
    final kycAsync = ref.watch(kycRecordProvider);

    // Bottom safe area is already handled by the shell's bottom navigation bar;
    // including it here added a visible gap above the nav.
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardAggregateProvider);
          ref.invalidate(kycRecordProvider);
        },
        child: agg.when(
          loading: () => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(height: 120),
              Center(child: CircularProgressIndicator()),
            ],
          ),
          error: (e, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [Text('$e')],
          ),
          data: (d) {
            final activeTrips = d.myTrips
                .where((t) => t.status == 'PLANNED' || t.status == 'ACTIVE')
                .length;
            final completedTrips =
                d.myTrips.where((t) => t.status == 'COMPLETED').length;
            final totalOrders = d.buyerOrders.length + d.travelerOrders.length;
            final earnings = d.travelerOrders
                .where((o) => o.status == 'DELIVERED')
                .fold<double>(
                  0,
                  (sum, o) => sum + ((o.subtotal ?? o.total)?.toDouble() ?? 0),
                );

            // CTAs sit directly under stats in the same scroll view so there is no
            // floating gap between the grid and actions.
            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Welcome back',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                fontSize: 24,
                                letterSpacing: -0.5,
                                color: AppColors.foreground,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Here's what's happening with your account today.",
                          style: TextStyle(color: AppColors.mutedForeground),
                        ),
                        const SizedBox(height: 16),
                        kycAsync.when(
                          data: (kyc) {
                            if (kyc == null || needsKycCompletion(kyc)) {
                              return Card(
                                color:
                                    AppColors.secondary.withValues(alpha: 0.35),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: AppColors.border),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      Icon(Icons.assignment_turned_in_outlined,
                                          color: AppColors.primary),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text('Complete your KYC',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.w600)),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Please complete identity verification to access all dashboard features (send parcels, list trips, and more).',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color:
                                                    AppColors.mutedForeground,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      FilledButton(
                                        onPressed: () => context.push('/kyc'),
                                        child: const Text('Complete KYC'),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                            if (kyc.status == 'SUBMITTED' ||
                                kyc.status == 'UNDER_REVIEW') {
                              return Card(
                                color:
                                    AppColors.primary.withValues(alpha: 0.06),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(Icons.verified_user_outlined,
                                          color: AppColors.primary),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                                'Verification Under Review',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.w600)),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Your KYC documents are being reviewed. Dashboard actions are disabled until verification is complete.',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color:
                                                    AppColors.mutedForeground,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Chip(
                                        label: const Text('Pending'),
                                        side: BorderSide(
                                          color: AppColors.primary
                                              .withValues(alpha: 0.25),
                                        ),
                                        backgroundColor: AppColors.primary
                                            .withValues(alpha: 0.08),
                                        labelStyle: TextStyle(
                                            color: AppColors.primary,
                                            fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                        const SizedBox(height: 12),
                        _DashboardStatsGrid(
                          totalOrders: totalOrders,
                          activeTrips: activeTrips,
                          completedTrips: completedTrips,
                          totalEarningsUsd: earnings,
                        ),
                        const SizedBox(height: 14),
                        DashboardCtaBanner(
                          backgroundColor: AppColors.primary,
                          arrowColor: AppColors.primary,
                          icon: Icons.inventory_2_outlined,
                          decorationIcon: Icons.inventory_2_outlined,
                          title: 'Create Order',
                          subtitle:
                              'Send or shop and deliver packages with ease.',
                          onTap: () => context.go('/shipments/create'),
                        ),
                        const SizedBox(height: 10),
                        DashboardCtaBanner(
                          backgroundColor: AppColors.accent,
                          arrowColor: AppColors.accent,
                          icon: Icons.flight_takeoff,
                          decorationIcon: Icons.flight,
                          title: 'Create Trip',
                          subtitle:
                              'Travel and earn by carrying packages on your trip.',
                          onTap: () => context.go('/trips/create'),
                        ),
                        const SizedBox(height: 10),
                        DashboardPreviewRibbon(
                          title: 'Live Orders',
                          onViewAll: () => context.go('/browse/orders'),
                          emptyMessage: 'No live orders right now',
                          items: [
                            for (final o in _liveOrdersPreview(d))
                              DashboardPreviewRow(
                                title: cityCountryLabel(
                                      o.originCity, o.originCountryCode) +
                                  ' → ' +
                                  cityCountryLabel(o.destinationCity,
                                      o.destinationCountryCode),
                                subtitle: o.description,
                                statusLabel: o.status,
                                onTap: () => context.push(
                                    '/shipment/${o.primaryId}'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        DashboardPreviewRibbon(
                          title: 'Active Trips',
                          onViewAll: () => context.go('/browse/trips'),
                          emptyMessage: 'No active trips right now',
                          items: [
                            for (final t in _activeTripsPreview(d))
                              DashboardPreviewRow(
                                title: cityCountryLabel(
                                        t.fromCity, t.fromCountryCode) +
                                    ' → ' +
                                    cityCountryLabel(
                                        t.toCity, t.toCountryCode),
                                subtitle: _tripDateLabel(t.departAt),
                                statusLabel: t.status,
                                onTap: () => context.push('/trip/${t.tripId}'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DashboardStatsGrid extends StatelessWidget {
  const _DashboardStatsGrid({
    required this.totalOrders,
    required this.activeTrips,
    required this.completedTrips,
    required this.totalEarningsUsd,
  });

  final int totalOrders;
  final int activeTrips;
  final int completedTrips;
  final double totalEarningsUsd;

  @override
  Widget build(BuildContext context) {
    final earningsFormatted = NumberFormat.currency(
      symbol: r'$',
      decimalDigits: 0,
    ).format(totalEarningsUsd);

    final cards = [
      (
        'Total Orders',
        '$totalOrders',
        Icons.inventory_2_outlined,
        AppColors.primary,
      ),
      (
        'Active Trips',
        '$activeTrips',
        Icons.schedule_outlined,
        AppColors.accent,
      ),
      (
        'Completed Trips',
        '$completedTrips',
        Icons.flight_takeoff,
        const Color(0xFF22C55E),
      ),
      (
        'Total Earnings',
        earningsFormatted,
        Icons.payments_outlined,
        const Color(0xFFEAB308),
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.6,
      children: [
        for (final c in cards)
          DashboardStatCard(
            label: c.$1,
            value: c.$2,
            icon: c.$3,
            accentColor: c.$4,
          ),
      ],
    );
  }
}
