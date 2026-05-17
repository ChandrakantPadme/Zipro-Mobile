import 'package:dio/dio.dart';

import '../../../core/models/api_models.dart';
import '../../../core/models/delivery_models.dart';
import '../../../core/network/api_endpoints.dart';

class OrderRepository {
  OrderRepository(this._dio);

  final Dio _dio;

  List<ShipmentOrderDto> _normalizeOrdersList(dynamic raw) {
    if (raw is List) {
      return raw
          .whereType<Map<String, dynamic>>()
          .map(ShipmentOrderDto.fromJson)
          .toList();
    }
    if (raw is Map<String, dynamic>) {
      for (final key in ['data', 'content', 'orders']) {
        final v = raw[key];
        if (v is List) {
          return v
              .whereType<Map<String, dynamic>>()
              .map(ShipmentOrderDto.fromJson)
              .toList();
        }
      }
    }
    return const [];
  }

  Future<List<ShipmentOrderDto>> getMyOrdersBuyer() async {
    final res = await _dio.get<dynamic>(ApiEndpoints.orders.myBuyer);
    return _normalizeOrdersList(res.data);
  }

  Future<List<ShipmentOrderDto>> getMyOrdersTraveler() async {
    final res = await _dio.get<dynamic>(ApiEndpoints.orders.myTraveler);
    return _normalizeOrdersList(res.data);
  }

  Future<ShipmentOrderDto?> getOrder(String orderId) async {
    final res = await _dio.get<dynamic>(ApiEndpoints.orders.getById(orderId));
    final body = res.data;
    if (body is Map<String, dynamic> && body['orderId'] != null) {
      return ShipmentOrderDto.fromJson(body);
    }
    if (body is Map<String, dynamic>) {
      final d = body['data'];
      if (d is Map<String, dynamic>) return ShipmentOrderDto.fromJson(d);
    }
    return null;
  }

  /// Returns the order tied to [shipmentId], or `null` when there is no order
  /// yet or the caller is not allowed to view it (mirrors web `useOrderByShipment`
  /// which simply renders nothing on 403/404).
  Future<ShipmentOrderDto?> getOrderByShipment(String shipmentId) async {
    try {
      final res = await _dio
          .get<dynamic>(ApiEndpoints.orders.getByShipment(shipmentId));
      final body = res.data;
      if (body is Map<String, dynamic> && body['orderId'] != null) {
        return ShipmentOrderDto.fromJson(body);
      }
      if (body is Map<String, dynamic>) {
        final d = body['data'];
        if (d is Map<String, dynamic>) return ShipmentOrderDto.fromJson(d);
      }
      return null;
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      if (status == 401 || status == 403 || status == 404) {
        return null;
      }
      rethrow;
    }
  }

  /// Returns the orders linked to [tripId]. Mirrors web `useOrdersByTrip`
  /// which falls back to an empty list on 401/403/404 (caller is not the
  /// trip owner or there are no orders yet).
  Future<List<ShipmentOrderDto>> getOrdersByTrip(String tripId) async {
    try {
      final res =
          await _dio.get<dynamic>(ApiEndpoints.orders.getByTrip(tripId));
      return _normalizeOrdersList(res.data);
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      if (status == 401 || status == 403 || status == 404) {
        return const [];
      }
      rethrow;
    }
  }

  /// POST /v1/orders/{id}/delivery-otp/generate — sends a 6-digit OTP to the
  /// sender's email so the carrier can use it on `markDelivered`.
  Future<ApiResponse<void>> generateDeliveryOtp(String orderId) async {
    final res = await _dio.post<dynamic>(
      ApiEndpoints.orders.generateDeliveryOtp(orderId),
      data: {'orderId': orderId},
    );
    final body = res.data;
    return ApiResponse(
      success: body is Map<String, dynamic>
          ? body['success'] as bool? ?? true
          : true,
      message:
          body is Map<String, dynamic> ? body['message'] as String? ?? '' : '',
      data: null,
    );
  }

