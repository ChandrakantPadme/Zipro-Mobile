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
    final res = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.kyc.create,
      data: payload.toJson(),
    );
    final body = res.data ?? {};
    final success = body['success'] as bool? ?? false;
    final msg = body['message'] as String? ?? '';
    final data = body['data'];
    KycDto? kyc;
    if (data is Map<String, dynamic>) {
      kyc = KycDto.fromJson(data);
    }
    return ApiResponse<KycDto?>(success: success, message: msg, data: kyc);
  }
}
