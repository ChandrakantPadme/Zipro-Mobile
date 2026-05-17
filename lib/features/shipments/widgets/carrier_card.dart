import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/models/delivery_models.dart';
import '../../../core/theme/app_theme.dart';

/// Mirrors [zipro_website_new/components/carrier/carrier-card.tsx].
class CarrierCard extends StatelessWidget {
  const CarrierCard({
    super.key,
    required this.carrier,
    required this.onSelect,
    required this.isCreating,
  });

  final MatchableCarrierDto carrier;
  final VoidCallback onSelect;
  final bool isCreating;

  @override
  Widget build(BuildContext context) {
    final from =
        carrier.fromCountryCode != null && carrier.fromCountryCode!.isNotEmpty
            ? '${carrier.fromCity}, ${carrier.fromCountryCode}'
            : carrier.fromCity;
    final to =
        carrier.toCountryCode != null && carrier.toCountryCode!.isNotEmpty
            ? '${carrier.toCity}, ${carrier.toCountryCode}'
            : carrier.toCity;
    final dateLabel = _formatDepart(carrier.departAt);
    final hasFlight = (carrier.airline ?? '').isNotEmpty ||
        (carrier.flightNumber ?? '').isNotEmpty;
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
            Container(width: 4, color: AppColors.primary),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 460;
            final info = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      carrier.carrierName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    if (carrier.isVerified == true)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified_user_outlined,
                                size: 12, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(
                              'Verified',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if ((carrier.completedDeliveries ?? 0) > 0)
                      Text(
                        '${carrier.completedDeliveries} deliveries',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                _IconLine(
                  icon: Icons.place_outlined,
                  text: '$from → $to',
                ),
                const SizedBox(height: 4),
                _IconLine(
                  icon: Icons.calendar_today_outlined,
                  text: dateLabel,
                ),
                if (hasFlight) ...[
                  const SizedBox(height: 4),
                  _IconLine(
                    icon: Icons.flight_takeoff,
                    text: [
                      if ((carrier.airline ?? '').isNotEmpty) carrier.airline!,
                      if ((carrier.flightNumber ?? '').isNotEmpty)
                        '· ${carrier.flightNumber}',
                    ].join(' '),
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.payments_outlined,
                        size: 14, color: AppColors.mutedForeground),
                    const SizedBox(width: 6),
                    Text(
                      '${carrier.currency} ${carrier.agreedFee}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            );
            final cta = SizedBox(
              width: wide ? null : double.infinity,
              child: FilledButton(
                onPressed: isCreating ? null : onSelect,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.accentForeground,
                ),
                child: Text(isCreating ? 'Selecting…' : 'Select carrier'),
              ),
            );
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: info),
                  const SizedBox(width: 12),
                  cta,
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [info, const SizedBox(height: 12), cta],
            );
          },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDepart(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return DateFormat('MMM dd, yyyy').format(dt.toLocal());
  }
}

class _IconLine extends StatelessWidget {
  const _IconLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: AppColors.mutedForeground),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.mutedForeground,
            ),
          ),
        ),
      ],
    );
  }
}
