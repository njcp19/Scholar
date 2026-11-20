import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholar_wallet/theme/app_theme.dart';
import 'package:scholar_wallet/widgets/widgets.dart';

void main() {
  testWidgets('prototype notices use shared neutral text at compact scale',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(
      tester.view.platformDispatcher.clearTextScaleFactorTestValue,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                PrototypeNotice(message: prototypeCashOutNotice),
                SizedBox(height: 16),
                PrototypeNotice(message: prototypeLinkedAccountNotice),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text(prototypeCashOutNotice), findsOneWidget);
    expect(find.text(prototypeLinkedAccountNotice), findsOneWidget);
    expect(find.textContaining('Demo'), findsNothing);
    expect(find.textContaining('Simulated'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test(
      'Cash Out, Top up and Linked accounts contain exactly the approved notices',
      () {
    final cashOut = File('lib/screens/cashout_screen.dart').readAsStringSync();
    final topUp = File('lib/screens/admin/funding_account_screen.dart')
        .readAsStringSync();
    final linked =
        File('lib/screens/linked_accounts_screen.dart').readAsStringSync();

    expect(
      RegExp('PrototypeNotice\\(message: prototypeCashOutNotice\\)')
          .allMatches(cashOut)
          .length,
      1,
    );
    expect(topUp, contains('prototypeCashOutNotice'));
    expect(linked, contains('prototypeLinkedAccountNotice'));
    expect(topUp, isNot(contains('Demo mode')));
    expect(linked, isNot(contains('DEMO ONLY')));
    expect(linked, isNot(contains('Demo only')));
  });
}
