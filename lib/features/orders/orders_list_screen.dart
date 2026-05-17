import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/models/delivery_models.dart';
import '../../core/network/dio_error_mapper.dart';
import '../../core/theme/app_theme.dart';
import '../repositories_providers.dart';

final myOrdersPairProvider = FutureProvider.autoDispose<
    ({
      List<ShipmentOrderDto> buyer,
      List<ShipmentOrderDto> traveler
    })>((ref) async {
  final repo = ref.watch(orderRepositoryProvider);
  final buyer = await repo.getMyOrdersBuyer();
  final traveler = await repo.getMyOrdersTraveler();
  return (buyer: buyer, traveler: traveler);
});

String _fmt(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  try {
    return DateFormat('MMM dd, yyyy').format(DateTime.parse(iso).toLocal());
  } catch (_) {
    return iso;
  }
}

/// Parity with [zipro_website_new/app/(app)/orders/page.tsx].
class OrdersListScreen extends ConsumerWidget {
  const OrdersListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myOrdersPairProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('My Orders'),
      ),
      body: SafeArea(
        child: async.when(
          data: (pair) {
            return DefaultTabController(
              length: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Text(
                      'Track your orders as a buyer or traveller',
                      style: TextStyle(color: AppColors.mutedForeground),
                    ),
                  ),
                  TabBar(
                    labelColor: AppColors.primary,
                    unselectedLabelColor: AppColors.mutedForeground,
                    tabs: const [
                      Tab(text: 'As Buyer'),
                      Tab(text: 'As Traveller'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _OrdersListPane(
                          orders: pair.buyer,
                          isBuyer: true,
                          onRefresh: () async {
                            ref.invalidate(myOrdersPairProvider);
                          },
                          amountForDisplay: (o) => o.total,
                        ),
                        _OrdersListPane(
                          orders: pair.traveler,
                          isBuyer: false,
                          onRefresh: () async {
                            ref.invalidate(myOrdersPairProvider);
                          },
                          amountForDisplay: (o) => o.subtotal ?? o.total,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(dioErrorMessage(e))),
        ),
      ),
    );
  }
}

class _OrdersListPane extends StatelessWidget {
  const _OrdersListPane({
    required this.orders,
    required this.isBuyer,
    required this.onRefresh,
    required this.amountForDisplay,
  });

  final List<ShipmentOrderDto> orders;
  final bool isBuyer;
  final Future<void> Function() onRefresh;
  final num? Function(ShipmentOrderDto o) amountForDisplay;

  static const _payableStatuses = {
    'CREATED',
    'AWAITING_PAYMENT',
    'PAYMENT_PENDING',
  };

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(32),
          children: [
            Icon(Icons.inventory_2_outlined,
                size: 48, color: AppColors.mutedForeground),
            const SizedBox(height: 16),
            Text(
              'No orders found',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.mutedForeground),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final order = orders[i];
          final short = order.orderId.length > 8
              ? order.orderId.substring(order.orderId.length - 8)
              : order.orderId;
          final amt = amountForDisplay(order);
          final cur = order.currency ?? '';
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Order $short',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Chip(
                        label: Text(order.status,
                            style: const TextStyle(fontSize: 11)),
                        visualDensity: VisualDensity.compact,
                        side: BorderSide(color: AppColors.border),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Total: $cur ${amt ?? '—'}',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.mutedForeground),
                  ),
                  if (order.createdAt != null && order.createdAt!.isNotEmpty)
                    Text(
                      'Created: ${_fmt(order.createdAt)}',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.mutedForeground),
                    ),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (isBuyer && _payableStatuses.contains(order.status))
                        FilledButton.icon(
                          onPressed: () =>
                              context.push('/order/${order.orderId}/pay'),
                          icon: const Icon(Icons.credit_card, size: 16),
                          label: const Text('Pay now'),
                        ),
                      OutlinedButton(
                        onPressed: () =>
                            context.push('/order/${order.orderId}'),
                        child: const Text('View Details'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
