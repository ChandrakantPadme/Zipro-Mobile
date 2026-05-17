import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/navigation/zipro_pop_or_home.dart';
import '../../core/network/dio_error_mapper.dart';
import '../../core/theme/app_theme.dart';
import '../auth/presentation/auth_providers.dart';
import '../repositories_providers.dart';
import 'order_detail_screen.dart' show orderDetailProvider;
import 'widgets/mark_delivered_sheet.dart';
import 'widgets/mark_received_sheet.dart';
import 'widgets/order_tracking_stepper.dart';

/// Mirrors [zipro_website_new/app/(app)/orders/[orderId]/deliver/page.tsx].
class OrderDeliverScreen extends ConsumerStatefulWidget {
  const OrderDeliverScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<OrderDeliverScreen> createState() => _OrderDeliverScreenState();
}

class _OrderDeliverScreenState extends ConsumerState<OrderDeliverScreen> {
  bool _markInTransitBusy = false;

  Future<void> _markInTransit() async {
    if (_markInTransitBusy) return;
    setState(() => _markInTransitBusy = true);
    try {
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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(dioErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _markInTransitBusy = false);
    }
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
          title: const Text('Delivery'),
          leading: ziproLeadingBackOrHome(context),
        ),
        body: asyncOrder.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(dioErrorMessage(e))),
        data: (order) {
          if (order == null) {
            return const Center(child: Text('Order not found'));
          }
          final isCarrier = (order.travelerUserId ?? '').isEmpty ||
              (userId != null && userId == order.travelerUserId);
          if (!isCarrier) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Only the carrier for this order can update delivery status.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.mutedForeground),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => context.go('/order/${widget.orderId}'),
                    child: const Text('Back to order'),
                  ),
                ],
              ),
            );
          }
          final status = order.status;
          final milestone = order.deliveryMilestone;
          final showReceived = const {
            'CONFIRMED',
            'CREATED',
            'PAYMENT_PENDING',
            'MATCHED',
          }.contains(status);
          final showInTransit = status == 'IN_PROGRESS' &&
              (milestone == null || milestone == 'PICKED_UP');
          final showDelivered = status == 'IN_PROGRESS';

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: Column(
                  children: [
                    Icon(Icons.vpn_key_outlined,
                        size: 40, color: AppColors.primary),
                    const SizedBox(height: 12),
                    const Text(
                      'Delivery Verification',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Mark order as received, then in transit, then delivered with OTP.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: OrderTrackingStepper(
                    status: status,
                    deliveryMilestone: milestone,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (showReceived)
                _ActionTile(
                  icon: Icons.assignment_turned_in_outlined,
                  title: 'Product received',
                  description:
                      'Confirm you have received the parcel from the sender.',
                  buttonLabel: 'Mark received',
                  onPressed: _openMarkReceived,
                ),
              if (showInTransit) ...[
                if (showReceived) const SizedBox(height: 12),
                _ActionTile(
                  icon: Icons.local_shipping_outlined,
                  title: 'In transit',
                  description:
                      'Mark the package as in transit when you are on the way.',
                  buttonLabel:
                      _markInTransitBusy ? 'Submitting…' : 'Mark in transit',
                  onPressed: _markInTransitBusy ? null : _markInTransit,
                ),
              ],
              if (showDelivered) ...[
                if (showReceived || showInTransit) const SizedBox(height: 12),
                _ActionTile(
                  icon: Icons.task_alt,
                  title: 'Delivered',
                  description:
                      'Enter the 6-digit OTP from the sender and upload a delivery confirmation photo.',
                  buttonLabel: 'Mark delivered',
                  primary: true,
                  onPressed: _openMarkDelivered,
                ),
              ],
            ],
          );
        },
      ),
    ),
  );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.onPressed,
    this.primary = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final String buttonLabel;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
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
                Icon(icon, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: primary
                  ? FilledButton(
                      onPressed: onPressed,
                      child: Text(buttonLabel),
                    )
                  : OutlinedButton(
                      onPressed: onPressed,
                      child: Text(buttonLabel),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
