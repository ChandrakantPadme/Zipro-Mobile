import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/models/delivery_models.dart';
import '../../../core/theme/app_theme.dart';

/// Mirrors [zipro_website_new/components/payments/payment-status.tsx].
class PaymentStatusCard extends StatelessWidget {
  const PaymentStatusCard({
    super.key,
    required this.payment,
    this.embedded = false,
  });

  final PaymentDto? payment;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final inner = _buildInner(context);
    if (embedded) return inner;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: inner,
      ),
    );
  }

  Widget _buildInner(BuildContext context) {
    final p = payment;
    if (p == null) {
      return Text(
        'No payment information available',
        style: TextStyle(
          fontSize: 13,
          color: AppColors.mutedForeground,
        ),
      );
    }
    final status = p.status;
    final config = _statusFor(status);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(config.icon, color: config.color, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Payment Status',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: config.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                config.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: config.color,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (p.amount != null)
          _row(
            'Amount',
            '${p.currency ?? ''} ${p.amount}',
          ),
        if ((p.paymentMethod ?? '').isNotEmpty)
          _row('Payment method', p.paymentMethod!),
        if ((p.transactionId ?? '').isNotEmpty)
          _row('Transaction ID', p.transactionId!, mono: true),
        if ((p.razorpayPaymentId ?? '').isNotEmpty)
          _row('Razorpay payment ID', p.razorpayPaymentId!, mono: true),
        if ((p.createdAt ?? '').isNotEmpty)
          _row('Created', _formatDateTime(p.createdAt!)),
        if ((p.failureReason ?? '').isNotEmpty) ...[
          const SizedBox(height: 8),
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.destructive.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Text(
                p.failureReason!,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.destructive,
                ),
              ),
            ),
          ),
        ],
        if (status == 'PROCESSING') ...[
          const SizedBox(height: 8),
          Text(
            'Payment is being processed. Please wait…',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.mutedForeground,
            ),
          ),
        ],
      ],
    );
  }

  Widget _row(String label, String value, {bool mono = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: AppColors.mutedForeground),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFamily: mono ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  _StatusConfig _statusFor(String status) {
    switch (status) {
      case 'PENDING':
        return _StatusConfig(
          icon: Icons.schedule,
          label: 'Pending',
          color: AppColors.mutedForeground,
        );
      case 'PROCESSING':
        return _StatusConfig(
          icon: Icons.hourglass_top,
          label: 'Processing',
          color: AppColors.primary,
        );
      case 'SUCCESS':
        return const _StatusConfig(
          icon: Icons.check_circle,
          label: 'Success',
          color: Color(0xFF15803D),
        );
      case 'FAILED':
        return _StatusConfig(
          icon: Icons.cancel,
          label: 'Failed',
          color: AppColors.destructive,
        );
      case 'REFUNDED':
        return _StatusConfig(
          icon: Icons.replay_circle_filled_outlined,
          label: 'Refunded',
          color: AppColors.mutedForeground,
        );
      default:
        return _StatusConfig(
          icon: Icons.info_outline,
          label: status,
          color: AppColors.mutedForeground,
        );
    }
  }
}

class _StatusConfig {
  const _StatusConfig({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;
}

String _formatDateTime(String iso) {
  final dt = DateTime.tryParse(iso);
  if (dt == null) return iso;
  return DateFormat('MMM dd, yyyy HH:mm').format(dt.toLocal());
}
