import 'package:dio/dio.dart';

import '../../../core/models/api_models.dart';
import '../../../core/models/delivery_models.dart';
import '../../../core/models/pagination.dart';
import '../../../core/network/api_endpoints.dart';

class TripRepository {
  TripRepository(this._dio);

  final Dio _dio;

  Future<PaginatedResponse<TripDto>> getMyTrips({
    int page = 0,
    int size = 20,
    String? status,
  }) async {
    final params = <String, dynamic>{'page': page, 'size': size};
    if (status != null) params['status'] = status;
    final res =
        await _dio.get<dynamic>(ApiEndpoints.trips.my, queryParameters: params);
    final raw = res.data;
    Map<String, dynamic>? pageJson;
    if (raw is Map<String, dynamic> && raw['content'] is List) {
      pageJson = raw;
    } else if (raw is Map<String, dynamic> &&
        raw['data'] is Map<String, dynamic>) {
      pageJson = raw['data'] as Map<String, dynamic>;
    }
    if (pageJson != null) {
      return PaginatedResponse.fromJson(pageJson, TripDto.fromJson);
    }
    return PaginatedResponse<TripDto>(
      content: const [],
      totalElements: 0,
      totalPages: 0,
      size: size,
      number: page,
    );
  }

  Future<TripDto?> getTrip(String tripId) async {
    final res = await _dio.get<dynamic>(ApiEndpoints.trips.getById(tripId));
    final body = res.data;
    Map<String, dynamic>? m;
    if (body is Map<String, dynamic> && body['tripId'] != null) {
      m = body;
    } else if (body is Map<String, dynamic>) {
      final d = body['data'];
      if (d is Map<String, dynamic>) m = d;
    }
    return m != null ? TripDto.fromJson(m) : null;
  }

  Future<ApiResponse<TripDto?>> createTrip(Map<String, dynamic> payload) async {
    final res =
        await _dio.post<dynamic>(ApiEndpoints.trips.create, data: payload);
    final body = res.data;
    if (body is Map<String, dynamic> && body['tripId'] != null) {
      return ApiResponse(
        success: true,
        message: 'OK',
        data: TripDto.fromJson(body),
      );
    }
    if (body is Map<String, dynamic>) {
      final d = body['data'];
      return ApiResponse(
        success: body['success'] as bool? ?? false,
        message: body['message'] as String? ?? '',
        data: d is Map<String, dynamic> ? TripDto.fromJson(d) : null,
      );
    }
    return const ApiResponse(
        success: false, message: 'Invalid response', data: null);
  }

  Future<ApiResponse<TripDto?>> startTrip(String tripId) async {
    final res = await _dio.post<dynamic>(ApiEndpoints.trips.start(tripId));
    final body = res.data;
    if (body is Map<String, dynamic> && body['tripId'] != null) {
      return ApiResponse(
        success: true,
        message: 'OK',
        data: TripDto.fromJson(body),
      );
    }
    final d = body is Map<String, dynamic> ? body['data'] : null;
    return ApiResponse(
      success: body is Map<String, dynamic>
          ? body['success'] as bool? ?? true
          : false,
      message:
          body is Map<String, dynamic> ? body['message'] as String? ?? '' : '',
      data: d is Map<String, dynamic> ? TripDto.fromJson(d) : null,
    );
  }

  Future<PaginatedResponse<TripDto>> getAvailableTrips({
    int page = 0,
    int size = 10,
    String? fromCountryCode,
    String? toCountryCode,
  }) async {
    final params = <String, dynamic>{'page': page, 'size': size};
    if (fromCountryCode != null) params['fromCountryCode'] = fromCountryCode;
    if (toCountryCode != null) params['toCountryCode'] = toCountryCode;
    final res = await _dio.get<dynamic>(
      ApiEndpoints.trips.available,
      queryParameters: params,
    );
    final raw = res.data;
    Map<String, dynamic>? pageJson;
    if (raw is Map<String, dynamic> && raw['content'] is List) {
      pageJson = raw;
    } else if (raw is Map<String, dynamic> &&
        raw['data'] is Map<String, dynamic>) {
      pageJson = raw['data'] as Map<String, dynamic>;
    }
    if (pageJson != null) {
      return PaginatedResponse.fromJson(pageJson, TripDto.fromJson);
    }
    return PaginatedResponse<TripDto>(
      content: const [],
      totalElements: 0,
      totalPages: 0,
      size: size,
      number: page,
    );
  }

  /// Traveler accepts a posted shipment for a PLANNED trip (creates + accepts match).
  Future<ApiResponse<MatchDto?>> acceptShipmentForTrip({
    required String tripId,
    required String shipmentId,
  }) async {
    final res = await _dio.post<dynamic>(
      ApiEndpoints.trips.acceptShipment(tripId),
      data: <String, dynamic>{'shipmentId': shipmentId},
    );
    final body = res.data;
    Map<String, dynamic>? m;
    if (body is Map<String, dynamic> && body['matchId'] != null) {
      m = body;
    } else if (body is Map<String, dynamic>) {
      final d = body['data'];
      if (d is Map<String, dynamic> && d['matchId'] != null) {
        m = d;
      }
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
}
