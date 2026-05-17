import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/delivery_models.dart';
import '../../core/network/dio_error_mapper.dart';
import '../../core/theme/app_theme.dart';
import '../kyc/widgets/kyc_required_dialog.dart';
import '../repositories_providers.dart';
import 'shipment_detail_screen.dart' show shipmentDetailProvider;
import 'widgets/carrier_card.dart';

/// Mirrors [zipro_website_new/app/(app)/shipments/[shipmentId]/carriers/page.tsx].
class ShipmentCarriersScreen extends ConsumerStatefulWidget {
  const ShipmentCarriersScreen({super.key, required this.shipmentId});

  final String shipmentId;

  @override
  ConsumerState<ShipmentCarriersScreen> createState() =>
      _ShipmentCarriersScreenState();
}

class _ShipmentCarriersScreenState
    extends ConsumerState<ShipmentCarriersScreen> {
  String? _busyTripId;

  Future<void> _selectCarrier(String tripId) async {
    if (_busyTripId != null) return;
    setState(() => _busyTripId = tripId);
    final repo = ref.read(matchRepositoryProvider);
    try {
      final res = await repo.createMatch(
        shipmentId: widget.shipmentId,
        tripId: tripId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(res.message.isNotEmpty
                ? res.message
                : 'Request sent to carrier')),
      );
      if (res.success) {
        context.go('/shipment/${widget.shipmentId}');
      }
    } catch (e) {
      if (!mounted) return;
      if (isKycRequiredError(e)) {
        await showKycRequiredDialog(context, actionLabel: 'choose a traveller');
        return;
      }
      final msg = e is DioException ? dioErrorMessage(e) : '$e';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _busyTripId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncCarriers = ref.watch(_carriersProvider(widget.shipmentId));
    final asyncShipment = ref.watch(shipmentDetailProvider(widget.shipmentId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose carrier'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/shipment/${widget.shipmentId}');
            }
          },
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(_carriersProvider(widget.shipmentId));
        },
        child: asyncCarriers.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorView(message: dioErrorMessage(e)),
          data: (carriers) {
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Choose a carrier',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Select a traveller whose trip matches your order route.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 16),
                if (carriers.isEmpty)
                  _EmptyCarriersCard(
                    shipment: asyncShipment.asData?.value,
                    onBack: () => context.go('/shipment/${widget.shipmentId}'),
                  )
                else
                  ...carriers.map(
                    (c) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: CarrierCard(
                        carrier: c,
                        isCreating: _busyTripId == c.tripId,
                        onSelect: () => _selectCarrier(c.tripId),
                      ),
                    ),
                  ),
                const SizedBox(height: 32),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _EmptyCarriersCard extends StatelessWidget {
  const _EmptyCarriersCard({this.shipment, required this.onBack});

  final ShipmentOrderDto? shipment;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final origin = shipment?.originCity ?? '—';
    final dest = shipment?.destinationCity ?? '—';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.flight_takeoff,
                size: 48, color: AppColors.mutedForeground),
            const SizedBox(height: 12),
            const Text(
              'Carriers on your route',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Your order route: $origin → $dest',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Carriers will show here when a traveller creates a trip on the same route (same origin and destination).',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onBack,
              child: const Text('Back to order'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.mutedForeground)),
      ),
    );
  }
}

final _carriersProvider = FutureProvider.family
    .autoDispose<List<MatchableCarrierDto>, String>((ref, shipmentId) async {
  final r = ref.watch(shipmentRepositoryProvider);
  return r.getMatchableCarriers(shipmentId);
});
