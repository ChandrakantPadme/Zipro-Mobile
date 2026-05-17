import 'package:dio/dio.dart';

/// Returns true when the API responded with the `KYC_REQUIRED` sentinel
/// message, mirroring web `isKycRequiredError`.
bool isKycRequiredError(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map) {
      final m = data['message'];
      if (m is String && m.contains('KYC_REQUIRED')) return true;
    }
    final msg = error.message ?? '';
    if (msg.contains('KYC_REQUIRED')) return true;
  } else {
    final s = error.toString();
    if (s.contains('KYC_REQUIRED')) return true;
  }
  return false;
}

/// Human-readable API error message from Dio (matches web error-handler patterns).
String dioErrorMessage(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map) {
      final m = data['message'];
      if (m is String && m.isNotEmpty) return m;
      final errors = data['errors'];
      if (errors is Map && errors.values.isNotEmpty) {
        final first = errors.values.first;
        if (first is List && first.isNotEmpty && first.first is String) {
          return first.first as String;
        }
      }
    }
    return error.message ?? 'Network error';
  }
  return error.toString();
}
