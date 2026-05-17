// DTOs aligned with zipro_website_new/lib/api/types.ts (subset + flexible fromJson).

List<String> _stringListFromJson(dynamic v) {
  if (v is! List) return const [];
  return v
      .map((e) => e is String ? e : '$e')
      .where((s) => s.isNotEmpty)
      .toList();
}

class ShipmentAddressesDto {
  ShipmentAddressesDto({
    this.originAddressText,
    this.destinationAddressText,
    this.originContactName,
    this.originContactPhone,
    this.destinationContactName,
    this.destinationContactPhone,
  });

  final String? originAddressText;
  final String? destinationAddressText;
  final String? originContactName;
  final String? originContactPhone;
  final String? destinationContactName;
  final String? destinationContactPhone;

  factory ShipmentAddressesDto.fromJson(Map<String, dynamic> j) {
    return ShipmentAddressesDto(
      originAddressText: j['originAddressText'] as String?,
      destinationAddressText: j['destinationAddressText'] as String?,
      originContactName: j['originContactName'] as String?,
      originContactPhone: j['originContactPhone'] as String?,
      destinationContactName: j['destinationContactName'] as String?,
      destinationContactPhone: j['destinationContactPhone'] as String?,
    );
  }
}

class OrderItemDto {
  OrderItemDto({
    this.itemId,
    required this.itemDescription,
    required this.quantity,
    this.itemValueAmount,
    this.productLink,
  });

  final String? itemId;
  final String itemDescription;
  final num quantity;
  final num? itemValueAmount;
  final String? productLink;

  factory OrderItemDto.fromJson(Map<String, dynamic> j) {
    return OrderItemDto(
      itemId: j['itemId'] as String?,
      itemDescription: j['itemDescription'] as String? ?? '',
      quantity: j['quantity'] as num? ?? 0,
      itemValueAmount: j['itemValueAmount'] as num?,
      productLink: j['productLink'] as String?,
    );
  }
}

List<OrderItemDto> _itemsFromJson(dynamic v) {
  if (v is! List) return const [];
  return v
      .whereType<Map<String, dynamic>>()
      .map(OrderItemDto.fromJson)
      .toList();
}

class ShipmentOrderDto {
  ShipmentOrderDto({
    required this.orderId,
    this.shipmentId,
    this.tripId,
    this.senderUserId,
    this.travelerUserId,
    this.shipmentType,
    this.latestDeliveryDate,
    this.productLinks = const [],
    this.items = const [],
    this.receiverName,
    this.receiverPhone,
    this.addresses,
    required this.originCity,
    required this.originCountryCode,
    required this.destinationCity,
    required this.destinationCountryCode,
    required this.description,
    required this.status,
    this.deliveryMilestone,
    this.declaredValueAmount,
    this.currency,
    this.weightKg,
    this.total,
    this.createdAt,
    this.subtotal,
    this.travelerFee,
    this.travelerFeeCurrency,
    this.deliveryFee,
    this.weightFare,
    this.secureFee,
    this.totalAmountToPay,
  });

  final String orderId;
  final String? shipmentId;
  final String? tripId;
  final String? senderUserId;
  final String? travelerUserId;
  final String? shipmentType;
  final String? latestDeliveryDate;
  final List<String> productLinks;
  final List<OrderItemDto> items;
  final String? receiverName;
  final String? receiverPhone;
  final ShipmentAddressesDto? addresses;
  final String originCity;
  final String originCountryCode;
  final String destinationCity;
  final String destinationCountryCode;
  final String description;
  final String status;

  /// Carrier-side delivery milestone ("PICKED_UP", "IN_TRANSIT", "DELIVERED").
  final String? deliveryMilestone;
  final num? declaredValueAmount;
  final String? currency;
  final num? weightKg;
  final num? total;
  final String? createdAt;
  final num? subtotal;
  final num? travelerFee;
  final String? travelerFeeCurrency;
  final num? deliveryFee;
  final num? weightFare;
  final num? secureFee;
  final num? totalAmountToPay;

  factory ShipmentOrderDto.fromJson(Map<String, dynamic> j) {
    final oid = j['orderId'] as String? ?? j['shipmentId'] as String? ?? '';
    final sid = j['shipmentId'] as String?;
    final addrRaw = j['addresses'];
    return ShipmentOrderDto(
      orderId: oid,
      shipmentId: sid ?? (oid.isNotEmpty ? oid : null),
      tripId: j['tripId'] as String?,
      senderUserId: j['senderUserId'] as String?,
      travelerUserId: j['travelerUserId'] as String?,
      shipmentType: j['shipmentType'] as String?,
      latestDeliveryDate: j['latestDeliveryDate'] as String?,
      productLinks: _stringListFromJson(j['productLinks']),
      items: _itemsFromJson(j['items']),
      receiverName: j['receiverName'] as String?,
      receiverPhone: j['receiverPhone'] as String?,
      addresses: addrRaw is Map<String, dynamic>
          ? ShipmentAddressesDto.fromJson(addrRaw)
          : null,
      originCity: j['originCity'] as String? ?? '',
      originCountryCode: j['originCountryCode'] as String? ?? '',
      destinationCity: j['destinationCity'] as String? ?? '',
      destinationCountryCode: j['destinationCountryCode'] as String? ?? '',
      description: j['description'] as String? ?? '',
      status: j['status'] as String? ?? '',
      deliveryMilestone: j['deliveryMilestone'] as String?,
      declaredValueAmount: j['declaredValueAmount'] as num?,
      currency: j['currency'] as String?,
      weightKg: j['weightKg'] as num?,
      total: j['total'] as num?,
      createdAt: j['createdAt'] as String?,
      subtotal: j['subtotal'] as num?,
      travelerFee: j['travelerFee'] as num?,
      travelerFeeCurrency: j['travelerFeeCurrency'] as String?,
      deliveryFee: j['deliveryFee'] as num?,
      weightFare: j['weightFare'] as num?,
      secureFee: j['secureFee'] as num?,
      totalAmountToPay: j['totalAmountToPay'] as num?,
    );
  }

