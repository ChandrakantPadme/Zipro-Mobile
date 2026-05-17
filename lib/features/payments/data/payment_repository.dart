import 'package:dio/dio.dart';

import '../../../core/models/api_models.dart';
import '../../../core/models/delivery_models.dart';
import '../../../core/network/api_endpoints.dart';

class PaymentRepository {
  PaymentRepository(this._dio);

  final Dio _dio;

  Future<ApiResponse<RazorpayOrderDto?>> createPaymentOrder(
      String orderId) async {
    final res = await _dio.post<dynamic>(
      ApiEndpoints.payments.create,
      data: {'orderId': orderId},
    );
    final body = res.data;
    Map<String, dynamic>? m;
    if (body is Map<String, dynamic>) {
      if (body['razorpayOrderId'] != null || body['amount'] != null) {
        m = body;
      } else if (body['data'] is Map<String, dynamic>) {
        m = body['data'] as Map<String, dynamic>;
      }
    }
    if (m != null) {
      return ApiResponse(
        success: true,
        message: body is Map<String, dynamic>
            ? body['message'] as String? ?? 'OK'
            : 'OK',
        data: RazorpayOrderDto.fromJson(m),
      );
    }
    return ApiResponse(
      success: body is Map<String, dynamic>
          ? body['success'] as bool? ?? false
          : false,
      message:
          body is Map<String, dynamic> ? body['message'] as String? ?? '' : '',
      data: null,
    );
  }

  Future<ApiResponse<void>> verifyPayment({
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.payments.verify,
      data: {
        'razorpayOrderId': razorpayOrderId,
        'razorpayPaymentId': razorpayPaymentId,
        'razorpaySignature': razorpaySignature,
      },
    );
    final body = res.data ?? {};
    return ApiResponse(
      success: body['success'] as bool? ?? true,
      message: body['message'] as String? ?? '',
      data: null,
    );
  }

  Future<PaymentDto?> getPaymentByOrder(String orderId) async {
    try {
      final res =
          await _dio.get<dynamic>(ApiEndpoints.payments.getByOrderId(orderId));
      final body = res.data;
      Map<String, dynamic>? m;
      if (body is Map<String, dynamic> && body['paymentId'] != null) {
        m = body;
      } else if (body is Map<String, dynamic>) {
        final d = body['data'];
        if (d is Map<String, dynamic>) m = d;
      }
      return m != null ? PaymentDto.fromJson(m) : null;
    } on DioException {
      return null;
    }
  }
}
