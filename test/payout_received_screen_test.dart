import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholar_wallet/models/models.dart';
import 'package:scholar_wallet/screens/payout_received_screen.dart';
import 'package:scholar_wallet/theme/app_theme.dart';
import 'package:scholar_wallet/widgets/receipt_layout.dart';
import 'package:scholar_wallet/widgets/widgets.dart';

void main() {
  testWidgets('success receipt uses the shared receipt hero card', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final claim = AllowanceClaim(
      id: 'payout-1',
      batchId: 'batch-1',
      batchTitle: 'Monthly Allowance',
      scholarId: 'scholar-1',
      scholarName: 'Alex Scholar',
      amount: 6000,
      token: 'token',
      status: ClaimStatus.received,
      claimedAt: DateTime(2026, 11, 20, 9, 15),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.3),
          ),
          child: child!,
        ),
        home: PayoutReceivedScreen(
          claim: claim,
          receivedAmount: 6000,
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(ReceiptHeroCard), findsOneWidget);
    expect(find.byType(CardDecorShapes), findsOneWidget);
    expect(find.text('Payout received'), findsOneWidget);
    expect(
      find.text('Verified by QR and device biometrics'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('PHP 6,000.00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
