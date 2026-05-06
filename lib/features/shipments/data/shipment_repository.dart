import 'package:dio/dio.dart';

import '../../../core/models/api_models.dart';
import '../../../core/models/delivery_models.dart';
import '../../../core/models/pagination.dart';
import '../../../core/network/api_endpoints.dart';

class ShipmentRepository {
  ShipmentRepository(this._dio);

  final Dio _dio;

  Map<String, dynamic> _unwrapShipment(Map<String, dynamic> raw) {
    final m = Map<String, dynamic>.from(raw);
    if (m['shipmentId'] != null && m['orderId'] == null) {
      m['orderId'] = m['shipmentId'];
    }
    return m;
  }

  ShipmentOrderDto? _parseOne(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      if (raw.containsKey('orderId') || raw.containsKey('shipmentId')) {
        return ShipmentOrderDto.fromJson(_unwrapShipment(raw));
      }
      final inner = raw['data'];
      if (inner is Map<String, dynamic>) {
        return ShipmentOrderDto.fromJson(_unwrapShipment(inner));
      }
    }
    return null;
  }

  Future<PaginatedResponse<ShipmentOrderDto>> getMyShipments({
    int page = 0,
    int size = 20,
  }) async {
    final res = await _dio.get<dynamic>(
      ApiEndpoints.shipments.my,
      queryParameters: {'page': page, 'size': size},
    );
    final raw = res.data;
    Map<String, dynamic>? pageJson;
    if (raw is Map<String, dynamic> && raw['content'] is List) {
      pageJson = raw;
    } else if (raw is Map<String, dynamic> && raw['data'] is Map<String, dynamic>) {
      pageJson = raw['data'] as Map<String, dynamic>;
    }
    if (pageJson != null) {
      return PaginatedResponse.fromJson(
        pageJson,
        (m) => ShipmentOrderDto.fromJson(_unwrapShipment(m)),
      );
    }
    return PaginatedResponse<ShipmentOrderDto>(
      content: const [],
      totalElements: 0,
      totalPages: 0,
      size: size,
      number: page,
    );
  }

  Future<PaginatedResponse<ShipmentOrderDto>> getAvailableShipments({
    int page = 0,
    int size = 20,
  }) async {
    final res = await _dio.get<dynamic>(
      ApiEndpoints.shipments.available,
      queryParameters: {'page': page, 'size': size},
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
      return PaginatedResponse.fromJson(
        pageJson,
        (m) => ShipmentOrderDto.fromJson(_unwrapShipment(m)),
      );
    }
    return PaginatedResponse<ShipmentOrderDto>(
      content: const [],
      totalElements: 0,
      totalPages: 0,
      size: size,
      number: page,
    );
  }

  Future<ShipmentOrderDto?> getShipment(String id) async {
    final res = await _dio.get<dynamic>(ApiEndpoints.shipments.getById(id));
    return _parseOne(res.data);
  }

  Future<ApiResponse<ShipmentOrderDto?>> createShipment(
      Map<String, dynamic> payload) async {
    final res = await _dio.post<dynamic>(
      ApiEndpoints.shipments.create,
      data: payload,
    );
    final data = ShipmentRepository._parseShipmentCreate(res.data);
    return ApiResponse(
      success: data.$1,
      message: data.$2,
      data: data.$3 != null ? ShipmentOrderDto.fromJson(data.$3!) : null,
    );
  }

  /// Returns (success, message, optional raw map normalized)
  static (bool, String, Map<String, dynamic>?) _parseShipmentCreate(dynamic body) {
    if (body is Map<String, dynamic>) {
      if (body.containsKey('orderId') || body.containsKey('shipmentId')) {
        final m = Map<String, dynamic>.from(body);
        if (m['shipmentId'] != null && m['orderId'] == null) {
          m['orderId'] = m['shipmentId'];
        }
        return (true, 'OK', m);
      }
      final wrapped = body['data'];
      if (wrapped is Map<String, dynamic>) {
        final m = Map<String, dynamic>.from(wrapped);
        if (m['shipmentId'] != null && m['orderId'] == null) {
          m['orderId'] = m['shipmentId'];
        }
        return (
          body['success'] as bool? ?? true,
          body['message'] as String? ?? '',
          m,
        );
      }
    }
    return (false, 'Invalid shipment response', null);
  }

  /// Searches POSTED shipments by `originCountryCode`/`destinationCountryCode`.
  /// Mirrors web `useSearchShipments`.
  Future<PaginatedResponse<ShipmentOrderDto>> searchShipments({
    String? originCountryCode,
    String? destinationCountryCode,
    int page = 0,
    int size = 20,
  }) async {
    final params = <String, dynamic>{'page': page, 'size': size};
    if (originCountryCode != null && originCountryCode.isNotEmpty) {
      params['originCountryCode'] = originCountryCode;
    }
    if (destinationCountryCode != null && destinationCountryCode.isNotEmpty) {
      params['destinationCountryCode'] = destinationCountryCode;
    }
    final res = await _dio.get<dynamic>(
      ApiEndpoints.shipments.search,
      queryParameters: params,
    );
    return _parsePaginated(res.data, page: page, size: size);
  }

  /// Searches POSTED shipments by exact `originCity`/`destinationCity`.
  /// Mirrors web `useSearchShipmentsByCities`.
  Future<PaginatedResponse<ShipmentOrderDto>> searchShipmentsByCities({
    required String originCity,
    required String destinationCity,
    int page = 0,
    int size = 20,
  }) async {
    final params = <String, dynamic>{
      'originCity': originCity,
      'destinationCity': destinationCity,
      'page': page,
      'size': size,
    };
    final res = await _dio.get<dynamic>(
      ApiEndpoints.shipments.searchByCities,
      queryParameters: params,
    );
    return _parsePaginated(res.data, page: page, size: size);
  }

  PaginatedResponse<ShipmentOrderDto> _parsePaginated(
    dynamic raw, {
    required int page,
    required int size,
  }) {
    Map<String, dynamic>? pageJson;
    if (raw is Map<String, dynamic> && raw['content'] is List) {
      pageJson = raw;
    } else if (raw is Map<String, dynamic> &&
        raw['data'] is Map<String, dynamic>) {
      pageJson = raw['data'] as Map<String, dynamic>;
    }
    if (pageJson != null) {
      return PaginatedResponse.fromJson(
        pageJson,
        (m) => ShipmentOrderDto.fromJson(_unwrapShipment(m)),
      );
    }
    return PaginatedResponse<ShipmentOrderDto>(
      content: const [],
      totalElements: 0,
      totalPages: 0,
      size: size,
      number: page,
    );
  }

  Future<List<MatchableCarrierDto>> getMatchableCarriers(String shipmentId) async {
    final res =
        await _dio.get<dynamic>(ApiEndpoints.shipments.matchableCarriers(shipmentId));
    final raw = res.data;
    if (raw is List) {
      return raw
          .whereType<Map<String, dynamic>>()
          .map(MatchableCarrierDto.fromJson)
          .toList();
    }
    if (raw is Map<String, dynamic>) {
      final inner = raw['data'];
      if (inner is List) {
        return inner
            .whereType<Map<String, dynamic>>()
            .map(MatchableCarrierDto.fromJson)
            .toList();
      }
    }
    return const [];
  }
}
