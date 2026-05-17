import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

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

final shipmentDetailProvider = FutureProvider.family
    .autoDispose<ShipmentOrderDto?, String>((ref, id) async {
  final repo = ref.watch(shipmentRepositoryProvider);
  return repo.getShipment(id);
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

    final isSenderForAppBar = asyncShipment.asData?.value != null &&
        asyncShipment.asData!.value!.senderUserId != null &&
        asyncShipment.asData!.value!.senderUserId!.isNotEmpty &&
        userId != null &&
        asyncShipment.asData!.value!.senderUserId == userId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order'),
        actions: [
          if (isSenderForAppBar)
            IconButton(
              icon: const Icon(Icons.people_outline),
              tooltip: 'Choose traveller',
              onPressed: () =>
                  context.push('/shipment/${widget.shipmentId}/carriers'),
            ),
        ],
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
                              color: AppColors.mutedForeground,
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
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ...matches.map(
                    (m) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                Text(
                                  'Match …${m.matchId.length > 8 ? m.matchId.substring(m.matchId.length - 8) : m.matchId}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Chip(
                                  label: Text(
                                    m.status,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  side: BorderSide(color: AppColors.border),
                                ),
                                if (!isSender)
                                  Text(
                                    'Fee: ${m.currency ?? feeCurrency} ${m.agreedFee}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.mutedForeground,
                                    ),
                                  ),
                              ],
                            ),
                            if (m.status == 'OFFERED')
                              Text(
                                'Request sent. Waiting for carrier to review and accept.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.mutedForeground,
                                ),
                              ),
                            if (isPosted && acceptedMatch == null)
                              TextButton(
                                onPressed: () => context.push(
                                  '/shipment/${widget.shipmentId}/carriers',
                                ),
                                child: const Text('Choose another traveller'),
                              ),
                          ],
                        ),
                      ),
                    ),
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
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/browse/orders');
                }
              },
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
