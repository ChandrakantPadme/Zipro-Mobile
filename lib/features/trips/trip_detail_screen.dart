import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/models/delivery_models.dart';
import '../../core/network/dio_error_mapper.dart';
import '../../core/theme/app_theme.dart';
import '../../data/supported_cities.dart';
import '../auth/presentation/auth_providers.dart';
import '../kyc/widgets/kyc_required_dialog.dart';
import '../repositories_providers.dart';
import '../shipments/widgets/shipment_request_review_sheet.dart';
import 'trips_list_screen.dart';

final tripProvider =
    FutureProvider.family.autoDispose<TripDto?, String>((ref, tripId) async {
  return ref.watch(tripRepositoryProvider).getTrip(tripId);
});

final tripOffersProvider = FutureProvider.family
    .autoDispose<List<TripOfferDto>, String>((ref, tripId) async {
  return ref.watch(tripOfferRepositoryProvider).offersForTrip(tripId);
});

/// Matches for this trip when the signed-in user owns it.
///
/// Watches [tripProvider] and [authNotifierProvider] so we refetch after trip/auth
/// resolve. Avoids empty matches when ownership was first computed inside nested
/// `asyncTrip.when(data:)` (Riverpod subscription timing).
final tripMatchesForTripProvider =
    FutureProvider.family.autoDispose<List<MatchDto>, String>((ref, tripId) async {
  ref.watch(authNotifierProvider);
  final userId = ref.read(authNotifierProvider).user?.userId;

  final TripDto? trip;
  try {
    trip = await ref.watch(tripProvider(tripId).future);
  } catch (_) {
    return const [];
  }
  if (trip == null) return const [];

  final travelerId = trip.travelerUserId?.trim();
  final isOwner = userId != null &&
      travelerId != null &&
      travelerId.isNotEmpty &&
      travelerId == userId;
  if (!isOwner) return const [];

  return ref.read(matchRepositoryProvider).getMatchesForTrip(tripId);
});

final ordersByTripProvider = FutureProvider.family
    .autoDispose<List<ShipmentOrderDto>, String>((ref, tripId) {
  return ref.watch(orderRepositoryProvider).getOrdersByTrip(tripId);
});

class _OrdersOnRouteParams {
  const _OrdersOnRouteParams({
    required this.tripId,
    required this.fromCity,
    required this.fromCountryCode,
    required this.toCity,
    required this.toCountryCode,
  });

  final String tripId;
  final String fromCity;
  final String fromCountryCode;
  final String toCity;
  final String toCountryCode;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _OrdersOnRouteParams &&
        other.tripId == tripId &&
        other.fromCity == fromCity &&
        other.fromCountryCode == fromCountryCode &&
        other.toCity == toCity &&
        other.toCountryCode == toCountryCode;
  }

  @override
  int get hashCode => Object.hash(
        tripId,
        fromCity,
        fromCountryCode,
        toCity,
        toCountryCode,
      );
}

final _ordersOnRouteProvider = FutureProvider.family
    .autoDispose<List<ShipmentOrderDto>, _OrdersOnRouteParams>((ref, p) async {
  final repo = ref.watch(shipmentRepositoryProvider);
  final useCity = p.fromCity.trim().isNotEmpty && p.toCity.trim().isNotEmpty;
  if (useCity) {
    final r = await repo.searchShipmentsByCities(
      originCity: p.fromCity,
      destinationCity: p.toCity,
      page: 0,
      size: 20,
    );
    return r.content;
  }
  if (p.fromCountryCode.isEmpty || p.toCountryCode.isEmpty) {
    return const [];
  }
  final r = await repo.searchShipments(
    originCountryCode: p.fromCountryCode,
    destinationCountryCode: p.toCountryCode,
    page: 0,
    size: 20,
  );
  return r.content;
});

