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
import '../repositories_providers.dart';
import '../payments/widgets/payment_pending_banner.dart';
import '../shipments/shipment_detail_screen.dart' show paymentByOrderIdProvider;
import 'widgets/mark_delivered_sheet.dart';
import 'widgets/mark_received_sheet.dart';
import 'widgets/order_tracking_stepper.dart';

final orderDetailProvider =
    FutureProvider.family.autoDispose<ShipmentOrderDto?, String>((ref, id) {
  return ref.watch(orderRepositoryProvider).getOrder(id);
});

final shipmentForOrderProvider = FutureProvider.family
    .autoDispose<ShipmentOrderDto?, String?>((ref, shipmentId) async {
  if (shipmentId == null || shipmentId.isEmpty) return null;
  return ref.watch(shipmentRepositoryProvider).getShipment(shipmentId);
});

/// Mirrors [zipro_website_new/app/(app)/orders/[orderId]/page.tsx].
class OrderDetailScreen extends ConsumerStatefulWidget {
  const OrderDetailScreen({
    super.key,
    required this.orderId,
    this.paymentPending = false,
  });

  final String orderId;
  final bool paymentPending;

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  bool _markInTransitBusy = false;
  bool _genOtpBusy = false;
  bool _invoiceBusy = false;
  bool _confirmBusy = false;

  Future<void> _runWithSnack(Future<void> Function() fn) async {
    try {
      await fn();
    } catch (e) {
      if (!mounted) return;
      final msg = e is DioException ? dioErrorMessage(e) : '$e';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _markInTransit() async {
    if (_markInTransitBusy) return;
    setState(() => _markInTransitBusy = true);
    await _runWithSnack(() async {
      final repo = ref.read(orderRepositoryProvider);
      final res = await repo.markInTransit(widget.orderId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(res.message.isNotEmpty ? res.message : 'Marked in transit'),
        ),
      );
      ref.invalidate(orderDetailProvider(widget.orderId));
    });
    if (!mounted) return;
    setState(() => _markInTransitBusy = false);
  }

  Future<void> _generateOtp() async {
    if (_genOtpBusy) return;
    setState(() => _genOtpBusy = true);
    await _runWithSnack(() async {
      final repo = ref.read(orderRepositoryProvider);
      final res = await repo.generateDeliveryOtp(widget.orderId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(res.message.isNotEmpty ? res.message : 'OTP sent to sender'),
        ),
      );
    });
    if (!mounted) return;
    setState(() => _genOtpBusy = false);
  }

