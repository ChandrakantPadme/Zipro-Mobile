import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/delivery_models.dart';
import '../../core/network/dio_error_mapper.dart';
import '../repositories_providers.dart';

final orderDetailProvider =
    FutureProvider.family.autoDispose<ShipmentOrderDto?, String>((ref, id) {
  return ref.watch(orderRepositoryProvider).getOrder(id);
});

class OrderDetailScreen extends ConsumerStatefulWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  final _otp = TextEditingController();
  final _buyerOtp = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _otp.dispose();
    _buyerOtp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(orderDetailProvider(widget.orderId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order'),
        actions: [
          TextButton(
            onPressed: () => context.push('/order/${widget.orderId}/pay'),
            child: const Text('Pay'),
          ),
        ],
      ),
      body: async.when(
        data: (o) {
          if (o == null) return const Center(child: Text('Not found'));
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${o.originCity} → ${o.destinationCity}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                ),
                Text('Status: ${o.status}'),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          setState(() => _busy = true);
                          final r = await ref
                              .read(orderRepositoryProvider)
                              .markInTransit(widget.orderId);
                          setState(() => _busy = false);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(r.message)),
                          );
                          ref.invalidate(orderDetailProvider(widget.orderId));
                        },
                  child: const Text('Mark in transit'),
                ),
                TextField(
                  controller: _otp,
                  decoration: const InputDecoration(
                    labelText: 'Delivery OTP (traveler)',
                  ),
                ),
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          setState(() => _busy = true);
                          final r = await ref
                              .read(orderRepositoryProvider)
                              .markDelivered(
                                widget.orderId,
                                otp: _otp.text.trim(),
                              );
                          setState(() => _busy = false);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(r.message)),
                          );
                          ref.invalidate(orderDetailProvider(widget.orderId));
                        },
                  child: const Text('Mark delivered'),
                ),
                const Divider(height: 32),
                TextField(
                  controller: _buyerOtp,
                  decoration: const InputDecoration(
                    labelText: 'Buyer: verify delivery OTP',
                  ),
                  keyboardType: TextInputType.number,
                ),
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          setState(() => _busy = true);
                          final r = await ref
                              .read(orderRepositoryProvider)
                              .verifyDeliveryOtp(
                                widget.orderId,
                                _buyerOtp.text.trim(),
                              );
                          setState(() => _busy = false);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(r.message)),
                          );
                          ref.invalidate(orderDetailProvider(widget.orderId));
                        },
                  child: const Text('Verify OTP'),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(dioErrorMessage(e))),
      ),
    );
  }
}
