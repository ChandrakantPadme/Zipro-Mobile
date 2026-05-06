import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/presentation/auth_providers.dart';
import 'data/kyc_repository.dart';
import 'data/upload_repository.dart';

/// Mirrors [KycStatusContext](zipro_website_new/contexts/KycStatusContext.tsx).
final kycRepositoryProvider = Provider<KycRepository>((ref) {
  final auth = ref.watch(authNotifierProvider);
  return KycRepository(auth.dio);
});

final uploadRepositoryProvider = Provider<UploadRepository>((ref) {
  final auth = ref.watch(authNotifierProvider);
  return UploadRepository(auth.dio);
});

final kycRecordProvider = FutureProvider.autoDispose((ref) async {
  final auth = ref.watch(authNotifierProvider);
  if (!auth.isLoggedIn) return null;
  final repo = ref.watch(kycRepositoryProvider);
  return repo.fetchMyKyc();
});

final kycGateProvider = Provider.autoDispose((ref) {
  final async = ref.watch(kycRecordProvider);
  return async.when(
    data: (kyc) {
      if (kyc == null) {
        return const KycGateState(
          isUnderReview: false,
          isVerified: false,
          status: null,
        );
      }
      const under = {'SUBMITTED', 'UNDER_REVIEW'};
      final status = kyc.status;
      final isUnderReview = under.contains(status);
      final isVerified = (kyc.verified == true) || status == 'VERIFIED';
      return KycGateState(
        isUnderReview: isUnderReview,
        isVerified: isVerified,
        status: status,
      );
    },
    loading: () => const KycGateState(
      isUnderReview: false,
      isVerified: false,
      status: null,
    ),
    error: (_, __) => const KycGateState(
      isUnderReview: false,
      isVerified: false,
      status: null,
    ),
  );
});

class KycGateState {
  const KycGateState({
    required this.isUnderReview,
    required this.isVerified,
    required this.status,
  });

  final bool isUnderReview;
  final bool isVerified;
  final String? status;
}