  String get primaryId =>
      shipmentId?.isNotEmpty == true ? shipmentId! : orderId;
}

class TripDto {
  TripDto({
    required this.tripId,
    this.travelerUserId,
    required this.fromCity,
    required this.fromCountryCode,
    required this.toCity,
    required this.toCountryCode,
    required this.departAt,
    required this.status,
    this.capacityWeightKg,
    this.capacityValueLimit,
    this.usedWeightKg,
    this.usedValue,
    this.airline,
    this.flightNumber,
    this.arriveAt,
  });

  final String tripId;

  /// Present on full trip details / API; used for owner checks (see web trip page).
  final String? travelerUserId;
  final String fromCity;
  final String fromCountryCode;
  final String toCity;
  final String toCountryCode;
  final String departAt;
  final String status;
  final num? capacityWeightKg;
  final num? capacityValueLimit;
  final num? usedWeightKg;
  final num? usedValue;
  final String? airline;
  final String? flightNumber;
  final String? arriveAt;

  factory TripDto.fromJson(Map<String, dynamic> j) {
    return TripDto(
      tripId: j['tripId'] as String? ?? '',
      travelerUserId: j['travelerUserId'] as String?,
      fromCity: j['fromCity'] as String? ?? '',
      fromCountryCode: j['fromCountryCode'] as String? ?? '',
      toCity: j['toCity'] as String? ?? '',
      toCountryCode: j['toCountryCode'] as String? ?? '',
      departAt: j['departAt'] as String? ?? '',
      status: j['status'] as String? ?? '',
      capacityWeightKg: j['capacityWeightKg'] as num?,
      capacityValueLimit: j['capacityValueLimit'] as num?,
      usedWeightKg: j['usedWeightKg'] as num?,
      usedValue: j['usedValue'] as num?,
      airline: j['airline'] as String?,
      flightNumber: j['flightNumber'] as String?,
      arriveAt: j['arriveAt'] as String?,
    );
  }
}

class TripOfferDto {
  TripOfferDto({
    required this.offerId,
    required this.tripId,
    required this.status,
    this.capacityWeightKg,
    this.capacityValueLimit,
    this.remainingWeightKg,
    this.remainingValue,
  });

  final String offerId;
  final String tripId;
  final String status;
  final num? capacityWeightKg;
  final num? capacityValueLimit;
  final num? remainingWeightKg;
  final num? remainingValue;

  factory TripOfferDto.fromJson(Map<String, dynamic> j) {
    return TripOfferDto(
      offerId: j['offerId'] as String? ?? '',
      tripId: j['tripId'] as String? ?? '',
      status: j['status'] as String? ?? '',
      capacityWeightKg: j['capacityWeightKg'] as num?,
      capacityValueLimit: j['capacityValueLimit'] as num?,
      remainingWeightKg: j['remainingWeightKg'] as num?,
      remainingValue: j['remainingValue'] as num?,
    );
  }
}

num? _nullableJsonNum(dynamic v) {
  if (v == null) return null;
  if (v is num) return v;
  if (v is String) return num.tryParse(v);
  return null;
}

num _jsonNum(dynamic v, [num fallback = 0]) => _nullableJsonNum(v) ?? fallback;

class MatchDto {
  MatchDto({
    required this.matchId,
    this.shipmentId,
    this.tripId,
    this.orderId,
    required this.travelerUserId,
    required this.status,
    required this.agreedFee,
    this.currency,
    this.weightKg,
    this.declaredValueAmount,
    this.declaredValueCurrency,
    this.carrierOriginAddressText,
    this.carrierDestinationAddressText,
  });

  final String matchId;
  final String? shipmentId;
  final String? tripId;
  final String? orderId;
  final String travelerUserId;
  final String status;
  final num agreedFee;
  final String? currency;
  final num? weightKg;
  final num? declaredValueAmount;
  final String? declaredValueCurrency;
  final String? carrierOriginAddressText;
  final String? carrierDestinationAddressText;