  Future<void> _downloadInvoice() async {
    if (_invoiceBusy) return;
    setState(() => _invoiceBusy = true);
    await _runWithSnack(() async {
      final repo = ref.read(orderRepositoryProvider);
      final url = await repo.getInvoiceUrl(widget.orderId);
      if (!mounted) return;
      if (url == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice not available yet')),
        );
        return;
      }
      final uri = Uri.tryParse(url);
      final ok = uri != null && await canLaunchUrl(uri);
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open invoice')),
        );
        return;
      }
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    });
    if (!mounted) return;
    setState(() => _invoiceBusy = false);
  }

  Future<void> _confirmOrder() async {
    if (_confirmBusy) return;
    setState(() => _confirmBusy = true);
    await _runWithSnack(() async {
      final repo = ref.read(orderRepositoryProvider);
      final res = await repo.confirmOrder(widget.orderId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(res.message.isNotEmpty ? res.message : 'Order confirmed'),
        ),
      );
      ref.invalidate(orderDetailProvider(widget.orderId));
    });
    if (!mounted) return;
    setState(() => _confirmBusy = false);
  }

  Future<void> _openMarkReceived() async {
    final ok = await showMarkReceivedSheet(
      context,
      orderId: widget.orderId,
      ref: ref,
    );
    if (ok && mounted) {
      ref.invalidate(orderDetailProvider(widget.orderId));
    }
  }

  Future<void> _openMarkDelivered() async {
    final ok = await showMarkDeliveredSheet(
      context,
      orderId: widget.orderId,
    );
    if (ok && mounted) {
      ref.invalidate(orderDetailProvider(widget.orderId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncOrder = ref.watch(orderDetailProvider(widget.orderId));
    final userId = ref.watch(authNotifierProvider).user?.userId;

    return ZiproPopScope(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Order'),
          leading: ziproLeadingBackOrHome(context),
        ),
        body: asyncOrder.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _NotFoundView(message: dioErrorMessage(e)),
        data: (order) {
          if (order == null) {
            return const _NotFoundView(message: 'Order not found');
          }
          final asyncShipment =
              ref.watch(shipmentForOrderProvider(order.shipmentId));
          final shipment = asyncShipment.asData?.value;
          final asyncPayment =
              ref.watch(paymentByOrderIdProvider(widget.orderId));
          final payment = asyncPayment.asData?.value;
          final paymentSuccess = payment?.status == 'SUCCESS';

          final isSender = (shipment?.senderUserId ?? '').isNotEmpty &&
              userId != null &&
              shipment?.senderUserId == userId;
          final isTraveller = (order.travelerUserId ?? '').isNotEmpty &&
              userId != null &&
              order.travelerUserId == userId;
          final showReceiverContact =
              isSender || (isTraveller && paymentSuccess);

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(orderDetailProvider(widget.orderId));
              if (order.shipmentId != null) {
                ref.invalidate(shipmentForOrderProvider(order.shipmentId));
              }
              ref.invalidate(paymentByOrderIdProvider(widget.orderId));
            },
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (widget.paymentPending) ...[
                  PaymentPendingBanner(
                    orderId: widget.orderId,
                    invalidateOnSuccess: () {
                      ref.invalidate(orderDetailProvider(widget.orderId));
                      if (order.shipmentId != null) {
                        ref.invalidate(
                            shipmentForOrderProvider(order.shipmentId));
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                ],
                _OrderHeaderCard(order: order),
                if (const {'CONFIRMED', 'IN_PROGRESS', 'DELIVERED'}
                    .contains(order.status)) ...[
                  const SizedBox(height: 16),
                  _TrackingCard(
                    order: order,
                    isTraveller: isTraveller,
                    markInTransitBusy: _markInTransitBusy,
                    onMarkInTransit: _markInTransit,
                    onMarkReceived: _openMarkReceived,
                    onMarkDelivered: _openMarkDelivered,
                  ),
                ],
                if (shipment != null) ...[
                  const SizedBox(height: 16),
                  _RouteParcelCard(
                    shipment: shipment,
                    isTraveller: isTraveller,
                    showReceiverContact: showReceiverContact,
                  ),
                ],
                const SizedBox(height: 16),
                _FeesCard(order: order, isSender: isSender),
                const SizedBox(height: 16),
                _ActionsCard(
                  order: order,
                  isSender: isSender,
                  isTraveller: isTraveller,
                  invoiceBusy: _invoiceBusy,
                  confirmBusy: _confirmBusy,
                  genOtpBusy: _genOtpBusy,
                  onPay: () => context.push('/order/${widget.orderId}/pay'),
                  onDownloadInvoice: _downloadInvoice,
                  onConfirm: _confirmOrder,
                  onGenerateOtp: _generateOtp,
                  onDeliveryManagement: () =>
                      context.push('/order/${widget.orderId}/deliver'),
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    ),
  );
  }
}

class _OrderHeaderCard extends StatelessWidget {
  const _OrderHeaderCard({required this.order});

  final ShipmentOrderDto order;

  @override
  Widget build(BuildContext context) {
    final last8 = order.orderId.length > 8
        ? order.orderId.substring(order.orderId.length - 8)
        : order.orderId;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.inventory_2_outlined,
                  color: AppColors.primary, size: 22),
              const SizedBox(width: 8),
              Text(
                'Order $last8',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              _StatusChip(status: order.status),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Order ID: ${order.orderId}',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.mutedForeground,
            ),
          ),
          if (order.createdAt != null && order.createdAt!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Created: ${_formatDateTime(order.createdAt)}',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.mutedForeground,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TrackingCard extends StatelessWidget {
  const _TrackingCard({
    required this.order,
    required this.isTraveller,
    required this.markInTransitBusy,
    required this.onMarkInTransit,
    required this.onMarkReceived,
    required this.onMarkDelivered,
  });

  final ShipmentOrderDto order;
  final bool isTraveller;
  final bool markInTransitBusy;
  final VoidCallback onMarkInTransit;
  final VoidCallback onMarkReceived;
  final VoidCallback onMarkDelivered;

  @override
  Widget build(BuildContext context) {
    final status = order.status;
    final milestone = order.deliveryMilestone;
    final showReceived = isTraveller && status == 'CONFIRMED';
    final showInTransit =
        isTraveller && status == 'IN_PROGRESS' && milestone == 'PICKED_UP';
    final showDelivered = isTraveller &&
        status == 'IN_PROGRESS' &&
        (milestone == 'IN_TRANSIT' || milestone == 'PICKED_UP');
    return _Card(
      borderColor: AppColors.primary,
      borderWidth: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tracking',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            'Product received → In transit → Delivered',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 16),
          OrderTrackingStepper(
            status: status,
            deliveryMilestone: milestone,
          ),
          if (isTraveller &&
              (showReceived || showInTransit || showDelivered)) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (showReceived)
                  OutlinedButton.icon(
                    onPressed: onMarkReceived,
                    icon: const Icon(Icons.assignment_turned_in_outlined,
                        size: 18),
                    label: const Text('Product received'),
                  ),
                if (showInTransit)
                  OutlinedButton.icon(
                    onPressed: markInTransitBusy ? null : onMarkInTransit,
                    icon: markInTransitBusy
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.local_shipping_outlined, size: 18),
                    label: const Text('In transit'),
                  ),
                if (showDelivered)
                  FilledButton.icon(
                    onPressed: onMarkDelivered,
                    icon: const Icon(Icons.task_alt, size: 18),
                    label: const Text('Mark delivered'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RouteParcelCard extends StatelessWidget {
  const _RouteParcelCard({
    required this.shipment,
    required this.isTraveller,
    required this.showReceiverContact,
  });

  final ShipmentOrderDto shipment;
  final bool isTraveller;
  final bool showReceiverContact;

  @override
  Widget build(BuildContext context) {
    final originAddr = (shipment.addresses?.originAddressText ?? '').trim();
    final destAddr = (shipment.addresses?.destinationAddressText ?? '').trim();
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.place_outlined,
                  size: 18, color: AppColors.mutedForeground),
              const SizedBox(width: 6),
              const Text(
                'Route & parcel',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth >= 480;
              final from = _RouteCell(
                title: 'From',
                primary: cityCountryLabel(
                  shipment.originCity,
                  shipment.originCountryCode,
                ),
                secondary: _renderableAddress(originAddr),
              );
              final to = _RouteCell(
                title: 'To',
                primary: cityCountryLabel(
                  shipment.destinationCity,
                  shipment.destinationCountryCode,
                ),
                secondary: _renderableAddress(destAddr),
              );
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: from),
                    const SizedBox(width: 16),
                    Expanded(child: to),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  from,
                  const SizedBox(height: 12),
                  to,
                ],
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: AppColors.border, height: 1),
          ),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.scale_outlined,
                      size: 16, color: AppColors.mutedForeground),
                  const SizedBox(width: 4),
                  Text(
                    'Weight: ${shipment.weightKg ?? '—'} kg',
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
              if (shipment.declaredValueAmount != null)
                Text(
                  'Declared value: ${shipment.currency ?? ''} ${shipment.declaredValueAmount}',
                  style: const TextStyle(fontSize: 13),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: AppColors.border, height: 1),
          ),
          LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth >= 480;
              final receiverName = _RouteCell(
                title: 'Receiver name',
                primary: showReceiverContact
                    ? (shipment.receiverName ?? '—')
                    : (isTraveller ? 'Awaiting payment from sender' : '—'),
              );
              final receiverPhone = _RouteCell(
                title: 'Receiver phone',
                primary: showReceiverContact
                    ? (shipment.receiverPhone ?? '—')
                    : (isTraveller ? 'Awaiting payment from sender' : '—'),
              );
              final nextSteps = isTraveller && showReceiverContact
                  ? const _RouteCell(
                      title: 'Next steps',
                      primary: 'Communicate with sender for further steps.',
                    )
                  : null;
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: receiverName),
                    const SizedBox(width: 16),
                    Expanded(child: receiverPhone),
                    if (nextSteps != null) ...[
                      const SizedBox(width: 16),
                      Expanded(child: nextSteps),
                    ],
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  receiverName,
                  const SizedBox(height: 12),
                  receiverPhone,
                  if (nextSteps != null) ...[
                    const SizedBox(height: 12),
                    nextSteps,
                  ],
                ],
              );
            },
          ),
          if (shipment.items.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Divider(color: AppColors.border, height: 1),
            ),
            Text(
              'Items',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 6),
            ...shipment.items.map(
              (it) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• ${it.itemDescription}'
                  '${it.quantity > 0 ? ' × ${_formatQty(it.quantity)}' : ''}',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String? _renderableAddress(String s) {
    if (s.isEmpty) return null;
    if (s.toLowerCase() == 'to be provided') return null;
    return s;
  }

  static String _formatQty(num q) {
    return q == q.truncateToDouble() ? q.toInt().toString() : q.toString();
  }
}

