import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../core/env/app_config.dart';
import '../repositories_providers.dart';
import 'order_detail_screen.dart';

class OrderPayScreen extends ConsumerStatefulWidget {
  const OrderPayScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<OrderPayScreen> createState() => _OrderPayScreenState();
}

class _OrderPayScreenState extends ConsumerState<OrderPayScreen> {
  late final Razorpay _rz;
  String? _rzOrderIdForVerify;
  String? _keyFromApi;
  bool _loading = true;
  String? _error;
  num _amount = 0;
  String _currency = 'INR';

  @override
  void initState() {
    super.initState();
    _rz = Razorpay();
    _rz.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onSuccess);
    _rz.on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError);
    _rz.on(Razorpay.EVENT_EXTERNAL_WALLET, (_) {});
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final repo = ref.read(paymentRepositoryProvider);
    final res = await repo.createPaymentOrder(widget.orderId);
    if (!mounted) return;
    if (!res.success || res.data == null) {
      setState(() {
        _loading = false;
        _error = res.message.isNotEmpty ? res.message : 'Could not start payment';
      });
      return;
    }
    final d = res.data!;
    _rzOrderIdForVerify = d.razorpayOrderIdOrId;
    _keyFromApi = d.razorpayKeyId;
    setState(() {
      _amount = d.amount;
      _currency = d.currency;
      _loading = false;
    });
  }

  Future<void> _onSuccess(PaymentSuccessResponse r) async {
    final repo = ref.read(paymentRepositoryProvider);
    final verify = await repo.verifyPayment(
      razorpayOrderId: _rzOrderIdForVerify ?? r.orderId ?? '',
      razorpayPaymentId: r.paymentId ?? '',
      razorpaySignature: r.signature ?? '',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(verify.message)),
    );
    ref.invalidate(orderDetailProvider(widget.orderId));
    context.pop();
  }

  void _onPaymentError(PaymentFailureResponse r) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(r.message ?? 'Payment failed')),
    );
  }

  void _openCheckout() {
    final key = (_keyFromApi != null && _keyFromApi!.trim().isNotEmpty)
        ? _keyFromApi!.trim()
        : AppConfig.razorpayKeyId;
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Set RAZORPAY_KEY_ID via dart-define or use backend key'),
        ),
      );
      return;
    }
    final options = {
      'key': key,
      'amount': _amount.round(),
      'currency': _currency,
      'name': 'Zipro',
      'description': 'Order ${widget.orderId}',
      if (_rzOrderIdForVerify != null) 'order_id': _rzOrderIdForVerify,
      'retry': {'enabled': true},
    };
    _rz.open(options);
  }

  @override
  void dispose() {
    _rz.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pay')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Text(_error!)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Amount: $_amount $_currency'),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _openCheckout,
                        child: const Text('Pay with Razorpay'),
                      ),
                    ],
                  ),
      ),
    );
  }
}
