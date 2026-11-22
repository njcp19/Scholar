import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholar_wallet/models/models.dart';
import 'package:scholar_wallet/screens/cashout_receipt_screen.dart';
import 'package:scholar_wallet/theme/app_theme.dart';
import 'package:scholar_wallet/widgets/receipt_layout.dart';
import 'package:scholar_wallet/widgets/widgets.dart';

Withdrawal _withdrawal({
  WithdrawalStatus status = WithdrawalStatus.completed,
  bool simulated = true,
}) =>
    Withdrawal(
      id: 25,
      scholarId: 'scholar-1',
      amount: 1250,
      provider: PayoutProvider.maya,
      bankName: '',
      accountName: 'Alex Scholar',
      accountNumber: '123456789012',
      status: status,
      simulated: simulated,
      reference: 'SIM-ABC12345',
      adminNote: '',
      createdAt: DateTime(2026, 11, 19, 8),
      processedAt: DateTime(2026, 11, 20, 9, 15),
    );

void main() {
  void setCompactViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(320, 640);
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

  testWidgets('shows the recorded Cash Out details', (tester) async {
    setCompactViewport(tester);
    await tester.pumpWidget(
      app(CashoutReceiptScreen(withdrawal: _withdrawal())),
    );
    await tester.pump();

    expect(find.text('Withdraw Allowance completed'), findsOneWidget);
    expect(find.byType(ReceiptHeroCard), findsOneWidget);
    expect(find.byType(CardDecorShapes), findsOneWidget);
    expect(find.bySemanticsLabel('PHP 1,250.00'), findsOneWidget);
    expect(find.text('Maya'), findsOneWidget);
    expect(find.text('Alex Scholar'), findsOneWidget);
    expect(find.text('•••• 9012'), findsOneWidget);
    expect(find.text('SIM-ABC12345'), findsOneWidget);
    await tester.ensureVisible(find.text('Status'));
    expect(find.text('COMPLETED'), findsOneWidget);
    await tester.drag(
      find.byType(Scrollable).first,
      const Offset(0, -600),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        'This receipt confirms your Withdraw Allowance request was recorded in Scholar Wallet.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a non-completed status without claiming completion',
      (tester) async {
    setCompactViewport(tester);
    await tester.pumpWidget(
      app(
        CashoutReceiptScreen(
          withdrawal: _withdrawal(
            status: WithdrawalStatus.pending,
            simulated: false,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.ensureVisible(find.text('Status'));

    expect(find.text('Withdraw Allowance status'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('COMPLETED'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
