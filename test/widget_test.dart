import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zipro_mobile/main.dart';

void main() {
  testWidgets('ZiproApp boots with loading scaffold', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: ZiproApp(),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump();
  });
}
