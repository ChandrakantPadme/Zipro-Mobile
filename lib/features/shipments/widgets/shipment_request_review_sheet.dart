import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/delivery_models.dart';
import '../../../core/network/dio_error_mapper.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/currency_rates.dart';
import '../../../data/supported_cities.dart';
import '../shipment_detail_screen.dart' show shipmentDetailProvider;

/// Mirrors [zipro_website_new/components/carrier/shipment-request-review-modal.tsx].
///
/// Read-only sheet for the trip owner to review a shipment before
/// accepting/rejecting an incoming match request. Includes a capacity
/// check that compares the shipment's weight + INR-converted declared value
/// against the trip's remaining capacity.
Future<void> showShipmentRequestReviewSheet(
  BuildContext context, {
  required String shipmentId,
  required TripDto trip,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ShipmentRequestReviewSheet(
      shipmentId: shipmentId,
      trip: trip,
    ),
  );
}

class _ShipmentRequestReviewSheet extends ConsumerWidget {
  const _ShipmentRequestReviewSheet({
    required this.shipmentId,
    required this.trip,
  });

  final String shipmentId;
  final TripDto trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(shipmentDetailProvider(shipmentId));
    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.inventory_2_outlined,
                        size: 22, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Order details',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Review origin, destination, weight, value and items. Accept only if you can carry this.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: async.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (e, _) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Text(
                        dioErrorMessage(e),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ),
                    data: (s) {
                      if (s == null) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Text(
                            'Could not load order details.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.mutedForeground,
                            ),
                          ),
                        );
                      }
                      return _Body(shipment: s, trip: trip);
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.shipment, required this.trip});

  final ShipmentOrderDto shipment;
  final TripDto trip;

  @override
  Widget build(BuildContext context) {
    final originLabel =
        cityCountryLabel(shipment.originCity, shipment.originCountryCode);
    final destLabel = cityCountryLabel(
        shipment.destinationCity, shipment.destinationCountryCode);
    final capacity = _capacityCheck(shipment, trip);
    final travellerFee = shipment.travelerFee ??
        ((shipment.totalAmountToPay ?? shipment.total ?? 0) * 0.85);
    final feeCurrency = shipment.travelerFeeCurrency ?? shipment.currency ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.place_outlined,
                size: 16, color: AppColors.mutedForeground),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '$originLabel  →  $destLabel',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _MetaCell(
                label: 'Weight',
                value:
                    shipment.weightKg != null ? '${shipment.weightKg} kg' : '—',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetaCell(
                label: 'Declared value',
                value: shipment.declaredValueAmount != null
                    ? '${shipment.currency ?? ''} ${shipment.declaredValueAmount}'
                    : '—',
              ),
            ),
          ],
        ),
        if (capacity != null) ...[
          const SizedBox(height: 16),
          _CapacityBanner(check: capacity),
        ],
        if (shipment.description.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Description',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.mutedForeground,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            shipment.description,
            style: const TextStyle(fontSize: 14),
          ),
        ],
        if (shipment.totalAmountToPay != null || shipment.total != null) ...[
          const SizedBox(height: 16),
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '$feeCurrency ${travellerFee.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  _CapacityResult? _capacityCheck(ShipmentOrderDto s, TripDto t) {
    if (t.capacityWeightKg == null || t.capacityValueLimit == null) {
      return null;
    }
    final remainingWeight = t.capacityWeightKg! - (t.usedWeightKg ?? 0);
    final remainingValue = t.capacityValueLimit! - (t.usedValue ?? 0);
    final shipmentValueInr = s.shipmentType == 'DUTY_FREE_SHOPPING'
        ? 0.0
        : convertToInr(s.declaredValueAmount ?? 0, s.currency);
    final fitsWeight = (s.weightKg ?? 0) <= remainingWeight;
    final fitsValue = shipmentValueInr <= remainingValue;
    return _CapacityResult(
      fitsWeight: fitsWeight,
      fitsValue: fitsValue,
    );
  }
}

class _MetaCell extends StatelessWidget {
  const _MetaCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.mutedForeground,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CapacityResult {
  const _CapacityResult({required this.fitsWeight, required this.fitsValue});

  final bool fitsWeight;
  final bool fitsValue;

  bool get fits => fitsWeight && fitsValue;
}

class _CapacityBanner extends StatelessWidget {
  const _CapacityBanner({required this.check});

  final _CapacityResult check;

  @override
  Widget build(BuildContext context) {
    final fits = check.fits;
    final color = fits ? AppColors.primary : AppColors.destructive;
    final icon = fits ? Icons.check_circle : Icons.warning_amber_rounded;
    String label;
    if (fits) {
      label = 'Fits in your capacity';
    } else {
      final parts = <String>[];
      if (!check.fitsWeight) parts.add('weight');
      if (!check.fitsValue) parts.add('value limit');
      label = 'Would exceed your capacity (${parts.join(' and ')})';
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
