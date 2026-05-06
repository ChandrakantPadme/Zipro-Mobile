import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/presentation/auth_notifier.dart';
import '../auth/presentation/auth_providers.dart';
import 'profile_screen.dart';

/// Account tab root: menu of personal actions (no nested [Scaffold] — shell provides app bar).
class ProfileHubScreen extends ConsumerWidget {
  const ProfileHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authNotifierProvider);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          ListTile(
            leading: const Icon(Icons.inventory_2_outlined),
            title: const Text('My orders'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/my-shipments'),
          ),
          ListTile(
            leading: const Icon(Icons.luggage_outlined),
            title: const Text('My trips'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/my-trips'),
          ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Profile details'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/profile'),
          ),
          ListTile(
            leading: const Icon(Icons.verified_user_outlined),
            title: const Text('KYC'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/kyc'),
          ),
          ListTile(
            leading: const Icon(Icons.payments_outlined),
            title: const Text('Payments'),
            subtitle: const Text('Orders and checkout'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/orders'),
          ),
          ListTile(
            leading: const Icon(Icons.mail_outline),
            title: const Text('Contact support'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showZiproContactSupport(context),
          ),
          const Divider(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FilledButton(
              onPressed: auth.status == AuthStatus.authenticated
                  ? () => ref.read(authNotifierProvider).logout()
                  : null,
              child: const Text('Log out'),
            ),
          ),
        ],
      ),
    );
  }
}
