import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/navigation/zipro_pop_or_home.dart';
import '../auth/presentation/auth_providers.dart';
import '../repositories_providers.dart';

void showZiproContactSupport(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (ctx) => _ContactZiproDialog(parentContext: context),
  );
}

final userTrustSummaryProvider =
    FutureProvider.autoDispose<String?>((ref) async {
  final u = ref.watch(authNotifierProvider).user;
  if (u == null) return null;
  final (level, n) =
      await ref.watch(trustRepositoryProvider).getTrust(u.userId);
  if (level != null && level.isNotEmpty) {
    return '$level · $n completed deliveries';
  }
  return '$n completed deliveries';
});

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authNotifierProvider).user;
    final trust = ref.watch(userTrustSummaryProvider);

    return ZiproPopScope(
      child: Scaffold(
        appBar: AppBar(
          leading: ziproLeadingBackOrHome(context),
          title: const Text('Profile details'),
        ),
        body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            ListTile(
              title: const Text('Email'),
              subtitle: Text(user?.email ?? '—'),
            ),
            ListTile(
              title: const Text('Phone'),
              subtitle: Text(user?.phone ?? '—'),
            ),
            trust.when(
              data: (t) =>
                  t == null ? const SizedBox.shrink() : ListTile(title: Text(t)),
              loading: () => const ListTile(title: Text('Trust…')),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    ),
  );
  }
}

class _ContactZiproDialog extends ConsumerStatefulWidget {
  const _ContactZiproDialog({required this.parentContext});

  final BuildContext parentContext;

  @override
  ConsumerState<_ContactZiproDialog> createState() =>
      _ContactZiproDialogState();
}

class _ContactZiproDialogState extends ConsumerState<_ContactZiproDialog> {
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _msg;

  @override
  void initState() {
    super.initState();
    final u = ref.read(authNotifierProvider).user;
    _name = TextEditingController(
      text: '${u?.firstName ?? ''} ${u?.lastName ?? ''}'.trim(),
    );
    _email = TextEditingController(text: u?.email ?? '');
    _msg = TextEditingController();
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _msg.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Contact Zipro'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: _msg,
              decoration: const InputDecoration(labelText: 'Message'),
              maxLines: 4,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            final repo = ref.read(contactRepositoryProvider);
            final res = await repo.submit(
              name: _name.text.trim(),
              email: _email.text.trim(),
              message: _msg.text.trim(),
            );
            if (!context.mounted) return;
            Navigator.pop(context);
            if (!widget.parentContext.mounted) return;
            ScaffoldMessenger.of(widget.parentContext).showSnackBar(
              SnackBar(content: Text(res.message)),
            );
          },
          child: const Text('Send'),
        ),
      ],
    );
  }
}