  factory MatchDto.fromJson(Map<String, dynamic> j) {
    return MatchDto(
      matchId: j['matchId'] as String? ?? '',
      shipmentId: j['shipmentId'] as String?,
      tripId: j['tripId'] as String?,
      orderId: j['orderId'] as String?,
      travelerUserId: j['travelerUserId'] as String? ?? '',
      status: () {
        final s = j['status'];
        if (s is String) return s;
        return s?.toString() ?? '';
      }(),
      agreedFee: _jsonNum(j['agreedFee']),
      currency: j['currency'] as String?,
      weightKg: _nullableJsonNum(j['weightKg']),
      declaredValueAmount: _nullableJsonNum(j['declaredValueAmount']),
      declaredValueCurrency: j['declaredValueCurrency'] as String?,
      carrierOriginAddressText: j['carrierOriginAddressText'] as String?,
      carrierDestinationAddressText:
          j['carrierDestinationAddressText'] as String?,
    );
  }
}

class MatchableCarrierDto {
  MatchableCarrierDto({
    required this.tripId,
    required this.travelerUserId,
    required this.carrierName,
    required this.agreedFee,
    required this.currency,
    required this.fromCity,
    required this.toCity,
    required this.departAt,
    this.fromCountryCode,
    this.toCountryCode,
    this.airline,
    this.flightNumber,
    this.isVerified,
    this.completedDeliveries,
  });

  final String tripId;
  final String travelerUserId;
  final String carrierName;
  final num agreedFee;
  final String currency;
  final String fromCity;
  final String toCity;
  final String departAt;
  final String? fromCountryCode;
  final String? toCountryCode;
  final String? airline;
  final String? flightNumber;
  final bool? isVerified;
  final int? completedDeliveries;

  factory MatchableCarrierDto.fromJson(Map<String, dynamic> j) {
    return MatchableCarrierDto(
      tripId: j['tripId'] as String? ?? '',
      travelerUserId: j['travelerUserId'] as String? ?? '',
      carrierName: j['carrierName'] as String? ?? '',
      agreedFee: j['agreedFee'] as num? ?? 0,
      currency: j['currency'] as String? ?? 'INR',
      fromCity: j['fromCity'] as String? ?? '',
      toCity: j['toCity'] as String? ?? '',
      departAt: j['departAt'] as String? ?? '',
      fromCountryCode: j['fromCountryCode'] as String?,
      toCountryCode: j['toCountryCode'] as String?,
      airline: j['airline'] as String?,
      flightNumber: j['flightNumber'] as String?,
      isVerified: j['isVerified'] as bool?,
      completedDeliveries: (j['completedDeliveries'] as num?)?.toInt(),
    );
  }
}

class RazorpayOrderDto {
  RazorpayOrderDto({
    this.paymentId,
    this.orderId,
    this.razorpayOrderId,
    required this.amount,
    required this.currency,
    this.razorpayKeyId,
    this.customerName,
    this.customerEmail,
    this.customerPhone,
    this.description,
  });

  final String? paymentId;
  final String? orderId;
  final String? razorpayOrderId;
  final num amount;
  final String currency;
  final String? razorpayKeyId;
  final String? customerName;
  final String? customerEmail;
  final String? customerPhone;
  final String? description;

  factory RazorpayOrderDto.fromJson(Map<String, dynamic> j) {
    return RazorpayOrderDto(
      paymentId: j['paymentId'] as String?,
      orderId: j['orderId'] as String?,
      razorpayOrderId: j['razorpayOrderId'] as String? ?? j['id'] as String?,
      amount: j['amount'] as num? ?? 0,
      currency: j['currency'] as String? ?? 'INR',
      razorpayKeyId: j['razorpayKeyId'] as String?,
      customerName: j['customerName'] as String?,
      customerEmail: j['customerEmail'] as String?,
      customerPhone: j['customerPhone'] as String?,
      description: j['description'] as String?,
    );
  }

  String get razorpayOrderIdOrId => razorpayOrderId ?? '';
}

/// GET /v1/payments/order/{orderId}
class PaymentDto {
  PaymentDto({
    required this.paymentId,
    required this.orderId,
    required this.status,
    this.amount,
    this.currency,
    this.paymentMethod,
    this.transactionId,
    this.razorpayPaymentId,
    this.razorpayOrderId,
    this.failureReason,
    this.createdAt,
  });

  final String paymentId;
  final String orderId;
  final String status;
  final num? amount;
  final String? currency;
  final String? paymentMethod;
  final String? transactionId;
  final String? razorpayPaymentId;
  final String? razorpayOrderId;
  final String? failureReason;
  final String? createdAt;

  factory PaymentDto.fromJson(Map<String, dynamic> j) {
    return PaymentDto(
      paymentId: j['paymentId'] as String? ?? '',
      orderId: j['orderId'] as String? ?? '',
      status: j['status'] as String? ?? '',
      amount: j['amount'] as num?,
      currency: j['currency'] as String?,
      paymentMethod: j['paymentMethod'] as String?,
      transactionId: j['transactionId'] as String?,
      razorpayPaymentId: j['razorpayPaymentId'] as String?,
      razorpayOrderId: j['razorpayOrderId'] as String?,
      failureReason: j['failureReason'] as String?,
      createdAt: j['createdAt'] as String?,
    );
  }
}