  /// POST /v1/orders/{id}/confirm — used by the buyer to confirm a fulfilled
  /// order (moves it from CREATED → CONFIRMED).
  Future<ApiResponse<ShipmentOrderDto?>> confirmOrder(String orderId) async {
    final res = await _dio.post<dynamic>(
      ApiEndpoints.orders.confirm(orderId),
    );
    return _unwrapOrder(res.data);
  }

  /// GET /v1/orders/{id}/invoice — returns `{ invoiceUrl }` signed URL.
  Future<String?> getInvoiceUrl(String orderId) async {
    final res = await _dio.get<dynamic>(ApiEndpoints.orders.invoice(orderId));
    final body = res.data;
    if (body is Map<String, dynamic>) {
      final url = body['invoiceUrl'] as String?;
      if (url != null && url.isNotEmpty) return url;
      final inner = body['data'];
      if (inner is Map<String, dynamic>) {
        final innerUrl = inner['invoiceUrl'] as String?;
        if (innerUrl != null && innerUrl.isNotEmpty) return innerUrl;
      }
    }
    return null;
  }

  Future<ApiResponse<ShipmentOrderDto?>> markInTransit(String orderId) async {
    final res = await _dio.post<dynamic>(
      ApiEndpoints.orders.markInTransit(orderId),
      data: {},
    );
    return _unwrapOrder(res.data);
  }

  Future<ApiResponse<ShipmentOrderDto?>> markDelivered(
    String orderId, {
    required String otp,
    String? deliveryPhotoS3Key,
  }) async {
    final res = await _dio.post<dynamic>(
      ApiEndpoints.orders.markDelivered(orderId),
      data: {
        'otp': otp,
        if (deliveryPhotoS3Key != null)
          'deliveryPhotoS3Key': deliveryPhotoS3Key,
      },
    );
    return _unwrapOrder(res.data);
  }

  Future<ApiResponse<ShipmentOrderDto?>> markReceived(
    String orderId, {
    required String receiptS3Key,
    required bool carrierDeclarationAccepted,
  }) async {
    final res = await _dio.post<dynamic>(
      ApiEndpoints.orders.markReceived(orderId),
      data: {
        'receiptS3Key': receiptS3Key,
        'carrierDeclarationAccepted': carrierDeclarationAccepted,
      },
    );
    return _unwrapOrder(res.data);
  }

  Future<ApiResponse<ShipmentOrderDto?>> verifyDeliveryOtp(
    String orderId,
    String otp,
  ) async {
    final res = await _dio.post<dynamic>(
      ApiEndpoints.orders.verifyDeliveryOtp(orderId),
      data: {'orderId': orderId, 'otp': otp},
    );
    final body = res.data;
    if (body is Map<String, dynamic>) {
      return ApiResponse(
        success: body['success'] as bool? ?? true,
        message: body['message'] as String? ?? '',
        data: body['data'] is Map<String, dynamic>
            ? ShipmentOrderDto.fromJson(body['data'] as Map<String, dynamic>)
            : null,
      );
    }
    return const ApiResponse(
      success: false,
      message: 'Invalid response',
      data: null,
    );
  }

  ApiResponse<ShipmentOrderDto?> _unwrapOrder(dynamic body) {
    if (body is Map<String, dynamic> && body['orderId'] != null) {
      return ApiResponse(
        success: true,
        message: 'OK',
        data: ShipmentOrderDto.fromJson(body),
      );
    }
    if (body is Map<String, dynamic>) {
      final d = body['data'];
      return ApiResponse(
        success: body['success'] as bool? ?? true,
        message: body['message'] as String? ?? '',
        data: d is Map<String, dynamic> ? ShipmentOrderDto.fromJson(d) : null,
      );
    }
    return const ApiResponse(success: false, message: 'Invalid', data: null);
  }
}
