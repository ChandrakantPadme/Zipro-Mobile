import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/network/dio_error_mapper.dart';
import '../../../core/models/api_models.dart';
import '../../../core/storage/token_storage.dart';
import '../data/auth_repository.dart';

enum AuthStatus { unknown, unauthenticated, authenticated }

class AuthNotifier extends ChangeNotifier {
  AuthNotifier(this._storage) {
    _dio = createAuthDio(
      getToken: _storage.getAccessToken,
      onUnauthorized: logoutLocal,
    );
    _repo = AuthRepository(_dio);
  }

  final TokenStorage _storage;
  late final Dio _dio;
  late final AuthRepository _repo;

  AuthStatus _status = AuthStatus.unknown;
  UserProfile? _user;

  AuthStatus get status => _status;
  UserProfile? get user => _user;
  bool get isLoggedIn => _status == AuthStatus.authenticated;

  Dio get dio => _dio;

  /// Cold start — read secure storage.
  Future<void> bootstrap() async {
    final ok = await _storage.isAuthenticated();
    if (!ok) {
      _status = AuthStatus.unauthenticated;
      _user = null;
      notifyListeners();
      return;
    }
    await refreshProfile();
  }

  Future<void> refreshProfile() async {
    try {
      final res = await _repo.getCurrentUser();
      if (res.success && res.data != null) {
        _user = res.data;
        _status = AuthStatus.authenticated;
      } else {
        await logoutLocal();
      }
    } catch (_) {
      await logoutLocal();
    }
    notifyListeners();
  }

  Future<String?> requestLoginOtp({
    required String channel,
    required String identifier,
  }) async {
    try {
      final res = await _repo.requestLoginOtp(
        LoginOtpRequestPayload(
          channel: channel,
          identifier: identifier,
          purpose: 'LOGIN',
        ),
      );
      if (res.success) return null;
      return res.message.isNotEmpty ? res.message : 'Could not send OTP';
    } on DioException catch (e) {
      return dioErrorMessage(e);
    }
  }

  Future<String?> verifyLoginOtp({
    required String channel,
    required String identifier,
    required String otp,
  }) async {
    try {
      final res = await _repo.verifyLoginOtp(
        VerifyOtpPayload(
          channel: channel,
          identifier: identifier,
          otp: otp,
        ),
      );
      if (!res.success || res.data == null) {
        return res.message.isNotEmpty ? res.message : 'Verification failed';
      }
      await _storage.storeTokens(tokens: res.data!);
      await refreshProfile();
      return null;
    } on DioException catch (e) {
      return dioErrorMessage(e);
    }
  }

  Future<String?> signupRequest({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String countryCode,
    required String verifyChannel,
  }) async {
    try {
      final res = await _repo.signupRequest(
        SignupRequestPayload(
          firstName: firstName.trim(),
          lastName: lastName.trim(),
          email: email.trim(),
          phone: phone.trim(),
          countryCode: countryCode.trim(),
          verifyChannel: verifyChannel,
        ),
      );
      if (res.success) return null;
      return res.message.isNotEmpty ? res.message : 'Could not send OTP';
    } on DioException catch (e) {
      return dioErrorMessage(e);
    }
  }

  Future<String?> verifySignupOtp({
    required String channel,
    required String identifier,
    required String otp,
  }) async {
    try {
      final res = await _repo.verifySignupOtp(
        VerifyOtpPayload(
          channel: channel,
          identifier: identifier,
          otp: otp,
        ),
      );
      if (!res.success || res.data == null) {
        return res.message.isNotEmpty ? res.message : 'Verification failed';
      }
      await _storage.storeTokens(tokens: res.data!);
      await refreshProfile();
      return null;
    } on DioException catch (e) {
      return dioErrorMessage(e);
    }
  }

  Future<void> logout() async {
    try {
      await _repo.logout();
    } catch (_) {
      /* network optional */
    }
    await logoutLocal();
  }

  Future<void> logoutLocal() async {
    await _storage.clear();
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
