import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholar_wallet/screens/cashout_screen.dart';
import 'package:scholar_wallet/theme/app_theme.dart';
import 'package:scholar_wallet/widgets/receipt_layout.dart';

void main() {
  testWidgets('highlight cards preserve content at narrow scaled size', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final cards = [
      const _CardCase(
        CashoutBalanceHeroCard(balance: 1234567.89),
        'AVAILABLE BALANCE',
      ),
      const _CardCase(
        ReceiptHeroCard(
          heading: 'Payout received',
          amount: 1234567.89,
        ),
        'Payout received',
      ),
    ];

    for (final cardCase in cards) {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.3),
            ),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: cardCase.card,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(cardCase.label), findsOneWidget);
      expect(find.bySemanticsLabel('PHP 1,234,567.89'), findsOneWidget);

      expect(tester.takeException(), isNull, reason: cardCase.label);
    }
  });
}

class _CardCase {
  final Widget card;
  final String label;

  const _CardCase(this.card, this.label);
}
