import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholar_wallet/theme/app_theme.dart';
import 'package:scholar_wallet/widgets/widgets.dart';

void main() {
  Widget appWithLoadState(bool pending) => MaterialApp(
        theme: AppTheme.light,
        home: AppInitialLoadView(
          firstLoadPending: pending,
          skeleton: const Text('skeleton'),
          child: const Text('ready'),
        ),
      );

  testWidgets('shows the initial skeleton only after 150ms', (tester) async {
    await tester.pumpWidget(appWithLoadState(true));
    expect(find.text('skeleton'), findsNothing);
    expect(find.bySemanticsLabel('Loading'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 149));
    expect(find.text('skeleton'), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('skeleton'), findsOneWidget);
  });

  testWidgets('keeps a shown skeleton visible for at least 400ms',
      (tester) async {
    await tester.pumpWidget(appWithLoadState(true));
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text('skeleton'), findsOneWidget);

    await tester.pumpWidget(appWithLoadState(false));
    await tester.pump(const Duration(milliseconds: 399));
    expect(find.text('skeleton'), findsOneWidget);
    expect(find.text('ready'), findsNothing);

    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('ready'), findsOneWidget);
  });

  testWidgets('skips the skeleton when the first load finishes before 150ms',
      (tester) async {
    await tester.pumpWidget(appWithLoadState(true));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(appWithLoadState(false));

    expect(find.text('ready'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('skeleton'), findsNothing);
  });

  test('classifies known transport failures as offline', () {
    expect(isOfflineLoadError(const SocketException('network unavailable')),
        isTrue);
    expect(isOfflineLoadError(TimeoutException('request timed out')), isTrue);
    expect(isOfflineLoadError(Exception('invalid response')), isFalse);
  });
}
