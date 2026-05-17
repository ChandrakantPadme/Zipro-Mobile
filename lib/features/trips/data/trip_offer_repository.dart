import 'package:dio/dio.dart';

import '../../../core/models/api_models.dart';
import '../../../core/models/delivery_models.dart';
import '../../../core/network/api_endpoints.dart';

class TripOfferRepository {
  TripOfferRepository(this._dio);

  final Dio _dio;

  Future<ApiResponse<TripOfferDto?>> createOffer(
    String tripId,
    Map<String, dynamic> payload,
  ) async {
    final body = {...payload, 'tripId': tripId};
    final res = await _dio.post<dynamic>(
      ApiEndpoints.tripOffers.create(tripId),
      data: body,
    );
    final data = res.data;
    Map<String, dynamic>? m;
    if (data is Map<String, dynamic> && data['offerId'] != null) {
      m = data;
    } else if (data is Map<String, dynamic>) {
      final d = data['data'];
      if (d is Map<String, dynamic>) m = d;
    }
    if (m != null) {
      return ApiResponse(
        success: true,
        message: data is Map<String, dynamic>
            ? data['message'] as String? ?? 'OK'
            : 'OK',
        data: TripOfferDto.fromJson(m),
      );
    }
    if (data is Map<String, dynamic>) {
      return ApiResponse(
        success: data['success'] as bool? ?? false,
        message: data['message'] as String? ?? '',
        data: null,
      );
    }
    return const ApiResponse(
        success: false, message: 'Invalid response', data: null);
  }

  Future<List<TripOfferDto>> offersForTrip(String tripId,
      {bool openOnly = false}) async {
    final path = openOnly
        ? ApiEndpoints.tripOffers.getOpenForTrip(tripId)
        : ApiEndpoints.tripOffers.getForTrip(tripId);
    final res = await _dio.get<dynamic>(path);
    final raw = res.data;
    List<dynamic> list = const [];
    if (raw is List) list = raw;
    if (raw is Map<String, dynamic>) {
      final d = raw['data'];
      if (d is List) list = d;
    }
    return list
        .whereType<Map<String, dynamic>>()
        .map(TripOfferDto.fromJson)
        .toList();
  }
}
