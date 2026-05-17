import 'package:dio/dio.dart';

import '../../../core/models/api_models.dart';
import '../../../core/models/kyc_dto.dart';
import '../../../core/network/api_endpoints.dart';

class KycRepository {
  KycRepository(this._dio);

  final Dio _dio;

  /// Mirrors [kycFromApiResponse] — no usable row without non-empty `kycId`.
  Future<KycDto?> fetchMyKyc() async {
    try {
      final res = await _dio.get<dynamic>(ApiEndpoints.kyc.getMy);
      final body = res.data;
      Map<String, dynamic>? map;
      if (body is Map<String, dynamic>) {
        final id = body['kycId'];
        if (id is String && id.isNotEmpty) {
          map = body;
        } else {
          final wrapped = body['data'];
          if (wrapped is Map<String, dynamic>) {
            final wid = wrapped['kycId'];
            if (wid is String && wid.isNotEmpty) map = wrapped;
          }
        }
      }
      if (map == null) return null;
      return KycDto.fromJson(map);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<ApiResponse<KycDto?>> createKyc(CreateKycPayload payload) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.kyc.create,
        data: payload.toJson(),
      );
      final body = res.data ?? {};

      // Spring returns [KycResponse] as the JSON body (kycId at top level), not
      // { success, message, data }.
      final directId = body['kycId'];
      if (directId is String && directId.isNotEmpty) {
        return ApiResponse<KycDto?>(
          success: true,
          message: body['message'] as String? ?? '',
          data: KycDto.fromJson(body),
        );
      }

      final wrapped = body['data'];
      if (wrapped is Map<String, dynamic>) {
        final wid = wrapped['kycId'];
        if (wid is String && wid.isNotEmpty) {
          return ApiResponse<KycDto?>(
            success: body['success'] as bool? ?? true,
            message: body['message'] as String? ?? '',
            data: KycDto.fromJson(wrapped),
          );
        }
      }

      final success = body['success'] as bool? ?? false;
      final msg = body['message'] as String? ?? '';
      return ApiResponse<KycDto?>(success: success, message: msg, data: null);
    } on DioException catch (e) {
      return ApiResponse<KycDto?>(
        success: false,
        message: _messageFromDio(e),
        data: null,
      );
    }
  }
}

String _messageFromDio(DioException e) {
  final data = e.response?.data;
  if (data is Map<String, dynamic>) {
    final m = data['message'];
    if (m is String && m.isNotEmpty) return m;
    final detail = data['detail'];
    if (detail is String && detail.isNotEmpty) return detail;
    final error = data['error'];
    if (error is String && error.isNotEmpty) return error;
  }
  if (data is String && data.isNotEmpty) return data;
  return e.message ?? 'Request failed';
}

