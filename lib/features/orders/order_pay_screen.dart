import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../core/env/app_config.dart';
import '../../core/navigation/zipro_pop_or_home.dart';
import '../../core/models/delivery_models.dart';
import '../../core/network/dio_error_mapper.dart';
import '../../core/theme/app_theme.dart';
import '../payments/widgets/payment_status_card.dart';
import '../repositories_providers.dart';
import '../shipments/shipment_detail_screen.dart' show paymentByOrderIdProvider;
import 'order_detail_screen.dart';

/// Mirrors [zipro_website_new/app/(app)/orders/[orderId]/pay/page.tsx]:
/// shows the full order summary, payment status panel, and a Razorpay
/// checkout that gracefully resumes an existing pending payment.
class OrderPayScreen extends ConsumerStatefulWidget {
  const OrderPayScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<OrderPayScreen> createState() => _OrderPayScreenState();
}

class _OrderPayScreenState extends ConsumerState<OrderPayScreen> {
  late final Razorpay _rz;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _rz = Razorpay();
    _rz.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onSuccess);
    _rz.on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError);
    _rz.on(Razorpay.EVENT_EXTERNAL_WALLET, (_) {});
  }

  @override
  void dispose() {
    _rz.clear();
    super.dispose();
  }

  Future<void> _onSuccess(PaymentSuccessResponse r) async {
    final repo = ref.read(paymentRepositoryProvider);
    try {
      final verify = await repo.verifyPayment(
        razorpayOrderId: r.orderId ?? '',
        razorpayPaymentId: r.paymentId ?? '',
        razorpaySignature: r.signature ?? '',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(verify.message.isNotEmpty
                ? verify.message
                : 'Payment received')),
      );
    } catch (_) {
      // Verification can fail if the webhook hasn't completed yet — that
      // is fine; the order detail screen polls payment status and will
      // flip to SUCCESS as soon as Razorpay's webhook confirms.
    }
    ref.invalidate(orderDetailProvider(widget.orderId));
    ref.invalidate(paymentByOrderIdProvider(widget.orderId));
    if (!mounted) return;
    final order = ref.read(orderDetailProvider(widget.orderId)).asData?.value;
    final shipmentId = order?.shipmentId;
    if (shipmentId != null && shipmentId.isNotEmpty) {
      context.go('/shipment/$shipmentId?payment=pending');
    } else {
      context.go('/order/${widget.orderId}?payment=pending');
    }
  }

  void _onPaymentError(PaymentFailureResponse r) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(r.message ?? 'Payment failed')),
    );
  }

  Future<RazorpayOrderDto?> _resumeExistingPayment() async {
    try {
      final p = await ref
          .read(paymentRepositoryProvider)
          .getPaymentByOrder(widget.orderId);
      if (p == null) return null;
      final rzOrderId = p.razorpayOrderId ?? '';
      if (p.status != 'PENDING' || rzOrderId.isEmpty) return null;
      final amountInPaise =
          p.amount == null ? 0 : (p.amount!.toDouble() * 100).round();
      return RazorpayOrderDto(
        razorpayOrderId: rzOrderId,
        amount: amountInPaise,
        currency: p.currency ?? 'INR',
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _onPay(ShipmentOrderDto order) async {
    if (_busy) return;
    setState(() => _busy = true);
    final repo = ref.read(paymentRepositoryProvider);
    try {
      final res = await repo.createPaymentOrder(widget.orderId);
      if (res.success && res.data != null) {
        _openCheckout(order, res.data!);
        return;
      }
      // Fall through to "already exists" handling.
      final resume = await _resumeExistingPayment();
      if (resume != null) {
        _openCheckout(order, resume);
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              res.message.isNotEmpty ? res.message : 'Could not start payment'),
        ),
      );
    } on DioException catch (e) {
      final msg = (e.response?.data is Map<String, dynamic>
              ? (e.response!.data as Map<String, dynamic>)['message'] as String?
              : null) ??
          dioErrorMessage(e);
      if (msg.toLowerCase().contains('already exists')) {
        final resume = await _resumeExistingPayment();
        if (resume != null) {
          _openCheckout(order, resume);
          return;
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openCheckout(ShipmentOrderDto order, RazorpayOrderDto rz) {
    final key = (rz.razorpayKeyId ?? '').trim().isNotEmpty
        ? rz.razorpayKeyId!.trim()
        : AppConfig.razorpayKeyId;
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Set RAZORPAY_KEY_ID via dart-define or use backend key'),
        ),
      );
      return;
    }
    final options = <String, dynamic>{
      'key': key,
      'amount': rz.amount.round(),
      'currency': rz.currency,
      'name': 'Zipro',
      'description': rz.description ?? 'Order ${widget.orderId}',
      'order_id': rz.razorpayOrderId,
      'retry': {'enabled': true},
      'prefill': {
        if ((rz.customerName ?? '').isNotEmpty) 'name': rz.customerName,
        if ((rz.customerEmail ?? '').isNotEmpty) 'email': rz.customerEmail,
        if ((rz.customerPhone ?? '').isNotEmpty) 'contact': rz.customerPhone,
      },
    };
    _rz.open(options);
  }

  bool _canPay(ShipmentOrderDto order) {
    return const {'CREATED', 'AWAITING_PAYMENT', 'PAYMENT_PENDING'}
        .contains(order.status);
  }

  @override
  Widget build(BuildContext context) {
    final asyncOrder = ref.watch(orderDetailProvider(widget.orderId));
    final asyncPayment = ref.watch(paymentByOrderIdProvider(widget.orderId));
    return ZiproPopScope(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Payment'),
          leading: ziproLeadingBackOrHome(context),
        ),
        body: asyncOrder.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(dioErrorMessage(e))),
        data: (order) {
          if (order == null) {
            return const Center(child: Text('Order not found'));
          }
          if (!_canPay(order)) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'This order is not in a payable state.\nCurrent status: ${order.status}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.mutedForeground),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () => context.go('/order/${widget.orderId}'),
                      child: const Text('View order'),
                    ),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(orderDetailProvider(widget.orderId));
              ref.invalidate(paymentByOrderIdProvider(widget.orderId));
            },
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _OrderSummaryCard(order: order),
                const SizedBox(height: 16),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        PaymentStatusCard(
                          payment: asyncPayment.asData?.value,
                          embedded: true,
                        ),
                        const SizedBox(height: 12),
                        Divider(color: AppColors.border, height: 1),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                            onPressed: _busy ? null : () => _onPay(order),
                            icon: _busy
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.credit_card, size: 18),
                            label: Text(_busy ? 'Processing…' : 'Pay Now'),
                          ),
                        ),
                      ],
                    ),
                  ),
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

