import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/api_models.dart';

/// Same semantics as [zipro_website_new/lib/auth/token-storage.ts]
class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _storage;

  static const _kAccess = 'zipro_access_token';
  static const _kData = 'zipro_token_data';
  static const _kUserId = 'zipro_user_id';

  Future<void> storeTokens({
    required AuthTokens tokens,
  }) async {
    final expiresAt = DateTime.now().millisecondsSinceEpoch + tokens.expiresIn;
    final data = jsonEncode({
      'accessToken': tokens.accessToken,
      'tokenType': tokens.tokenType,
      'expiresIn': tokens.expiresIn,
      'userId': tokens.userId,
      'refreshToken': tokens.refreshToken,
      'expiresAt': expiresAt,
    });
    await _storage.write(key: _kAccess, value: tokens.accessToken);
    await _storage.write(key: _kData, value: data);
    await _storage.write(key: _kUserId, value: tokens.userId);
  }

  Future<String?> getAccessToken() async {
    final token = await _storage.read(key: _kAccess);
    final raw = await _storage.read(key: _kData);
    if (token == null || raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final expiresAt = map['expiresAt'] as int?;
      if (expiresAt != null && DateTime.now().millisecondsSinceEpoch >= expiresAt) {
        await clear();
        return null;
      }
    } catch (_) {
      await clear();
      return null;
    }
    return token;
  }

  Future<bool> isAuthenticated() async {
    final t = await getAccessToken();
    return t != null && t.isNotEmpty;
  }

  Future<void> clear() async {
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kData);
    await _storage.delete(key: _kUserId);
  }
}
