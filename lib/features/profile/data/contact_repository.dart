import 'package:dio/dio.dart';

import '../../../core/env/app_config.dart';
import '../../../core/models/api_models.dart';
import '../../../core/network/api_endpoints.dart';

class ContactRepository {
  Future<ApiResponse<void>> submit({
    required String name,
    required String email,
    String? phone,
    required String message,
  }) async {
    final plain = Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl,
        headers: const {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      ),
    );
    final res = await plain.post<Map<String, dynamic>>(
      ApiEndpoints.contact.submit,
      data: {
        'name': name,
        'email': email,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        'message': message,
      },
    );
    final body = res.data ?? {};
    return ApiResponse(
      success: body['success'] as bool? ?? false,
      message: body['message'] as String? ?? '',
      data: null,
    );
  }
}
