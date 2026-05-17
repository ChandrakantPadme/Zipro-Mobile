import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../shipments/shipment_detail_screen.dart'
    show paymentByOrderIdProvider;

/// Mirrors the `?payment=pending` post-pay banner on web
/// (see `app/(app)/orders/[orderId]/page.tsx` and `shipments/[shipmentId]/page.tsx`).
///
/// Polls the payment status every few seconds while it is `PENDING` or
/// `PROCESSING`, and shows either a "Payment processing" loading card or a
/// green "Payment successful" confirmation card. The webhook on the backend
/// flips the status to `SUCCESS` once Razorpay confirms.
class PaymentPendingBanner extends ConsumerStatefulWidget {
  const PaymentPendingBanner({
    super.key,
    required this.orderId,
    required this.invalidateOnSuccess,
  });

  final String orderId;

  /// Riverpod refresh callback fired once when payment flips to `SUCCESS`,
  /// so the host screen can also refresh order/shipment data.
  final VoidCallback invalidateOnSuccess;

  @override
  ConsumerState<PaymentPendingBanner> createState() =>
      _PaymentPendingBannerState();
}

class _PaymentPendingBannerState extends ConsumerState<PaymentPendingBanner> {
  Timer? _pollTimer;
  bool _shownSuccessOnce = false;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      final p =
          ref.read(paymentByOrderIdProvider(widget.orderId)).asData?.value;
      final status = p?.status ?? '';
      if (status == 'SUCCESS' || status == 'FAILED' || status == 'REFUNDED') {
        _pollTimer?.cancel();
        _pollTimer = null;
        return;
      }
      ref.invalidate(paymentByOrderIdProvider(widget.orderId));
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(paymentByOrderIdProvider(widget.orderId));
    final status = p.asData?.value?.status ?? '';
    if (status == 'SUCCESS' && !_shownSuccessOnce) {
      _shownSuccessOnce = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.invalidateOnSuccess();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment successful! Order confirmed.'),
          ),
        );
      });
    }
    if (status == 'SUCCESS') {
      return _SuccessBanner();
    }
    if (status == 'FAILED' || status == 'REFUNDED') {
      return const SizedBox.shrink();
    }
    return const _ProcessingBanner();
  }
}

class _ProcessingBanner extends StatelessWidget {
  const _ProcessingBanner();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.30),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Payment processing',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'This may take a few seconds. Status will update when Razorpay confirms your payment.',
                    style: TextStyle(
                      fontSize: 12,
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

class _SuccessBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const greenBg = Color(0x1A22C55E);
    const greenBorder = Color(0x6622C55E);
    const greenFg = Color(0xFF166534);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: greenBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: greenBorder),
      ),
      child: const Padding(
        padding: EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: greenFg, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Payment successful. Order confirmed.',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: greenFg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
