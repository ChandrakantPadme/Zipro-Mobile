import 'package:dio/dio.dart';

import '../../../core/env/app_config.dart';
import '../../../core/models/api_models.dart';
import '../../../core/network/api_endpoints.dart';

class AuthRepository {
  AuthRepository(this._dio);

  final Dio _dio;

  Future<ApiResponse<void>> requestLoginOtp(LoginOtpRequestPayload payload) async {
    final res = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.auth.loginOtpRequest,
      data: payload.toJson(),
    );
    final body = res.data ?? {};
    return ApiResponse<void>(
      success: body['success'] as bool? ?? false,
      message: body['message'] as String? ?? '',
      data: null,
    );
  }

  Future<ApiResponse<AuthTokens>> verifyLoginOtp(VerifyOtpPayload payload) async {
    final res = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.auth.loginVerifyOtp,
      data: payload.toJson(),
    );
    final body = res.data ?? {};
    final success = body['success'] as bool? ?? false;
    final data = body['data'];
    AuthTokens? tokens;
    if (data is Map<String, dynamic>) {
      tokens = AuthTokens.fromJson(data);
    }
    return ApiResponse<AuthTokens>(
      success: success,
      message: body['message'] as String? ?? '',
      data: tokens,
    );
  }

  Future<ApiResponse<UserProfile>> getCurrentUser() async {
    final res = await _dio.get<dynamic>(ApiEndpoints.auth.me);
    final body = res.data;
    if (body is Map<String, dynamic>) {
      if (body.containsKey('userId') && !body.containsKey('success')) {
        return ApiResponse<UserProfile>(
          success: true,
          message: 'OK',
          data: UserProfile.fromJson(body),
        );
      }
      return ApiResponse<UserProfile>.fromJson(
        body,
            (d) => d is Map<String, dynamic> ? UserProfile.fromJson(d) : null,
      );
    }
    return const ApiResponse<UserProfile>(
      success: false,
      message: 'Invalid response',
      data: null,
    );
  }

  Future<ApiResponse<void>> logout() async {
    final res = await _dio.post<Map<String, dynamic>>(ApiEndpoints.auth.logout);
    final body = res.data ?? {};
    return ApiResponse<void>(
      success: body['success'] as bool? ?? true,
      message: body['message'] as String? ?? '',
      data: null,
    );
  }

  Future<ApiResponse<void>> signupRequest(SignupRequestPayload payload) async {
    final res = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.auth.signup,
      data: payload.toJson(),
    );
    final body = res.data ?? {};
    return ApiResponse<void>(
      success: body['success'] as bool? ?? false,
      message: body['message'] as String? ?? '',
      data: null,
    );
  }

  /// Same OTP shape as login verify; backend path is signup verify.
  Future<ApiResponse<AuthTokens>> verifySignupOtp(VerifyOtpPayload payload) async {
    final res = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.auth.signupVerifyOtp,
      data: payload.toJson(),
    );
    final body = res.data ?? {};
    final success = body['success'] as bool? ?? false;
    final data = body['data'];
    AuthTokens? tokens;
    if (data is Map<String, dynamic>) {
      tokens = AuthTokens.fromJson(data);
    }
    return ApiResponse<AuthTokens>(
      success: success,
      message: body['message'] as String? ?? '',
      data: tokens,
    );
  }
}

Dio createAuthDio({
  required Future<String?> Function() getToken,
  required void Function() onUnauthorized,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: const {
        'Content-Type': 'application/json',
        // Required for free ngrok tier — skips the browser warning interstitial
        // that otherwise blocks API responses. Safe to keep even on prod backend.
        'ngrok-skip-browser-warning': 'true',
      },
    ),
  );

  // Auth + 401 handling
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await getToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (e, handler) {
        if (e.response?.statusCode == 401) {
          onUnauthorized();
        }
        return handler.next(e);
      },
    ),
  );

  // Debug logging — remove or wrap in `if (kDebugMode)` for release builds
  dio.interceptors.add(
    LogInterceptor(
      request: true,
      requestHeader: true,
      requestBody: true,
      responseHeader: false,
      responseBody: true,
      error: true,
    ),
  );

  return dio;
}