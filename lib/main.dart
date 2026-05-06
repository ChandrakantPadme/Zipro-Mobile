import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/env/app_config.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/auth_providers.dart';
import 'router/app_router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.logConfig();
  runApp(
    const ProviderScope(
      child: ZiproApp(),
    ),
  );
}

class ZiproApp extends ConsumerStatefulWidget {
  const ZiproApp({super.key});

  @override
  ConsumerState<ZiproApp> createState() => _ZiproAppState();
}

class _ZiproAppState extends ConsumerState<ZiproApp> {
  GoRouter? _router;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await ref.read(authNotifierProvider).bootstrap();
    if (!mounted) return;
    final auth = ref.read(authNotifierProvider);
    setState(() {
      _router = buildAppRouter(auth);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_router == null) {
      return MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
      );
    }

    return MaterialApp.router(
      theme: buildAppTheme(),
      routerConfig: _router!,
    );
  }
}
