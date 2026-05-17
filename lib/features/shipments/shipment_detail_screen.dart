import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/navigation/zipro_pop_or_home.dart';
import '../../core/models/delivery_models.dart';
import '../../core/network/dio_error_mapper.dart';
import '../../core/theme/app_theme.dart';
import '../../data/supported_cities.dart';
import '../auth/presentation/auth_providers.dart';
import '../kyc/widgets/kyc_required_dialog.dart';
import '../payments/widgets/payment_pending_banner.dart';
import '../repositories_providers.dart';
import '../trips/trips_list_screen.dart' show myPlannedTripsProvider;
import 'shipment_trip_match.dart';
import 'widgets/carrier_card.dart';

final shipmentDetailProvider = FutureProvider.family
    .autoDispose<ShipmentOrderDto?, String>((ref, id) async {
  final repo = ref.watch(shipmentRepositoryProvider);
  return repo.getShipment(id);
});

final matchableCarriersProvider = FutureProvider.family
    .autoDispose<List<MatchableCarrierDto>, String>((ref, shipmentId) async {
  final repo = ref.watch(shipmentRepositoryProvider);
  return repo.getMatchableCarriers(shipmentId);
});

final orderByShipmentProvider = FutureProvider.family
    .autoDispose<ShipmentOrderDto?, String>((ref, shipmentId) async {
  final repo = ref.watch(orderRepositoryProvider);
  return repo.getOrderByShipment(shipmentId);
});

final shipmentMatchesProvider = FutureProvider.family
    .autoDispose<List<MatchDto>, String>((ref, shipmentId) async {
  final repo = ref.watch(matchRepositoryProvider);
  return repo.getMatchesForShipment(shipmentId);
});

final paymentByOrderIdProvider = FutureProvider.family
    .autoDispose<PaymentDto?, String>((ref, orderId) async {
  if (orderId.isEmpty) return null;
  final repo = ref.watch(paymentRepositoryProvider);
  return repo.getPaymentByOrder(orderId);
});

bool _isMatchAccepted(MatchDto m) =>
    m.status == 'ACCEPTED' || m.status == 'MATCHED';

String _formatFee(num? v) {
  if (v == null) return '—';
  return NumberFormat('#0.00').format(v);
}

/// Readable reference: long ULIDs get `prefix…suffix` instead of harsh truncation.
String _compactMatchId(String id) {
  final t = id.trim();
  if (t.isEmpty) return '—';
  if (t.length <= 18) return t;
  return '${t.substring(0, 8)}…${t.substring(t.length - 8)}';
}

(Color, Color) _matchStatusColors(String status) {
  switch (status) {
    case 'PLANNED':
    case 'OFFERED':
      return (
        AppColors.primary.withValues(alpha: 0.12),
        AppColors.primary,
      );
    case 'ACCEPTED':
    case 'MATCHED':
    case 'CONFIRMED':
      return (const Color(0xFFDCFCE7), const Color(0xFF166534));
    case 'IN_PROGRESS':
    case 'STARTED':
      return (
        AppColors.accent.withValues(alpha: 0.18),
        AppColors.accent,
      );
    case 'COMPLETED':
    case 'DELIVERED':
      return (const Color(0xFFDCFCE7), const Color(0xFF166534));
    case 'CANCELLED':
    case 'REJECTED':
      return (
        AppColors.destructive.withValues(alpha: 0.12),
        AppColors.destructive,
      );
    default:
      return (AppColors.secondary, AppColors.mutedForeground);
  }
}

String _latestDeliveryLabel(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  final dt = DateTime.tryParse(iso);
  if (dt == null) return iso;
  return DateFormat.yMMMd().format(dt.toLocal());
}

bool _feeRowVisible(ShipmentOrderDto s) {
  return s.deliveryFee != null ||
      (s.weightFare != null && (s.weightFare ?? 0) >= 0) ||
      s.secureFee != null ||
      s.totalAmountToPay != null ||
      s.total != null ||
      s.travelerFee != null;
}

