import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholar_wallet/screens/admin/fund_topup_receipt_screen.dart';
import 'package:scholar_wallet/theme/app_theme.dart';

final _completeReceipt = FundTopUpReceiptData(
  amount: 5000,
  fundingAccountLast4: '1234',
  dateTime: DateTime(2026, 11, 20, 9, 15),
  entryNumber: '42',
  newAvailableFund: 15000,
);

void main() {
  void setCompactViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget app(Widget home) => MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.3),
          ),
          child: child!,
        ),
        home: home,
      );

  testWidgets('shows entered amount, masked account, status, and note',
      (tester) async {
    setCompactViewport(tester);
    await tester.pumpWidget(
      app(FundTopUpReceiptScreen(data: _completeReceipt)),
    );
    await tester.pump();
    final scrollable = find.byType(Scrollable).first;

    expect(find.text('Top up successful'), findsOneWidget);
    expect(find.text('PHP 5,000.00'), findsOneWidget);
    expect(find.text('•••• 1234'), findsOneWidget);
    expect(find.text('COMPLETED'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text(
          'This receipt confirms the funds were added to the payout fund.'),
      200,
      scrollable: scrollable,
    );
    expect(
      find.text(
          'This receipt confirms the funds were added to the payout fund.'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Entry number'));
    expect(find.text('#42'), findsOneWidget);
    await tester.ensureVisible(find.text('New available fund'));
    expect(find.text('PHP 15,000.00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hides optional rows when receipt data is missing',
      (tester) async {
    setCompactViewport(tester);
    final data = FundTopUpReceiptData(
      amount: 5000,
      fundingAccountLast4: '1234',
      dateTime: DateTime(2026, 11, 20, 9, 15),
    );

    await tester.pumpWidget(
      app(FundTopUpReceiptScreen(data: data)),
    );
    await tester.pump();

    expect(find.text('Entry number'), findsNothing);
    expect(find.text('New available fund'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Done pops back to the funding account screen', (tester) async {
    setCompactViewport(tester);

    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        FundTopUpReceiptScreen(data: _completeReceipt),
                  ),
                ),
                child: const Text('Funding account'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Funding account'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Done'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('Funding account'), findsOneWidget);
    expect(find.text('Top up successful'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