class _RouteCell extends StatelessWidget {
  const _RouteCell({
    required this.title,
    required this.primary,
    this.secondary,
  });

  final String title;
  final String primary;
  final String? secondary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.mutedForeground,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(primary, style: const TextStyle(fontSize: 14)),
        if (secondary != null) ...[
          const SizedBox(height: 2),
          Text(
            secondary!,
            style: TextStyle(fontSize: 12, color: AppColors.mutedForeground),
          ),
        ],
      ],
    );
  }
}

class _FeesCard extends StatelessWidget {
  const _FeesCard({required this.order, required this.isSender});

  final ShipmentOrderDto order;
  final bool isSender;

  @override
  Widget build(BuildContext context) {
    final cur = order.currency ?? '';
    final hasBreakdown = order.deliveryFee != null ||
        order.weightFare != null ||
        order.secureFee != null ||
        order.subtotal != null;
    final showSenderBreakdown = isSender && hasBreakdown;
    final senderTotal = order.totalAmountToPay ?? order.total;
    final travellerEarning = order.subtotal ?? order.travelerFee;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isSender) ...[
            const Text(
              'Fees',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
          ],
          if (showSenderBreakdown) ...[
            if (order.deliveryFee != null)
              _feeRow(context, 'Delivery fee', cur, order.deliveryFee),
            if (order.weightFare != null && order.weightFare! >= 0)
              _feeRow(context, 'Weight fare', cur, order.weightFare),
            if (order.secureFee != null)
              _feeRow(context, 'Parcel Protection Fee', cur, order.secureFee),
            if (order.subtotal != null)
              _feeRow(context, 'Subtotal', cur, order.subtotal),
            const SizedBox(height: 8),
            Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 8),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isSender ? 'Total fees' : 'Your earnings',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              Text(
                isSender
                    ? '$cur ${_fmt(senderTotal)}'
                    : '$cur ${_fmt(travellerEarning)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _feeRow(
      BuildContext context, String label, String currency, num? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.mutedForeground,
              )),
          Text('$currency ${_fmt(value)}',
              style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  static String _fmt(num? v) {
    if (v == null) return '—';
    return v.toStringAsFixed(2);
  }
}

class _ActionsCard extends StatelessWidget {
  const _ActionsCard({
    required this.order,
    required this.isSender,
    required this.isTraveller,
    required this.invoiceBusy,
    required this.confirmBusy,
    required this.genOtpBusy,
    required this.onPay,
    required this.onDownloadInvoice,
    required this.onConfirm,
    required this.onGenerateOtp,
    required this.onDeliveryManagement,
  });

