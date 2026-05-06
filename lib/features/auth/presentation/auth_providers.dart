import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/token_storage.dart';
import 'auth_notifier.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

final authNotifierProvider = ChangeNotifierProvider<AuthNotifier>((ref) {
  final storage = ref.watch(tokenStorageProvider);
  return AuthNotifier(storage);
});