bool _hasRenderableAddresses(ShipmentAddressesDto? a) {
  if (a == null) return false;
  final origin = (a.originAddressText ?? '').trim();
  final dest = (a.destinationAddressText ?? '').trim();
  if (_addressPlaceholder(origin) && _addressPlaceholder(dest)) {
    return false;
  }
  return true;
}

Widget _feeLineRow(String label, num value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: AppColors.mutedForeground)),
        Text(_formatFee(value)),
      ],
    ),
  );
}

bool _addressPlaceholder(String? s) {
  if (s == null) return true;
  final t = s.trim();
  return t.isEmpty || t.toLowerCase() == 'to be provided';
}

class ShipmentDetailScreen extends ConsumerStatefulWidget {
  const ShipmentDetailScreen({
    super.key,
    required this.shipmentId,
    this.paymentPending = false,
  });

  final String shipmentId;
  final bool paymentPending;

  @override
  ConsumerState<ShipmentDetailScreen> createState() =>
      _ShipmentDetailScreenState();
}

class _ShipmentDetailScreenState extends ConsumerState<ShipmentDetailScreen> {
  bool _acceptLoading = false;
  String? _busyTripId;

  Future<void> _selectCarrier(String tripId) async {
    if (_busyTripId != null) return;
    setState(() => _busyTripId = tripId);
    final repo = ref.read(matchRepositoryProvider);
    try {
      final res = await repo.createMatch(
        shipmentId: widget.shipmentId,
        tripId: tripId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res.message.isNotEmpty ? res.message : 'Request sent to carrier',
          ),
        ),
      );
      if (res.success) {
        ref.invalidate(shipmentMatchesProvider(widget.shipmentId));
        ref.invalidate(shipmentDetailProvider(widget.shipmentId));
        ref.invalidate(matchableCarriersProvider(widget.shipmentId));
      }
    } catch (e) {
      if (!mounted) return;
      if (isKycRequiredError(e)) {
        await showKycRequiredDialog(context, actionLabel: 'choose a traveller');
        return;
      }
      final msg = e is DioException ? dioErrorMessage(e) : '$e';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _busyTripId = null);
    }
  }

  Future<void> _onAcceptOrder({
    required ShipmentOrderDto shipment,
    required TripDto? matchingTrip,
  }) async {
    if (matchingTrip == null) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Create a trip to accept this order'),
          content: Text(
            'You don\'t have a trip for this route yet. Create a trip from '
            '${cityCountryLabel(shipment.originCity, shipment.originCountryCode)} '
            'to ${cityCountryLabel(shipment.destinationCity, shipment.destinationCountryCode)} '
            'to accept this order.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.accentForeground,
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                final loc = Uri(
                  path: '/trips/create',
                  queryParameters: {
                    'fromCity': shipment.originCity,
                    'fromCountryCode': shipment.originCountryCode,
                    'toCity': shipment.destinationCity,
                    'toCountryCode': shipment.destinationCountryCode,
                    'forShipment': widget.shipmentId,
                  },
                ).toString();
                context.push(loc);
              },
              child: const Text('Create trip'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _acceptLoading = true);
    final repo = ref.read(tripRepositoryProvider);
    try {
      final res = await repo.acceptShipmentForTrip(
        tripId: matchingTrip.tripId,
        shipmentId: widget.shipmentId,
      );
      if (!mounted) return;
      setState(() => _acceptLoading = false);
      if (!res.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(res.message.isNotEmpty ? res.message : 'Failed')),
        );
        return;
      }
      ref.invalidate(shipmentDetailProvider(widget.shipmentId));
      ref.invalidate(shipmentMatchesProvider(widget.shipmentId));
      ref.invalidate(myPlannedTripsProvider);
      ref.invalidate(orderByShipmentProvider(widget.shipmentId));
      if (!context.mounted) return;
      context.push('/trip/${matchingTrip.tripId}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _acceptLoading = false);
      if (isKycRequiredError(e)) {
        await showKycRequiredDialog(context, actionLabel: 'accept an order');
        return;
      }
      final msg = e is DioException ? dioErrorMessage(e) : '$e';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncShipment = ref.watch(shipmentDetailProvider(widget.shipmentId));
    final asyncMatches = ref.watch(shipmentMatchesProvider(widget.shipmentId));
    final asyncTrips = ref.watch(myPlannedTripsProvider);
    final asyncOrder = ref.watch(orderByShipmentProvider(widget.shipmentId));
    final userId = ref.watch(authNotifierProvider).user?.userId;

    return ZiproPopScope(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Order'),
          leading: ziproLeadingBackOrHome(context),
        ),
        body: asyncShipment.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _NotFoundView(message: dioErrorMessage(e)),
        data: (s) {
          if (s == null) {
            return const _NotFoundView(message: 'Order not found');
          }
          // Matches API is sender-only on the backend; mirror web behaviour and
          // silently fall back to an empty list when the call errors so the
          // page still renders for travellers viewing a live order.
          final matches = asyncMatches.asData?.value ?? const <MatchDto>[];
          MatchDto? acceptedMatch;
          for (final m in matches) {
            if (_isMatchAccepted(m)) {
              acceptedMatch = m;
              break;
            }
          }
          final hasAcceptedMatch = acceptedMatch != null;
          MatchDto? offeredMatch;
          for (final m in matches) {
            if (m.status == 'OFFERED') {
              offeredMatch = m;
              break;
            }
          }
          final hasAnyMatch = matches.isNotEmpty;
          final isPosted = s.status == 'POSTED';
          final isSender = s.senderUserId != null &&
              s.senderUserId!.isNotEmpty &&
              userId != null &&
              s.senderUserId == userId;
          final isMatchedTraveller = acceptedMatch != null &&
              userId != null &&
              acceptedMatch.travelerUserId == userId;

          final orderIdForPayment =
              hasAcceptedMatch && asyncOrder.asData?.value != null
                  ? asyncOrder.asData!.value!.orderId
                  : '';
          final payAsync =
              ref.watch(paymentByOrderIdProvider(orderIdForPayment));
          final paymentSuccess = payAsync.asData?.value?.status == 'SUCCESS';
          final showReceiverContact =
              isSender || (isMatchedTraveller && paymentSuccess);

          final trips = asyncTrips.asData?.value;
          final tripsLoading = asyncTrips.isLoading;
          final matchingTrip =
              trips != null ? findFirstMatchingPlannedTrip(s, trips) : null;
          final showAcceptOrder =
              isPosted && !isSender && userId != null && !hasAcceptedMatch;

          final headerRoute = s.shipmentType == 'DUTY_FREE_SHOPPING'
              ? cityCountryLabel(
                  s.destinationCity,
                  s.destinationCountryCode,
                )
              : '${cityCountryLabel(s.originCity, s.originCountryCode)} → '
                  '${cityCountryLabel(s.destinationCity, s.destinationCountryCode)}';
          final orderIdDisplay = s.shipmentId ?? s.orderId;
          final feeCurrency = s.travelerFeeCurrency ?? s.currency ?? '';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.paymentPending && orderIdForPayment.isNotEmpty) ...[
                  PaymentPendingBanner(
                    orderId: orderIdForPayment,
                    invalidateOnSuccess: () {
                      ref.invalidate(shipmentDetailProvider(widget.shipmentId));
                      ref.invalidate(
                          orderByShipmentProvider(widget.shipmentId));
                    },
                  ),
                  const SizedBox(height: 16),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.place_outlined,
                        size: 20, color: AppColors.mutedForeground),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            headerRoute,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Chip(
                                label: Text(
                                  s.status,
                                  style: const TextStyle(fontSize: 11),
                                ),
                                visualDensity: VisualDensity.compact,
                                side: BorderSide(color: AppColors.border),
                              ),
                              if (s.shipmentType == 'DUTY_FREE_SHOPPING')
                                Chip(
                                  label: const Text(
                                    'DUTY FREE SHOPPING',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  side: BorderSide.none,
                                  backgroundColor:
                                      AppColors.accent.withValues(alpha: 0.2),
                                  labelStyle: TextStyle(
                                    color: AppColors.foreground,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Order #$orderIdDisplay',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.foreground.withValues(alpha: 0.68),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (showAcceptOrder) ...[
                      const SizedBox(width: 8),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: AppColors.accentForeground,
                        ),
                        onPressed: (_acceptLoading || tripsLoading)
                            ? null
                            : () => _onAcceptOrder(
                                  shipment: s,
                                  matchingTrip: matchingTrip,
                                ),
                        child: _acceptLoading || tripsLoading
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.accentForeground,
                                ),
                              )
                            : const Text('Accept order'),
                      ),
                    ],
                  ],
                ),
                if (isPosted &&
                    offeredMatch != null &&
                    acceptedMatch == null &&
                    isSender)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'Waiting for traveller to accept.',
                      style: TextStyle(
                        color: AppColors.mutedForeground,
                        fontSize: 13,
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                Text(
                  'Parcel',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                    color: AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 12),
                _ParcelInfoGrid(
                  shipment: s,
                  showReceiverContact: showReceiverContact,
                  isMatchedTraveller: isMatchedTraveller,
                  onOpenLink: (url) async {
                    final uri = Uri.tryParse(url);
                    if (uri != null && await canLaunchUrl(uri)) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
                ),
                if (_feeRowVisible(s)) ...[
                  const SizedBox(height: 24),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.secondary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          if (isSender) ...[
                            if (s.deliveryFee != null)
                              _feeLineRow('Delivery', s.deliveryFee!),
                            if (s.weightFare != null && s.weightFare! >= 0)
                              _feeLineRow('Weight fare', s.weightFare!),
                            if (s.secureFee != null)
                              _feeLineRow(
                                'Parcel Protection Fee',
                                s.secureFee!,
                              ),
                          ],
                          if (s.totalAmountToPay != null ||
                              s.total != null ||
                              (isSender == false && s.travelerFee != null))
                            Padding(
                              padding: EdgeInsets.only(
                                top: isSender ? 12 : 0,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Total',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    isSender
                                        ? '$feeCurrency ${_formatFee(s.totalAmountToPay ?? s.total)}'
                                        : '$feeCurrency ${_formatFee(s.travelerFee)}',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (_hasRenderableAddresses(s.addresses)) ...[
                  const SizedBox(height: 24),
                  _AddressSection(addresses: s.addresses!),
                ],
                if (hasAnyMatch && s.status != 'DELIVERED') ...[
                  const SizedBox(height: 24),
                  Text(
                    'Current match',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 10),
                  ...matches.map(
                    (m) => _ShipmentMatchCard(
                      match: m,
                      isPosted: isPosted,
                      acceptedMatch: acceptedMatch,
                    ),
                  ),
                ],
                if (isPosted && !hasAnyMatch && isSender) ...[
                  const SizedBox(height: 24),
                  _CarriersInlineSection(
                    shipmentId: widget.shipmentId,
                    shipment: s,
                    busyTripId: _busyTripId,
                    onSelect: _selectCarrier,
                  ),
                ],
                const SizedBox(height: 24),
                asyncOrder.when(
                  data: (order) {
                    if (order == null) {
                      return const SizedBox.shrink();
                    }
                    final payStates = {
                      'AWAITING_PAYMENT',
                      'PAYMENT_PENDING',
                      'CREATED',
                    };
                    if (payStates.contains(order.status)) {
                      return FilledButton(
                        onPressed: () =>
                            context.push('/order/${order.orderId}/pay'),
                        child: const Text('Pay'),
                      );
                    }
                    return TextButton(
                      onPressed: () => context.push('/order/${order.orderId}'),
                      child: const Text('Open order'),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
  }
}

class _ShipmentMatchCard extends StatelessWidget {
  const _ShipmentMatchCard({
    required this.match,
    required this.isPosted,
    required this.acceptedMatch,
  });

  final MatchDto match;
  final bool isPosted;
  final MatchDto? acceptedMatch;

  @override
  Widget build(BuildContext context) {
    final tripId = match.tripId;
    final (statusBg, statusFg) = _matchStatusColors(match.status);
    final hasHandover = (match.carrierOriginAddressText ?? '')
            .trim()
            .isNotEmpty ||
        (match.carrierDestinationAddressText ?? '').trim().isNotEmpty;
    final hasTripLink = tripId != null && tripId.isNotEmpty;
    final hasTopContent = hasTripLink || hasHandover;

    final bodyChildren = <Widget>[
      if (hasTripLink)
        TextButton.icon(
          style: TextButton.styleFrom(
            alignment: Alignment.centerLeft,
            padding: EdgeInsets.zero,
            foregroundColor: AppColors.primary,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: () => context.push('/trip/$tripId'),
          icon: const Icon(Icons.flight_outlined, size: 18),
          label: const Text('View carrier trip'),
        ),
      if (hasHandover) ...[
        if (hasTripLink) const SizedBox(height: 8),
        Text(
          'Handover',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: AppColors.mutedForeground,
          ),
        ),
        const SizedBox(height: 4),
        if ((match.carrierOriginAddressText ?? '').trim().isNotEmpty)
          Text(
            'Pickup: ${match.carrierOriginAddressText}',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.mutedForeground,
              height: 1.35,
            ),
          ),
        if ((match.carrierDestinationAddressText ?? '').trim().isNotEmpty)
          Text(
            'Drop-off: ${match.carrierDestinationAddressText}',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.mutedForeground,
              height: 1.35,
            ),
          ),
      ],
      if (match.status == 'OFFERED')
        Padding(
          padding: EdgeInsets.only(top: hasTopContent ? 10 : 0),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.schedule_outlined,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Request sent. Waiting for the carrier to accept.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: AppColors.foreground.withValues(alpha: 0.88),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.foreground.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  border: Border(
                    bottom: BorderSide(
                      color: AppColors.border.withValues(alpha: 0.85),
                    ),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.handshake_outlined,
                      size: 24,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Carrier match',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: AppColors.foreground,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'MATCH ID',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: AppColors.mutedForeground,
                            ),
                          ),
                          const SizedBox(height: 2),
                          SelectableText(
                            _compactMatchId(match.matchId),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.foreground.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        match.status,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: statusFg,
                          letterSpacing: 0.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (bodyChildren.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: bodyChildren,
                  ),
                ),
            ],
          ),
        ),
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
            Icon(
              Icons.inventory_2_outlined,
              size: 56,
              color: AppColors.mutedForeground,
            ),
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
              onPressed: () => ziproPopOrHome(context),
              child: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParcelInfoGrid extends StatelessWidget {
  const _ParcelInfoGrid({
    required this.shipment,
    required this.showReceiverContact,
    required this.isMatchedTraveller,
    required this.onOpenLink,
  });

  final ShipmentOrderDto shipment;
  final bool showReceiverContact;
  final bool isMatchedTraveller;
  final void Function(String url) onOpenLink;

  String _receiverNameText() {
    if (showReceiverContact) {
      return shipment.receiverName ?? '—';
    }
    if (isMatchedTraveller) return 'Available after payment';
    return '—';
  }

  String _receiverPhoneText() {
    if (showReceiverContact) {
      return shipment.receiverPhone ?? '—';
    }
    if (isMatchedTraveller) return 'Available after payment';
    return '—';
  }

  @override
  Widget build(BuildContext context) {
    final links = shipment.productLinks;
    final items = <(String, String)>[
      (
        'Description',
        shipment.description.isEmpty ? '—' : shipment.description
      ),
      ('Weight', '${shipment.weightKg ?? '—'} kg'),
      (
        'Declared value',
        '${shipment.currency ?? ''} ${shipment.declaredValueAmount ?? '—'}'
            .trim(),
      ),
      (
        'Latest delivery date',
        _latestDeliveryLabel(shipment.latestDeliveryDate)
      ),
      ('Receiver name', _receiverNameText()),
      ('Receiver phone', _receiverPhoneText()),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 520;
        final chunk = wide ? 3 : 1;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < items.length; i += chunk)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var j = 0; j < chunk; j++)
                            if (i + j < items.length)
                              Expanded(
                                child: _ParcelCell(
                                  label: items[i + j].$1,
                                  value: items[i + j].$2,
                                ),
                              ),
                        ],
                      )
                    : _ParcelCell(label: items[i].$1, value: items[i].$2),
              ),
            Text(
              'Product links',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 6),
            if (links.isEmpty)
              Text(
                '—',
                style: TextStyle(
                  color: AppColors.mutedForeground,
                  fontSize: 14,
                ),
              )
            else
              ...links.map(
                (url) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: GestureDetector(
                    onTap: () => onOpenLink(url),
                    child: Text(
                      url,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ParcelCell extends StatelessWidget {
  const _ParcelCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _AddressSection extends StatelessWidget {
  const _AddressSection({required this.addresses});

  final ShipmentAddressesDto addresses;

  @override
  Widget build(BuildContext context) {
    final origin = (addresses.originAddressText ?? '').trim();
    final dest = (addresses.destinationAddressText ?? '').trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_addressPlaceholder(origin))
          _AddressBlock(
            title: 'Origin address',
            text: addresses.originAddressText ?? '',
            contactName: addresses.originContactName,
            contactPhone: addresses.originContactPhone,
          ),
        if (!_addressPlaceholder(dest)) ...[
          if (!_addressPlaceholder(origin)) const SizedBox(height: 16),
          _AddressBlock(
            title: 'Destination address',
            text: addresses.destinationAddressText ?? '',
            contactName: addresses.destinationContactName,
            contactPhone: addresses.destinationContactPhone,
          ),
        ],
      ],
    );
  }
}

class _AddressBlock extends StatelessWidget {
  const _AddressBlock({
    required this.title,
    required this.text,
    this.contactName,
    this.contactPhone,
  });

  final String title;
  final String text;
  final String? contactName;
  final String? contactPhone;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        Text(
          text,
          style: TextStyle(fontSize: 14, color: AppColors.mutedForeground),
        ),
        if (contactName != null || contactPhone != null) ...[
          const SizedBox(height: 6),
          Text(
            'Contact: ${contactName ?? '—'} — ${contactPhone ?? '—'}',
            style: TextStyle(fontSize: 13, color: AppColors.mutedForeground),
          ),
        ],
      ],
    );
  }
}

