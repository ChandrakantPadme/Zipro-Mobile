import 'package:dio/dio.dart';

import '../../../core/models/kyc_dto.dart';
import '../../../core/network/api_endpoints.dart';

/// S3 presigned uploads (auth client + raw PUT to presigned URL).
class UploadRepository {
  UploadRepository(this._authDio);

  final Dio _authDio;
  static final Dio _presignedPut = Dio();

  Future<S3UploadUrlResponse> _requestPresignedUrl(S3UploadUrlRequest request) async {
    final res = await _authDio.post<dynamic>(
      ApiEndpoints.s3.getUploadUrl,
      data: request.toJson(),
    );
    final data = res.data;
    if (data is Map<String, dynamic>) {
      if (data['presignedUrl'] != null && data['fileKey'] != null) {
        return S3UploadUrlResponse.fromJson(data);
      }
      final inner = data['data'];
      if (inner is Map<String, dynamic> &&
          inner['presignedUrl'] != null &&
          inner['fileKey'] != null) {
        return S3UploadUrlResponse.fromJson(inner);
      }
    }
    throw DioException(
      requestOptions: res.requestOptions,
      message: 'Invalid S3 upload-url response',
    );
  }

  /// Returns `s3://bucket/fileKey` matching [uploadFileToS3AndGetPath] on web.
  Future<String> uploadBytesAndGetS3Path({
    required List<int> bytes,
    required String fileName,
    required String contentType,
    ProgressCallback? onSendProgress,
  }) async {
    final urlData = await _requestPresignedUrl(
      S3UploadUrlRequest(fileName: fileName, contentType: contentType),
    );
    await _presignedPut.put<void>(
      urlData.presignedUrl,
      data: bytes,
      options: Options(
        headers: {'Content-Type': contentType},
        validateStatus: (s) => s != null && (s == 200 || s == 204),
      ),
      onSendProgress: onSendProgress,
    );
    final bucket = urlData.bucket ?? 'zipro-file-uploads';
    return 's3://$bucket/${urlData.fileKey}';
  }
}
