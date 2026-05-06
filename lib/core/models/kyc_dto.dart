/// KYC + S3 DTOs aligned with [zipro_website_new/lib/api/types.ts].

class KycAddressDto {
  const KycAddressDto({
    required this.street,
    required this.city,
    required this.state,
    required this.postalCode,
    required this.country,
  });

  final String street;
  final String city;
  final String state;
  final String postalCode;
  final String country;

  Map<String, dynamic> toJson() => {
        'street': street,
        'city': city,
        'state': state,
        'postalCode': postalCode,
        'country': country,
      };
}

class CreateKycPayload {
  const CreateKycPayload({
    required this.legalName,
    required this.nationality,
    required this.countryResidence,
    required this.phoneNumberCode,
    required this.phoneNumber,
    required this.address,
    this.selfieImageRef,
    this.passportImageRef,
    this.metadata,
  });

  final String legalName;
  final String nationality;
  final String countryResidence;
  final String phoneNumberCode;
  final String phoneNumber;
  final KycAddressDto address;
  final String? selfieImageRef;
  final String? passportImageRef;
  final Map<String, dynamic>? metadata;

  Map<String, dynamic> toJson() => {
        'legalName': legalName,
        'nationality': nationality,
        'countryResidence': countryResidence,
        'phoneNumberCode': phoneNumberCode,
        'phoneNumber': phoneNumber,
        'address': address.toJson(),
        if (selfieImageRef != null) 'selfieImageRef': selfieImageRef,
        if (passportImageRef != null) 'passportImageRef': passportImageRef,
        if (metadata != null) 'metadata': metadata,
      };
}

class KycDto {
  const KycDto({
    required this.kycId,
    required this.userId,
    required this.legalName,
    required this.nationality,
    required this.countryResidence,
    required this.phoneNumberCode,
    required this.phoneNumber,
    required this.address,
    required this.status,
    required this.verified,
    required this.createdAt,
    required this.updatedAt,
    this.selfieImageRef,
    this.passportImageRef,
    this.rejectionReason,
    this.verifiedAt,
    this.metadata,
  });

  final String kycId;
  final String userId;
  final String legalName;
  final String nationality;
  final String countryResidence;
  final String phoneNumberCode;
  final String phoneNumber;
  final KycAddressDto address;
  final String status;
  final bool verified;
  final String? selfieImageRef;
  final String? passportImageRef;
  final String? rejectionReason;
  final Map<String, dynamic>? metadata;
  final String createdAt;
  final String updatedAt;
  final String? verifiedAt;

  factory KycDto.fromJson(Map<String, dynamic> json) {
    final addr = json['address'];
    return KycDto(
      kycId: json['kycId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      legalName: json['legalName'] as String? ?? '',
      nationality: json['nationality'] as String? ?? '',
      countryResidence: json['countryResidence'] as String? ?? '',
      phoneNumberCode: json['phoneNumberCode'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String? ?? '',
      address: addr is Map<String, dynamic>
          ? KycAddressDto(
              street: addr['street'] as String? ?? '',
              city: addr['city'] as String? ?? '',
              state: addr['state'] as String? ?? '',
              postalCode: addr['postalCode'] as String? ?? '',
              country: addr['country'] as String? ?? '',
            )
          : const KycAddressDto(
              street: '',
              city: '',
              state: '',
              postalCode: '',
              country: '',
            ),
      selfieImageRef: json['selfieImageRef'] as String?,
      passportImageRef: json['passportImageRef'] as String?,
      status: json['status'] as String? ?? 'NOT_STARTED',
      verified: json['verified'] as bool? ?? false,
      rejectionReason: json['rejectionReason'] as String?,
      metadata: json['metadata'] is Map<String, dynamic>
          ? json['metadata'] as Map<String, dynamic>
          : null,
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
      verifiedAt: json['verifiedAt'] as String?,
    );
  }
}

class S3UploadUrlRequest {
  const S3UploadUrlRequest({
    required this.fileName,
    required this.contentType,
  });

  final String fileName;
  final String contentType;

  Map<String, dynamic> toJson() => {
        'fileName': fileName,
        'contentType': contentType,
      };
}

class S3UploadUrlResponse {
  const S3UploadUrlResponse({
    required this.presignedUrl,
    required this.fileKey,
    this.bucket,
  });

  final String presignedUrl;
  final String fileKey;
  final String? bucket;

  factory S3UploadUrlResponse.fromJson(Map<String, dynamic> json) {
    return S3UploadUrlResponse(
      presignedUrl: json['presignedUrl'] as String,
      fileKey: json['fileKey'] as String,
      bucket: json['bucket'] as String?,
    );
  }
}
