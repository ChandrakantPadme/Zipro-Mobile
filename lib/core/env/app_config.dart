import 'package:flutter/foundation.dart';

/// API base URL — override with:
/// `flutter run --dart-define=API_BASE_URL=https://api.example.com`
class AppConfig {
  AppConfig._();

  static const String _defaultBaseUrl = 'https://ac4c-2401-4900-881c-9f95-4ce8-a337-80ce-597a.ngrok-free.app';

  static String get baseUrl {
    const fromEnv = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv;
    return _defaultBaseUrl;
  }

  static const Duration requestTimeout = Duration(seconds: 30);

  /// Razorpay key id fallback when backend omits it on payment order response.
  static String get razorpayKeyId {
    const fromEnv =
        String.fromEnvironment('RAZORPAY_KEY_ID', defaultValue: '');
    return fromEnv;
  }

  static String get senderDeclarationPdfUrl {
    const path = '/sender-declaration-form.pdf';
    if (publicWebOrigin.isEmpty) return path;
    return '${publicWebOrigin.replaceAll(RegExp(r'/$'), '')}$path';
  }

  /// Public marketing site (for PDFs, help links). Override with `--dart-define=WEB_ORIGIN=`.
  static String get publicWebOrigin {
    const fromEnv = String.fromEnvironment('WEB_ORIGIN', defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv;
    return 'https://zipro.in';
  }

  static void logConfig() {
    if (kDebugMode) {
      // ignore: avoid_print
      print('[Zipro] API_BASE_URL=$baseUrl');
    }
  }
}