/// Inline carriers section shown on the shipment detail page when the order is
/// posted by the current user and no match exists yet. Mirrors the web card at
/// `zipro_website_new/app/(app)/shipments/[shipmentId]/page.tsx` (lines 574–617).
class _CarriersInlineSection extends ConsumerWidget {
  const _CarriersInlineSection({
    required this.shipmentId,
    required this.shipment,
    required this.busyTripId,
    required this.onSelect,
  });

  final String shipmentId;
  final ShipmentOrderDto shipment;
  final String? busyTripId;
  final Future<void> Function(String tripId) onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(matchableCarriersProvider(shipmentId));
    return async.when(
      loading: () => const _CarriersCard(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(height: 12),
              Text('Looking for travellers on your route…'),
            ],
          ),
        ),
      ),
      error: (_, __) => _CarriersEmptyCard(shipment: shipment),
      data: (carriers) {
        if (carriers.isEmpty) return _CarriersEmptyCard(shipment: shipment);
        return _CarriersCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Travellers on your route',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              for (final c in carriers)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: CarrierCard(
                    carrier: c,
                    isCreating: busyTripId == c.tripId,
                    onSelect: () => onSelect(c.tripId),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _CarriersCard extends StatelessWidget {
  const _CarriersCard({
    required this.child,
    this.padding = const EdgeInsets.all(24),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _CarriersEmptyCard extends StatelessWidget {
  const _CarriersEmptyCard({required this.shipment});

  final ShipmentOrderDto shipment;

  @override
  Widget build(BuildContext context) {
    final origin =
        cityCountryLabel(shipment.originCity, shipment.originCountryCode);
    final dest = cityCountryLabel(
      shipment.destinationCity,
      shipment.destinationCountryCode,
    );
    return _CarriersCard(
      child: Column(
        children: [
          Icon(
            Icons.flight_takeoff,
            size: 48,
            color: AppColors.mutedForeground,
          ),
          const SizedBox(height: 12),
          const Text(
            'Travellers on your route will appear here',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            'When someone adds a trip from $origin to $dest, '
            "they'll show up here. You can check back anytime.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.mutedForeground,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
