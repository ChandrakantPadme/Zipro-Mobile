/// Mirrors [zipro_website_new/lib/api/config.ts] — keep in sync with backend.
class ApiEndpoints {
  ApiEndpoints._();

  static const auth = _AuthEndpoints();
  static const trips = _TripEndpoints();
  static const tripOffers = _TripOfferEndpoints();
  static const shipments = _ShipmentEndpoints();
  static const matches = _MatchEndpoints();
  static const orders = _OrderEndpoints();
  static const kyc = _KycEndpoints();
  static const s3 = _S3Endpoints();
  static const payments = _PaymentEndpoints();
  static const users = _UserEndpoints();
  static const contact = _ContactEndpoints();
}

class _AuthEndpoints {
  const _AuthEndpoints();

  String get signup => '/auth/signup/request';
  String get signupVerifyOtp => '/auth/signup/verify';
  String get loginOtpRequest => '/auth/otp/request';
  String get loginVerifyOtp => '/auth/otp/verify';
  String get logout => '/auth/logout';
  String get me => '/auth/me';
}

class _TripEndpoints {
  const _TripEndpoints();

  String get create => '/v1/trips';
  String getById(String tripId) => '/v1/trips/$tripId';
  String update(String tripId) => '/v1/trips/$tripId';
  String delete(String tripId) => '/v1/trips/$tripId';
  String get my => '/v1/trips/my';
  String get search => '/v1/trips/search';
  String get available => '/v1/trips/available';
  String start(String tripId) => '/v1/trips/$tripId/start';
  String acceptShipment(String tripId) => '/v1/trips/$tripId/accept-shipment';
}

class _TripOfferEndpoints {
  const _TripOfferEndpoints();

  String create(String tripId) => '/v1/trips/$tripId/offers';
  String getForTrip(String tripId) => '/v1/trips/$tripId/offers';
  String getOpenForTrip(String tripId) => '/v1/trips/$tripId/offers/open';
  String getById(String offerId) => '/v1/trips/offers/$offerId';
  String update(String offerId) => '/v1/trips/offers/$offerId';
  String delete(String offerId) => '/v1/trips/offers/$offerId';
  String get my => '/v1/trips/offers/my';
  String get search => '/v1/trips/offers/search';
}

class _ShipmentEndpoints {
  const _ShipmentEndpoints();

  String get create => '/v1/shipments';
  String getById(String shipmentId) => '/v1/shipments/$shipmentId';
  String update(String shipmentId) => '/v1/shipments/$shipmentId';
  String delete(String shipmentId) => '/v1/shipments/$shipmentId';
  String get my => '/v1/shipments/my';
  String get available => '/v1/shipments/available';
  String get search => '/v1/shipments/search';
  String get searchByCities => '/v1/shipments/search/cities';
  String matchableCarriers(String shipmentId) =>
      '/v1/shipments/$shipmentId/matchable-carriers';
}

class _MatchEndpoints {
  const _MatchEndpoints();

  String get create => '/v1/matches';
  String getById(String matchId) => '/v1/matches/$matchId';
  String accept(String matchId) => '/v1/matches/$matchId/accept';
  String reject(String matchId) => '/v1/matches/$matchId/reject';
  String cancel(String matchId) => '/v1/matches/$matchId/cancel';
  String getForShipment(String shipmentId) =>
      '/v1/matches/shipment/$shipmentId';
  String getForTrip(String tripId) => '/v1/matches/trip/$tripId';
  String getForOffer(String offerId) => '/v1/matches/offer/$offerId';
  String carrierAddresses(String matchId) =>
      '/v1/matches/$matchId/carrier-addresses';
  String get my => '/v1/matches/my';
}

class _OrderEndpoints {
  const _OrderEndpoints();

  String get create => '/v1/orders';
  String getById(String orderId) => '/v1/orders/$orderId';
  String update(String orderId) => '/v1/orders/$orderId';
  String delete(String orderId) => '/v1/orders/$orderId';
  String getByShipment(String shipmentId) =>
      '/v1/orders/shipment/$shipmentId';
  String get myBuyer => '/v1/orders/my/buyer';
  String get myTraveler => '/v1/orders/my/traveler';
  String confirm(String orderId) => '/v1/orders/$orderId/confirm';
  String generateDeliveryOtp(String orderId) =>
      '/v1/orders/$orderId/delivery-otp/generate';
  String verifyDeliveryOtp(String orderId) =>
      '/v1/orders/$orderId/delivery-otp/verify';
  String documents(String orderId) => '/v1/orders/$orderId/documents';
  String invoice(String orderId) => '/v1/orders/$orderId/invoice';
  String markReceived(String orderId) => '/v1/orders/$orderId/mark-received';
  String markInTransit(String orderId) => '/v1/orders/$orderId/mark-in-transit';
  String markDelivered(String orderId) => '/v1/orders/$orderId/mark-delivered';
  String getByTrip(String tripId) => '/v1/orders/trip/$tripId';
  String get search => '/v1/orders/search';
  String get searchByCities => '/v1/orders/search/cities';
}

class _KycEndpoints {
  const _KycEndpoints();

  String get create => '/v1/kyc';
  String get update => '/v1/kyc';
  String get getMy => '/v1/kyc';
}

class _S3Endpoints {
  const _S3Endpoints();

  String get getUploadUrl => '/v1/s3/upload-url';
}

class _PaymentEndpoints {
  const _PaymentEndpoints();

  String get create => '/v1/payments';
  String get verify => '/v1/payments/verify';
  String getById(String paymentId) => '/v1/payments/$paymentId';
  String getByOrderId(String orderId) => '/v1/payments/order/$orderId';
  String checkoutWithToken(String orderId) =>
      '/v1/payments/order/$orderId/checkout';
  String get verifyWithToken => '/v1/payments/verify-with-token';
}

class _UserEndpoints {
  const _UserEndpoints();

  String trust(String userId) => '/v1/users/$userId/trust';
}

class _ContactEndpoints {
  const _ContactEndpoints();

  String get submit => '/v1/contact';
}
