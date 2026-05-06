import '../../core/models/kyc_dto.dart';

/// Mirrors [needsKycCompletion](zipro_website_new/lib/kyc/kyc-completion.ts).
bool needsKycCompletion(KycDto? kyc) {
  if (kyc == null) return true;
  final s = kyc.status.toUpperCase();
  return s == 'REJECTED' || s == 'NOT_STARTED' || s == 'EXPIRED';
}
