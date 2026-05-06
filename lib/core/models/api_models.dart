/// DTOs aligned with [zipro_website_new/lib/api/types.ts].

typedef VerifyChannel = String; // EMAIL | PHONE

class ApiResponse<T> {
  const ApiResponse({
    required this.success,
    required this.message,
    this.data,
  });

  final bool success;
  final String message;
  final T? data;

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T? Function(Object?)? parseData,
  ) {
    return ApiResponse<T>(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      data: parseData != null ? parseData(json['data']) : json['data'] as T?,
    );
  }
}

class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.tokenType,
    required this.expiresIn,
    required this.userId,
    this.refreshToken,
  });

  final String accessToken;
  final String tokenType;
  final int expiresIn;
  final String userId;
  final String? refreshToken;

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      accessToken: json['accessToken'] as String,
      tokenType: json['tokenType'] as String? ?? 'Bearer',
      expiresIn: json['expiresIn'] as int,
      userId: json['userId'] as String,
      refreshToken: json['refreshToken'] as String?,
    );
  }
}

class UserProfile {
  const UserProfile({
    required this.userId,
    this.email,
    this.countryCode,
    this.phone,
    this.firstName,
    this.lastName,
    required this.isActive,
    required this.hasEnabledRiderMode,
    required this.isOauthLogin,
    required this.isVerified,
    required this.createdAt,
  });

  final String userId;
  final String? email;
  final String? countryCode;
  final String? phone;
  final String? firstName;
  final String? lastName;
  final bool isActive;
  final bool hasEnabledRiderMode;
  final bool isOauthLogin;
  final bool isVerified;
  final String createdAt;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: json['userId'] as String,
      email: json['email'] as String?,
      countryCode: json['countryCode'] as String?,
      phone: json['phone'] as String?,
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      hasEnabledRiderMode: json['hasEnabledRiderMode'] as bool? ?? false,
      isOauthLogin: json['isOauthLogin'] as bool? ?? false,
      isVerified: json['isVerified'] as bool? ?? false,
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

class LoginOtpRequestPayload {
  const LoginOtpRequestPayload({
    required this.channel,
    required this.identifier,
    required this.purpose,
  });

  final VerifyChannel channel;
  final String identifier;
  final String purpose;

  Map<String, dynamic> toJson() => {
        'channel': channel,
        'identifier': identifier,
        'purpose': purpose,
      };
}

class VerifyOtpPayload {
  const VerifyOtpPayload({
    required this.channel,
    required this.identifier,
    required this.otp,
  });

  final VerifyChannel channel;
  final String identifier;
  final String otp;

  Map<String, dynamic> toJson() => {
        'channel': channel,
        'identifier': identifier,
        'otp': otp,
      };
}

typedef OtpPurpose = String; // LOGIN | SIGNUP | RESET_PASSWORD

class SignupRequestPayload {
  const SignupRequestPayload({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.countryCode,
    required this.verifyChannel,
  });

  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String countryCode;
  final VerifyChannel verifyChannel;

  Map<String, dynamic> toJson() => {
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'phone': phone,
        'countryCode': countryCode,
        'verifyChannel': verifyChannel,
      };
}