class TripDetailScreen extends ConsumerStatefulWidget {
  const TripDetailScreen({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends ConsumerState<TripDetailScreen> {
  bool _starting = false;
  String? _busyMatchId;
  String? _busyShipmentId;
  String? _busyOrderId;

  Future<void> _runWithSnack(
    Future<void> Function() action, {
    String? kycActionLabel,
  }) async {
    try {
      await action();
    } catch (e) {
      if (!mounted) return;
      if (kycActionLabel != null && isKycRequiredError(e)) {
        await showKycRequiredDialog(context, actionLabel: kycActionLabel);
        return;
      }
      final msg = e is DioException ? dioErrorMessage(e) : '$e';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  void _invalidateTripMatchesListeners() {
    ref.invalidate(tripMatchesForTripProvider(widget.tripId));
  }

  Future<void> _startTrip() async {
    if (_starting) return;
    setState(() => _starting = true);
    await _runWithSnack(() async {
      final res =
          await ref.read(tripRepositoryProvider).startTrip(widget.tripId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message.isNotEmpty ? res.message : 'OK')),
      );
      ref.invalidate(tripProvider(widget.tripId));
      ref.invalidate(myTripsProvider);
      ref.invalidate(myPlannedTripsProvider);
      _invalidateTripMatchesListeners();
    });
    if (!mounted) return;
    setState(() => _starting = false);
  }

  Future<void> _acceptMatch(String matchId) async {
    if (_busyMatchId != null) return;
    setState(() => _busyMatchId = matchId);
    await _runWithSnack(
      () async {
        final res =
            await ref.read(matchRepositoryProvider).acceptMatch(matchId);
        if (!mounted) return;
        if (res.message.isNotEmpty) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(res.message)));
        }
        _invalidateTripMatchesListeners();
        ref.invalidate(ordersByTripProvider(widget.tripId));
      },
      kycActionLabel: 'accept an order request',
    );
    if (!mounted) return;
    setState(() => _busyMatchId = null);
  }

