import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/models/api_models.dart';
import '../../../core/models/delivery_models.dart';
import '../../../core/network/api_endpoints.dart';

class MatchRepository {
  MatchRepository(this._dio);

  final Dio _dio;

  List<MatchDto> _listFrom(dynamic raw) {
    dynamic decoded = raw;
    if (raw is String) {
      final s = raw.trim();
      if (s.isEmpty) return const [];
      try {
        decoded = jsonDecode(s);
      } catch (_) {
        return const [];
      }
    }
    List<dynamic> list = const [];
    if (decoded is List) {
      list = decoded;
    } else if (decoded is Map) {
      final map = Map<String, dynamic>.from(decoded);
      final d = map['data'];
      if (d is List) {
        list = d;
      } else if (d is Map && d['content'] is List) {
        list = d['content'] as List;
      } else if (map['content'] is List) {
        list = map['content'] as List;
      }
    }
    final out = <MatchDto>[];
    for (final item in list) {
      if (item is Map) {
        out.add(MatchDto.fromJson(Map<String, dynamic>.from(item)));
      }
    }
    return out;
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
      // 403/404: not sender or unknown shipment — treat as no matches (same as web).
      // Do not swallow 401; rely on auth interceptor + visible error.
      if (status == 403 || status == 404) {
        return const [];
      }
      rethrow;
    }
  }

  /// Returns matches for [tripId]. Backend restricts this endpoint to the
  /// trip owner, so non-owners hit 403/404. Those map to an empty list; 401 is not
  /// swallowed so auth failures surface.
  Future<List<MatchDto>> getMatchesForTrip(String tripId) async {
    try {
      final res = await _dio.get<dynamic>(
        ApiEndpoints.matches.getForTrip(tripId),
      );
      return _listFrom(res.data);
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      // 403/404: not trip owner or unknown trip — treat as no matches (same as web).
      // Do not swallow 401; rely on auth interceptor + visible error.
      if (status == 403 || status == 404) {
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
      message:
          body is Map<String, dynamic> ? body['message'] as String? ?? '' : '',
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
