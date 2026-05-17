import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/navigation/zipro_pop_or_home.dart';
import '../../core/models/delivery_models.dart';
import '../../core/network/dio_error_mapper.dart';
import '../repositories_providers.dart';

final myMatchesProvider = FutureProvider.autoDispose<List<MatchDto>>((ref) {
  return ref.watch(matchRepositoryProvider).getMyMatches();
});

class MatchesListScreen extends ConsumerWidget {
  const MatchesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myMatchesProvider);
    return ZiproPopScope(
      child: Scaffold(
        appBar: AppBar(
          leading: ziproLeadingBackOrHome(context),
          title: const Text('My matches'),
        ),
        body: async.when(
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('No matches yet'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myMatchesProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final m = list[i];
                return ListTile(
                  title: Text('Match ${m.matchId} · ${m.status}'),
                  subtitle: Text(
                    'Trip ${m.tripId ?? "—"} · Fee ${m.agreedFee} ${m.currency ?? ""}',
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(dioErrorMessage(e))),
      ),
    ),
  );
  }
}