class _OrderSummaryCard extends StatelessWidget {
  const _OrderSummaryCard({required this.order});

  final ShipmentOrderDto order;

  @override
  Widget build(BuildContext context) {
    final cur = order.currency ?? '';
    final hasBreakdown = order.deliveryFee != null ||
        order.weightFare != null ||
        order.secureFee != null;
    final total = order.totalAmountToPay ?? order.total;
    final last8 = order.orderId.length > 8
        ? order.orderId.substring(order.orderId.length - 8)
        : order.orderId;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.credit_card,
                    size: 20, color: AppColors.mutedForeground),
                const SizedBox(width: 8),
                const Text(
                  'Order Summary',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                _StatusChip(status: order.status),
              ],
            ),
            const SizedBox(height: 12),
            _row('Order ID', last8),
            if (hasBreakdown) ...[
              if (order.deliveryFee != null)
                _row('Delivery fee', '$cur ${order.deliveryFee}'),
              if (order.weightFare != null && order.weightFare! > 0)
                _row('Weight fare', '$cur ${order.weightFare}'),
              if (order.secureFee != null)
                _row('Parcel Protection Fee', '$cur ${order.secureFee}'),
            ] else ...[
              if (order.subtotal != null)
                _row('Subtotal', '$cur ${order.subtotal}'),
            ],
            const SizedBox(height: 8),
            Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                Text(
                  '$cur ${total ?? 0}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.mutedForeground,
              )),
          Text(value, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
