import '../../core/models/delivery_models.dart';

/// Same logic as [zipro_website_new/app/(app)/shipments/[shipmentId]/page.tsx] `tripMatchesShipment`.
bool tripMatchesShipment(ShipmentOrderDto shipment, TripDto trip) {
  final isDutyFree = shipment.shipmentType == 'DUTY_FREE_SHOPPING';
  late final bool routeMatch;
  if (isDutyFree &&
      shipment.destinationCity.isNotEmpty &&
      shipment.destinationCountryCode.isNotEmpty) {
    routeMatch = trip.toCity == shipment.destinationCity &&
        trip.toCountryCode == shipment.destinationCountryCode;
  } else {
    final hasCityPair = shipment.originCity.isNotEmpty &&
        shipment.originCountryCode.isNotEmpty &&
        shipment.destinationCity.isNotEmpty &&
        shipment.destinationCountryCode.isNotEmpty;
    routeMatch = hasCityPair
        ? trip.fromCity == shipment.originCity &&
            trip.fromCountryCode == shipment.originCountryCode &&
            trip.toCity == shipment.destinationCity &&
            trip.toCountryCode == shipment.destinationCountryCode
        : trip.fromCountryCode == shipment.originCountryCode &&
            trip.toCountryCode == shipment.destinationCountryCode;
  }
  final availWeight = (trip.capacityWeightKg ?? 0) - (trip.usedWeightKg ?? 0);
  final weightOk = availWeight >= (shipment.weightKg ?? 0);
  final availValue = (trip.capacityValueLimit ?? 0) - (trip.usedValue ?? 0);
  final valueOk = availValue >= (shipment.declaredValueAmount ?? 0);
  return routeMatch && weightOk && valueOk;
}

TripDto? findFirstMatchingPlannedTrip(
  ShipmentOrderDto shipment,
  List<TripDto> trips,
) {
  for (final t in trips) {
    if (tripMatchesShipment(shipment, t)) {
      return t;
    }
  }
  return null;
}