  Future<void> _rejectMatch(String matchId) async {
    if (_busyMatchId != null) return;
    setState(() => _busyMatchId = matchId);
    await _runWithSnack(
      () async {
        final res =
            await ref.read(matchRepositoryProvider).rejectMatch(matchId);
        if (!mounted) return;
        if (res.message.isNotEmpty) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(res.message)));
        }
        _invalidateTripMatchesListeners();
      },
      kycActionLabel: 'reject an order request',
    );
    if (!mounted) return;
    setState(() => _busyMatchId = null);
  }

  Future<void> _acceptShipmentOnRoute(String shipmentId) async {
    if (_busyShipmentId != null) return;
    setState(() => _busyShipmentId = shipmentId);
    await _runWithSnack(
      () async {
        final res =
            await ref.read(tripRepositoryProvider).acceptShipmentForTrip(
                  tripId: widget.tripId,
                  shipmentId: shipmentId,
                );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.success
                ? (res.message.isNotEmpty ? res.message : 'Order accepted')
                : (res.message.isNotEmpty ? res.message : 'Failed to accept')),
          ),
        );
        _invalidateTripMatchesListeners();
        ref.invalidate(ordersByTripProvider(widget.tripId));
        _invalidateOrdersOnRoute();
      },
      kycActionLabel: 'accept an order',
    );
    if (!mounted) return;
    setState(() => _busyShipmentId = null);
  }

  Future<void> _markInTransit(String orderId) async {
    if (_busyOrderId != null) return;
    setState(() => _busyOrderId = orderId);
    await _runWithSnack(() async {
      final res =
          await ref.read(orderRepositoryProvider).markInTransit(orderId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                res.message.isNotEmpty ? res.message : 'Marked in transit')),
      );
      ref.invalidate(ordersByTripProvider(widget.tripId));
    });
    if (!mounted) return;
    setState(() => _busyOrderId = null);
  }

  void _invalidateOrdersOnRoute() {
    final trip = ref.read(tripProvider(widget.tripId)).asData?.value;
    if (trip == null) return;
    ref.invalidate(_ordersOnRouteProvider(_OrdersOnRouteParams(
      tripId: widget.tripId,
      fromCity: trip.fromCity,
      fromCountryCode: trip.fromCountryCode,
      toCity: trip.toCity,
      toCountryCode: trip.toCountryCode,
    )));
  }

  @override
  Widget build(BuildContext context) {
    final asyncTrip = ref.watch(tripProvider(widget.tripId));
    final userId = ref.watch(authNotifierProvider).user?.userId;
    final asyncMatchesForTrip =
        ref.watch(tripMatchesForTripProvider(widget.tripId));

    return Scaffold(
      appBar: AppBar(title: const Text('Trip')),
      body: asyncTrip.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(dioErrorMessage(e)),
        )),
        data: (trip) {
          if (trip == null) {
            return const _NotFoundView(message: 'Trip not found');
          }
          final travelerId = trip.travelerUserId?.trim();
          final isOwner = userId != null &&
              travelerId != null &&
              travelerId.isNotEmpty &&
              travelerId == userId;
          final matches =
              asyncMatchesForTrip.asData?.value ?? const <MatchDto>[];
          final matchesLoading =
              isOwner && asyncMatchesForTrip.isLoading;
          final asyncOrders = ref.watch(ordersByTripProvider(widget.tripId));
          final ordersByTrip =
              asyncOrders.asData?.value ?? const <ShipmentOrderDto>[];

          final orderByShipment = <String, ShipmentOrderDto>{};
          for (final o in ordersByTrip) {
            final sid = o.shipmentId;
            if (sid != null && sid.isNotEmpty) {
              orderByShipment[sid] = o;
            }
          }

          final allOrdersPaid = ordersByTrip.isEmpty ||
              ordersByTrip.every(
                (o) => const {
                  'CONFIRMED',
                  'IN_PROGRESS',
                  'DELIVERED',
                }.contains(o.status),
              );

          final showOrdersOnRoute = isOwner && trip.status == 'PLANNED';
          final ordersOnRouteAsync = showOrdersOnRoute
              ? ref.watch(_ordersOnRouteProvider(_OrdersOnRouteParams(
                  tripId: widget.tripId,
                  fromCity: trip.fromCity,
                  fromCountryCode: trip.fromCountryCode,
                  toCity: trip.toCity,
                  toCountryCode: trip.toCountryCode,
                )))
              : null;
          final ordersOnRouteRaw =
              ordersOnRouteAsync?.asData?.value ?? const <ShipmentOrderDto>[];
          final matchedShipmentIds = <String>{
            for (final m in matches)
              if ((m.shipmentId ?? '').isNotEmpty) m.shipmentId!,
          };
          final ordersOnRoute = ordersOnRouteRaw
              .where((s) => !matchedShipmentIds.contains(s.primaryId))
              .toList();
          final ordersOnRouteLoading = ordersOnRouteAsync?.isLoading ?? false;

          final canStartTrip = trip.status == 'PLANNED' &&
              matches.isNotEmpty &&
              allOrdersPaid &&
              !_starting;
          final startTripDisabledReason =
              trip.status == 'PLANNED' && matches.isNotEmpty && !allOrdersPaid
                  ? 'Complete payment for all orders before starting the trip'
                  : null;
          final showStartTrip =
              isOwner && trip.status == 'PLANNED' && matches.isNotEmpty;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(tripProvider(widget.tripId));
              _invalidateTripMatchesListeners();
              ref.invalidate(ordersByTripProvider(widget.tripId));
              _invalidateOrdersOnRoute();
            },
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _TripHeroCard(
                  trip: trip,
                  showStartTrip: showStartTrip,
                  canStartTrip: canStartTrip,
                  starting: _starting,
                  startDisabledReason: startTripDisabledReason,
                  onStart: _startTrip,
                ),
                const SizedBox(height: 16),
                _TripMetaGrid(trip: trip, isOwner: isOwner),
                if (isOwner) ...[
                  if (matchesLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: LinearProgressIndicator(),
                    ),
                  if (isOwner &&
                      asyncMatchesForTrip.hasError &&
                      !matchesLoading)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        asyncMatchesForTrip.error is DioException
                            ? dioErrorMessage(
                                asyncMatchesForTrip.error! as DioException,
                              )
                            : '${asyncMatchesForTrip.error}',
                        style: TextStyle(
                          color: AppColors.destructive,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  if (!matchesLoading && matches.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const _SectionHeader(
                      icon: Icons.handshake_outlined,
                      title: 'Matches for this trip',
                      subtitle: 'Parcels matched to your trip.',
                    ),
                    const SizedBox(height: 12),
                    ...matches.map((m) {
                      final matchOrder = m.shipmentId != null
                          ? orderByShipment[m.shipmentId!]
                          : null;
                      final matchOrderId = matchOrder?.orderId;
                      return _MatchCard(
                        match: m,
                        order: matchOrder,
                        busy: _busyMatchId == m.matchId ||
                            (matchOrderId != null &&
                                _busyOrderId == matchOrderId),
                        onAccept: () => _acceptMatch(m.matchId),
                        onReject: () => _rejectMatch(m.matchId),
                        onMarkInTransit: (oid) => _markInTransit(oid),
                        onViewShipment: () {
                          final sid = m.shipmentId;
                          if (sid == null || sid.isEmpty) return;
                          showShipmentRequestReviewSheet(
                            context,
                            shipmentId: sid,
                            trip: trip,
                          );
                        },
                      );
                    }),
                  ],
                  if (showOrdersOnRoute) ...[
                    const SizedBox(height: 24),
                    const _SectionHeader(
                      icon: Icons.local_shipping_outlined,
                      title: 'Orders on your route',
                      subtitle:
                          'Live orders matching your trip. Accept one to carry it.',
                    ),
                    const SizedBox(height: 12),
                    if (ordersOnRouteLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (ordersOnRouteAsync?.hasError == true)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          ordersOnRouteAsync!.error is DioException
                              ? dioErrorMessage(
                                  ordersOnRouteAsync.error! as DioException,
                                )
                              : '${ordersOnRouteAsync.error}',
                          style: TextStyle(
                            color: AppColors.destructive,
                            fontSize: 14,
                          ),
                        ),
                      )
                    else if (ordersOnRoute.isEmpty)
                      _EmptyOnRouteCard(trip: trip)
                    else
                      for (final s in ordersOnRoute)
                        _OnRouteShipmentCard(
                          shipment: s,
                          busy: _busyShipmentId == s.primaryId,
                          onAccept: () => _acceptShipmentOnRoute(s.primaryId),
                        ),
                  ],
                ],
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TripHeroCard extends StatelessWidget {
  const _TripHeroCard({
    required this.trip,
    required this.showStartTrip,
    required this.canStartTrip,
    required this.starting,
    required this.startDisabledReason,
    required this.onStart,
  });

  final TripDto trip;
  final bool showStartTrip;
  final bool canStartTrip;
  final bool starting;
  final String? startDisabledReason;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final route = '${cityCountryLabel(trip.fromCity, trip.fromCountryCode)} → '
        '${cityCountryLabel(trip.toCity, trip.toCountryCode)}';
    final lastTwelve = trip.tripId.length > 12
        ? trip.tripId.substring(trip.tripId.length - 12)
        : trip.tripId;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.foreground.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 480;
            final left = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.flight, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        route,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _StatusChip(status: trip.status),
                      const SizedBox(height: 6),
                      Text(
                        'Trip ID: $lastTwelve',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
            final cta = showStartTrip
                ? Tooltip(
                    message: startDisabledReason ?? '',
                    triggerMode: startDisabledReason != null
                        ? TooltipTriggerMode.tap
                        : TooltipTriggerMode.manual,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.accentForeground,
                      ),
                      onPressed: canStartTrip ? onStart : null,
                      icon: starting
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.accentForeground,
                              ),
                            )
                          : const Icon(Icons.play_arrow, size: 18),
                      label: const Text('Start trip'),
                    ),
                  )
                : null;
            if (!wide || cta == null) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  left,
                  if (cta != null) ...[
                    const SizedBox(height: 12),
                    cta,
                  ],
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: left),
                const SizedBox(width: 12),
                cta,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TripMetaGrid extends StatelessWidget {
  const _TripMetaGrid({required this.trip, required this.isOwner});

  final TripDto trip;
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[];
    final depart = DateTime.tryParse(trip.departAt);
    if (depart != null) {
      tiles.add(_MetaTile(
        icon: Icons.calendar_today_outlined,
        label: 'Travel date',
        value: DateFormat.yMMMd().format(depart.toLocal()),
        accent: false,
      ));
    }
    final arrive =
        trip.arriveAt != null ? DateTime.tryParse(trip.arriveAt!) : null;
    if (arrive != null) {
      tiles.add(_MetaTile(
        icon: Icons.access_time_outlined,
        label: 'Return date',
        value: DateFormat.yMMMd().format(arrive.toLocal()),
        accent: true,
      ));
    }
    final flight = [
      if ((trip.airline ?? '').isNotEmpty) trip.airline!,
      if ((trip.flightNumber ?? '').isNotEmpty) trip.flightNumber!,
    ].join(' ');
    if (flight.isNotEmpty) {
      tiles.add(_MetaTile(
        icon: Icons.business_outlined,
        label: 'Flight',
        value: flight,
        accent: false,
      ));
    }
    if (trip.capacityWeightKg != null && trip.capacityValueLimit != null) {
      tiles.add(_CapacityTile(
        usedKg: (trip.usedWeightKg ?? 0).toDouble(),
        capKg: trip.capacityWeightKg!.toDouble(),
        usedValue: (trip.usedValue ?? 0).toDouble(),
        capValue: trip.capacityValueLimit!.toDouble(),
      ));
    }
    if (tiles.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 520;
        final cross = wide ? 2 : 1;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final t in tiles)
              SizedBox(
                width:
                    wide ? (c.maxWidth - 12 * (cross - 1)) / cross : c.maxWidth,
                child: t,
              ),
          ],
        );
      },
    );
  }
}

