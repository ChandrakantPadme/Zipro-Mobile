import 'package:dio/dio.dart';

import '../../../core/models/api_models.dart';
import '../../../core/models/delivery_models.dart';
import '../../../core/network/api_endpoints.dart';

class MatchRepository {
  MatchRepository(this._dio);

  final Dio _dio;

  List<MatchDto> _listFrom(dynamic raw) {
    List<dynamic> list = const [];
    if (raw is List) list = raw;
    if (raw is Map<String, dynamic>) {
      final d = raw['data'];
      if (d is List) list = d;
    }
    return list
        .whereType<Map<String, dynamic>>()
        .map(MatchDto.fromJson)
        .toList();
  }

  Future<List<MatchDto>> getMyMatches() async {
    final res = await _dio.get<dynamic>(ApiEndpoints.matches.my);
    return _listFrom(res.data);
  }

  /// Returns matches for [shipmentId]. Backend restricts this endpoint to the
  /// shipment's sender, so non-senders hit 403/404. Mirror the web behaviour
  /// (`useMatchesForShipment` defaults to `[]`) by treating those access
  /// errors as "no matches" instead of bubbling them to the UI.
  Future<List<MatchDto>> getMatchesForShipment(String shipmentId) async {
    try {
      final res = await _dio.get<dynamic>(
        ApiEndpoints.matches.getForShipment(shipmentId),
      );
      return _listFrom(res.data);
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      if (status == 401 || status == 403 || status == 404) {
        return const [];
      }
      rethrow;
    }
  }

  /// Returns matches for [tripId]. Backend restricts this endpoint to the
  /// trip owner, so non-owners hit 401/403/404. Treat those as no matches
  /// (mirrors the web `useMatchesForTrip` default behaviour).
  Future<List<MatchDto>> getMatchesForTrip(String tripId) async {
    try {
      final res = await _dio.get<dynamic>(
        ApiEndpoints.matches.getForTrip(tripId),
      );
      return _listFrom(res.data);
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      if (status == 401 || status == 403 || status == 404) {
        return const [];
      }
      rethrow;
    }
  }

  Future<ApiResponse<MatchDto?>> createMatch({
    required String shipmentId,
    required String tripId,
  }) async {
    final res = await _dio.post<dynamic>(
      ApiEndpoints.matches.create,
      data: {'shipmentId': shipmentId, 'tripId': tripId},
    );
    final body = res.data;
    Map<String, dynamic>? m;
    if (body is Map<String, dynamic> && body['matchId'] != null) {
      m = body;
    } else if (body is Map<String, dynamic>) {
      final d = body['data'];
      if (d is Map<String, dynamic>) m = d;
    }
    if (m != null) {
      return ApiResponse(
        success: true,
        message: body is Map<String, dynamic>
            ? body['message'] as String? ?? 'OK'
            : 'OK',
        data: MatchDto.fromJson(m),
      );
    }
    return ApiResponse(
      success: body is Map<String, dynamic>
          ? body['success'] as bool? ?? false
          : false,
      message: body is Map<String, dynamic>
          ? body['message'] as String? ?? ''
          : '',
      data: null,
    );
  }

  Future<ApiResponse<void>> acceptMatch(String matchId) async {
    final res = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.matches.accept(matchId),
    );
    final body = res.data ?? {};
    return ApiResponse(
      success: body['success'] as bool? ?? true,
      message: body['message'] as String? ?? '',
      data: null,
    );
  }

  Future<ApiResponse<void>> rejectMatch(String matchId) async {
    final res = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.matches.reject(matchId),
    );
    final body = res.data ?? {};
    return ApiResponse(
      success: body['success'] as bool? ?? true,
      message: body['message'] as String? ?? '',
      data: null,
    );
  }
}
