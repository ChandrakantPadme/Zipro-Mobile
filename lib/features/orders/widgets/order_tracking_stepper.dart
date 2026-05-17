import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Mirrors [zipro_website_new/components/orders/order-tracking-stepper.tsx].
///
/// Three steps: Product received → In transit → Delivered. Highlights the
/// active step using the order [status] and carrier [deliveryMilestone].
class OrderTrackingStepper extends StatelessWidget {
  const OrderTrackingStepper({
    super.key,
    required this.status,
    this.deliveryMilestone,
  });

  final String status;
  final String? deliveryMilestone;

  @override
  Widget build(BuildContext context) {
    // Resolve the effective milestone the same way web does: prefer the
    // explicit milestone, fall back to the status when the carrier hasn't
    // updated milestone yet (e.g. CONFIRMED → null, IN_PROGRESS → PICKED_UP,
    // DELIVERED → DELIVERED).
    final milestone = deliveryMilestone ??
        (status == 'DELIVERED'
            ? 'DELIVERED'
            : status == 'IN_PROGRESS'
                ? 'PICKED_UP'
                : null);

    final steps = const [
      _StepDef(
        key: 'received',
        label: 'Product received',
        doneIf: ['PICKED_UP', 'IN_TRANSIT', 'DELIVERED'],
        icon: Icons.inventory_2_outlined,
      ),
      _StepDef(
        key: 'transit',
        label: 'In transit',
        doneIf: ['IN_TRANSIT', 'DELIVERED'],
        icon: Icons.local_shipping_outlined,
      ),
      _StepDef(
        key: 'delivered',
        label: 'Delivered',
        doneIf: ['DELIVERED'],
        icon: Icons.place_outlined,
      ),
    ];

    final currentIndex = milestone == 'PICKED_UP'
        ? 1
        : milestone == 'IN_TRANSIT'
            ? 2
            : milestone == 'DELIVERED'
                ? 3
                : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (var i = 0; i < steps.length; i++) ...[
              if (i > 0)
                Expanded(
                  child: _Connector(
                    active: milestone != null &&
                        steps[i - 1].doneIf.contains(milestone),
                  ),
                ),
              _StepDot(
                step: steps[i],
                isDone:
                    milestone != null && steps[i].doneIf.contains(milestone),
                isCurrent: !(milestone != null &&
                        steps[i].doneIf.contains(milestone)) &&
                    currentIndex == i + 1,
              ),
              if (i < steps.length - 1)
                Expanded(
                  child: _Connector(
                    active: milestone != null &&
                        steps[i].doneIf.contains(milestone),
                  ),
                ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final s in steps)
              Expanded(
                child: Builder(
                  builder: (_) {
                    final isDone =
                        milestone != null && s.doneIf.contains(milestone);
                    final isCurrent =
                        !isDone && currentIndex - 1 == steps.indexOf(s);
                    return Text(
                      s.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDone
                            ? AppColors.primary
                            : isCurrent
                                ? AppColors.foreground
                                : AppColors.mutedForeground,
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _StepDef {
  const _StepDef({
    required this.key,
    required this.label,
    required this.doneIf,
    required this.icon,
  });

  final String key;
  final String label;
  final List<String> doneIf;
  final IconData icon;
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.step,
    required this.isDone,
    required this.isCurrent,
  });

  final _StepDef step;
  final bool isDone;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final bg = isDone
        ? AppColors.primary
        : isCurrent
            ? AppColors.primary.withValues(alpha: 0.18)
            : AppColors.secondary;
    final fg = isDone
        ? AppColors.primaryForeground
        : isCurrent
            ? AppColors.primary
            : AppColors.mutedForeground;
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
      ),
      child: Icon(
        isDone ? Icons.check : step.icon,
        size: 16,
        color: fg,
      ),
    );
  }
}

class _Connector extends StatelessWidget {
  const _Connector({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 2,
      color: active ? AppColors.primary : AppColors.border,
    );
  }
}