class _MetaTile extends StatelessWidget {
  const _MetaTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final iconBg =
        (accent ? AppColors.accent : AppColors.primary).withValues(alpha: 0.10);
    final iconColor = accent ? AppColors.accent : AppColors.primary;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CapacityTile extends StatelessWidget {
  const _CapacityTile({
    required this.usedKg,
    required this.capKg,
    required this.usedValue,
    required this.capValue,
  });

  final double usedKg;
  final double capKg;
  final double usedValue;
  final double capValue;

  @override
  Widget build(BuildContext context) {
    final wPct = capKg <= 0 ? 0.0 : (usedKg / capKg).clamp(0.0, 1.0);
    final vPct = capValue <= 0 ? 0.0 : (usedValue / capValue).clamp(0.0, 1.0);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Capacity',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _CapacityRow(
              label: 'Weight',
              used: '${_fmt(usedKg)} / ${_fmt(capKg)} kg',
              percent: wPct,
            ),
            const SizedBox(height: 8),
            _CapacityRow(
              label: 'Value',
              used: 'INR ${_fmt(usedValue)} / ${_fmt(capValue)}',
              percent: vPct,
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(double v) {
    if (v == v.truncateToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(2);
  }
}

class _CapacityRow extends StatelessWidget {
  const _CapacityRow({
    required this.label,
    required this.used,
    required this.percent,
  });

  final String label;
  final String used;
  final double percent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.mutedForeground,
              ),
            ),
            Text(
              used,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percent,
            minHeight: 6,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation(AppColors.primary),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({
    required this.match,
    required this.order,
    required this.busy,
    required this.onAccept,
    required this.onReject,
    required this.onMarkInTransit,
    required this.onViewShipment,
  });

  final MatchDto match;
  final ShipmentOrderDto? order;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final void Function(String orderId) onMarkInTransit;
  final VoidCallback onViewShipment;

  @override
  Widget build(BuildContext context) {
    final lastEight = match.matchId.length > 8
        ? match.matchId.substring(match.matchId.length - 8)
        : match.matchId;
    final isOrderPaid = order != null &&
        const {'CONFIRMED', 'IN_PROGRESS', 'DELIVERED'}.contains(order!.status);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _AccentLeftCard(
        accentColor: AppColors.accent,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined,
                      size: 18, color: AppColors.mutedForeground),
                  Text(
                    'Match $lastEight',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  _StatusChip(status: match.status),
                  if (match.status == 'OFFERED')
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'New request — review and accept or decline',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  Text(
                    'Fee: ${match.currency ?? 'INR'} ${match.agreedFee}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  if (match.weightKg != null)
                    Text(
                      '${match.weightKg} kg',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  if (match.declaredValueAmount != null)
                    Text(
                      '${match.declaredValueAmount} ${match.declaredValueCurrency ?? 'INR'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                ],
              ),
              if ((match.carrierOriginAddressText ?? '').isNotEmpty ||
                  (match.carrierDestinationAddressText ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                if ((match.carrierOriginAddressText ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      'Pickup: ${match.carrierOriginAddressText}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ),
                if ((match.carrierDestinationAddressText ?? '').isNotEmpty)
                  Text(
                    'Delivery: ${match.carrierDestinationAddressText}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.mutedForeground,
                    ),
                  ),
              ],
              const SizedBox(height: 12),
              if (match.status == 'OFFERED')
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if ((match.shipmentId ?? '').isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: onViewShipment,
                        icon:
                            const Icon(Icons.description_outlined, size: 16),
                        label: const Text('View order details'),
                      ),
                    if ((match.shipmentId ?? '').isNotEmpty)
                      const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: busy ? null : onAccept,
                            icon: const Icon(Icons.check_circle_outline,
                                size: 16),
                            label: const Text('Accept'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: busy ? null : onReject,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.destructive,
                              side: BorderSide(color: AppColors.destructive),
                            ),
                            icon: const Icon(Icons.cancel_outlined, size: 16),
                            label: const Text('Reject'),
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              else if (order == null)
                Text(
                  match.status == 'ACCEPTED'
                      ? 'Sender will make the payment for this match.'
                      : 'No order linked yet.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.mutedForeground,
                  ),
                )
              else ...[
                if (isOrderPaid) ...[
                  _OrderTrackingStepper(
                    status: order!.status,
                    milestone: order!.deliveryMilestone,
                  ),
                  const SizedBox(height: 12),
                ],
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => context.push('/order/${order!.orderId}'),
                      icon: const Icon(Icons.receipt_long_outlined, size: 16),
                      label: const Text('View order'),
                    ),
                    if (!isOrderPaid)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Sender will make the payment for this match.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      ),
                    if (isOrderPaid && order!.status == 'CONFIRMED')
                      OutlinedButton.icon(
                        onPressed: () =>
                            context.push('/order/${order!.orderId}'),
                        icon: const Icon(Icons.assignment_turned_in_outlined,
                            size: 16),
                        label: const Text('Product received'),
                      ),
                    if (isOrderPaid &&
                        order!.status == 'IN_PROGRESS' &&
                        order!.deliveryMilestone == 'PICKED_UP')
                      OutlinedButton.icon(
                        onPressed:
                            busy ? null : () => onMarkInTransit(order!.orderId),
                        icon:
                            const Icon(Icons.local_shipping_outlined, size: 16),
                        label: const Text('In transit'),
                      ),
                    if (isOrderPaid &&
                        order!.status == 'IN_PROGRESS' &&
                        (order!.deliveryMilestone == 'IN_TRANSIT' ||
                            order!.deliveryMilestone == 'PICKED_UP'))
                      FilledButton.icon(
                        onPressed: () =>
                            context.push('/order/${order!.orderId}'),
                        icon: const Icon(Icons.task_alt, size: 16),
                        label: const Text('Mark delivered'),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderTrackingStepper extends StatelessWidget {
  const _OrderTrackingStepper({required this.status, required this.milestone});

  final String status;
  final String? milestone;

  @override
  Widget build(BuildContext context) {
    final steps = const ['Confirmed', 'Picked up', 'In transit', 'Delivered'];
    int activeIndex = 0;
    if (status == 'CONFIRMED') {
      activeIndex = 0;
    } else if (status == 'IN_PROGRESS') {
      activeIndex =
          milestone == 'IN_TRANSIT' ? 2 : (milestone == 'DELIVERED' ? 3 : 1);
    } else if (status == 'DELIVERED') {
      activeIndex = 3;
    }
    return Row(
      children: [
        for (int i = 0; i < steps.length; i++) ...[
          _Dot(active: i <= activeIndex),
          if (i < steps.length - 1)
            Expanded(
              child: Container(
                height: 2,
                color: i < activeIndex ? AppColors.primary : AppColors.border,
              ),
            ),
        ],
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: active ? AppColors.primary : AppColors.border,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _OnRouteShipmentCard extends StatelessWidget {
  const _OnRouteShipmentCard({
    required this.shipment,
    required this.busy,
    required this.onAccept,
  });

  final ShipmentOrderDto shipment;
  final bool busy;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final route =
        '${cityCountryLabel(shipment.originCity, shipment.originCountryCode)} → '
        '${cityCountryLabel(shipment.destinationCity, shipment.destinationCountryCode)}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _AccentLeftCard(
        accentColor: AppColors.primary,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth >= 420;
              final left = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.place_outlined,
                          size: 16, color: AppColors.mutedForeground),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          route,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (shipment.description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      shipment.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      Text(
                        '${shipment.weightKg ?? '—'} kg',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                      if (shipment.declaredValueAmount != null)
                        Text(
                          '${shipment.currency ?? 'INR'} ${shipment.declaredValueAmount}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                    ],
                  ),
                ],
              );
              final cta = FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.accentForeground,
                ),
                onPressed: busy ? null : onAccept,
                child: busy
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.accentForeground,
                        ),
                      )
                    : const Text('Accept'),
              );
              if (!wide) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    left,
                    const SizedBox(height: 12),
                    cta,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: left),
                  const SizedBox(width: 12),
                  cta,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _EmptyOnRouteCard extends StatelessWidget {
  const _EmptyOnRouteCard({required this.trip});

  final TripDto trip;

  @override
  Widget build(BuildContext context) {
    final from = cityCountryLabel(trip.fromCity, trip.fromCountryCode);
    final to = cityCountryLabel(trip.toCity, trip.toCountryCode);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'No orders on this route right now. When someone posts an order from $from to $to, it will show up here.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: AppColors.mutedForeground,
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (status) {
      case 'PLANNED':
        bg = AppColors.primary.withValues(alpha: 0.12);
        fg = AppColors.primary;
        break;
      case 'IN_PROGRESS':
      case 'STARTED':
        bg = AppColors.accent.withValues(alpha: 0.18);
        fg = AppColors.accent;
        break;
      case 'COMPLETED':
      case 'DELIVERED':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF166534);
        break;
      case 'CANCELLED':
      case 'REJECTED':
        bg = AppColors.destructive.withValues(alpha: 0.12);
        fg = AppColors.destructive;
        break;
      case 'OFFERED':
        bg = AppColors.primary.withValues(alpha: 0.12);
        fg = AppColors.primary;
        break;
      case 'ACCEPTED':
      case 'MATCHED':
      case 'CONFIRMED':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF166534);
        break;
      default:
        bg = AppColors.secondary;
        fg = AppColors.mutedForeground;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// Rounded card with a thick coloured left accent bar — mirrors web's
/// `border-l-4 border-l-<colour>` rounded card. Implemented as a wrapper
/// because Flutter forbids `borderRadius` on a `Border` whose sides have
/// different colours, which silently turns the card into an empty
/// `ErrorWidget` and hides all its content.
class _AccentLeftCard extends StatelessWidget {
  const _AccentLeftCard({
    required this.accentColor,
    required this.child,
  });

  final Color accentColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 4,
            child: ColoredBox(color: accentColor),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _NotFoundView extends StatelessWidget {
  const _NotFoundView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flight, size: 56, color: AppColors.mutedForeground),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.mutedForeground,
                fontWeight: FontWeight.w500,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/my-trips');
                }
              },
              child: const Text('Back to trips'),
            ),
          ],
        ),
      ),
    );
  }
}