  final ShipmentOrderDto order;
  final bool isSender;
  final bool isTraveller;
  final bool invoiceBusy;
  final bool confirmBusy;
  final bool genOtpBusy;
  final VoidCallback onPay;
  final VoidCallback onDownloadInvoice;
  final VoidCallback onConfirm;
  final VoidCallback onGenerateOtp;
  final VoidCallback onDeliveryManagement;

  @override
  Widget build(BuildContext context) {
    final canPay = isSender &&
        const {'CREATED', 'AWAITING_PAYMENT', 'PAYMENT_PENDING'}
            .contains(order.status);
    final canConfirm = isSender && order.status == 'CREATED';
    final canDownloadInvoice = isSender &&
        const {'CONFIRMED', 'IN_PROGRESS', 'DELIVERED'}.contains(order.status);
    final canGenerateOtp = isTraveller &&
        const {'CONFIRMED', 'IN_PROGRESS'}.contains(order.status);
    final canOpenDelivery = isTraveller && order.status == 'IN_PROGRESS';

    final actions = <Widget>[
      if (canPay)
        FilledButton.icon(
          onPressed: onPay,
          icon: const Icon(Icons.credit_card, size: 18),
          label: const Text('Pay now'),
        ),
      if (canConfirm)
        FilledButton.icon(
          onPressed: confirmBusy ? null : onConfirm,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.primaryForeground,
          ),
          icon: confirmBusy
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_circle_outline, size: 18),
          label: const Text('Confirm order'),
        ),
      if (canDownloadInvoice)
        OutlinedButton.icon(
          onPressed: invoiceBusy ? null : onDownloadInvoice,
          icon: invoiceBusy
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download_outlined, size: 18),
          label: Text(invoiceBusy ? 'Loading…' : 'Download invoice'),
        ),
      if (canGenerateOtp)
        OutlinedButton.icon(
          onPressed: genOtpBusy ? null : onGenerateOtp,
          icon: genOtpBusy
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.vpn_key_outlined, size: 18),
          label: Text(genOtpBusy ? 'Sending…' : 'Generate delivery OTP'),
        ),
      if (canOpenDelivery)
        FilledButton.icon(
          onPressed: onDeliveryManagement,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: AppColors.accentForeground,
          ),
          icon: const Icon(Icons.assignment_outlined, size: 18),
          label: const Text('Delivery Management'),
        ),
    ];
    if (actions.isEmpty) return const SizedBox.shrink();
    return _Card(
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: actions,
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
      case 'CREATED':
      case 'AWAITING_PAYMENT':
      case 'PAYMENT_PENDING':
        bg = AppColors.primary.withValues(alpha: 0.12);
        fg = AppColors.primary;
        break;
      case 'CONFIRMED':
      case 'DELIVERED':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF166534);
        break;
      case 'IN_PROGRESS':
        bg = AppColors.accent.withValues(alpha: 0.18);
        fg = AppColors.accent;
        break;
      case 'CANCELLED':
        bg = AppColors.destructive.withValues(alpha: 0.12);
        fg = AppColors.destructive;
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

class _Card extends StatelessWidget {
  const _Card({
    required this.child,
    this.borderColor,
    this.borderWidth,
  });

  final Widget child;
  final Color? borderColor;
  final double? borderWidth;

  @override
  Widget build(BuildContext context) {
    final accentW = borderWidth ?? 4;
    final accent = borderColor;

    // Flutter forbids borderRadius + Border sides with different colours.
    if (accent != null) {
      return Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: accentW, color: accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: child,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
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
            Icon(Icons.inventory_2_outlined,
                size: 56, color: AppColors.mutedForeground),
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
              child: const Text('Back to orders'),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDateTime(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final dt = DateTime.tryParse(iso);
  if (dt == null) return iso;
  return DateFormat('MMM dd, yyyy HH:mm').format(dt.toLocal());
}
