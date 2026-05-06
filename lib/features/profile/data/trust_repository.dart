import 'package:dio/dio.dart';

import '../../../core/network/api_endpoints.dart';

class TrustRepository {
  TrustRepository(this._dio);

  final Dio _dio;

  Future<(String?, int)> getTrust(String userId) async {
    final res = await _dio.get<dynamic>(ApiEndpoints.users.trust(userId));
    final body = res.data;
    Map<String, dynamic>? m;
    if (body is Map<String, dynamic> && body['trustLevel'] != null) {
      m = body;
    } else if (body is Map<String, dynamic>) {
      final d = body['data'];
      if (d is Map<String, dynamic>) m = d;
    }
    if (m == null) return (null, 0);
    final level = m['trustLevel'] as String?;
    final deliveries = (m['completedDeliveries'] as num?)?.toInt() ?? 0;
    return (level, deliveries);
  }
}
