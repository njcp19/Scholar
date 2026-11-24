import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:scholar_wallet/models/models.dart';
import 'package:scholar_wallet/providers/app_state.dart';
import 'package:scholar_wallet/screens/cashout_screen.dart';
import 'package:scholar_wallet/services/wallet_service.dart';
import 'package:scholar_wallet/theme/app_theme.dart';
import 'package:scholar_wallet/widgets/widgets.dart';

class _CashoutWallet implements WalletService {
  @override
  Future<List<LinkedAccount>> getLinkedAccounts(String scholarId) async => [
        LinkedAccount(
          id: 1,
          provider: PayoutProvider.maya,
          bankName: '',
          accountName: 'Alex Scholar',
          accountNumber: '123456789012',
        ),
      ];

  @override
  Future<List<Withdrawal>> getMyWithdrawals(
    String scholarId, {
    int limit = 50,
  }) async =>
      [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CashoutAppState extends ChangeNotifier implements AppState {
  @override
  final WalletService wallet = _CashoutWallet();

  @override
  AppUser? user = AppUser(
    id: 'cashout-test-scholar',
    fullName: 'Alex Scholar',
    email: 'scholar@example.test',
    verificationStatus: VerificationStatus.approved,
    isActive: true,
  );

  @override
  double balance = 1234567.89;

  @override
  Future<void> refreshBalance() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
      'Cash Out screen card is left-aligned and clipped at compact size',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = _CashoutAppState();
    addTearDown(state.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.3),
            ),
            child: child!,
          ),
          home: const CashoutScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Withdraw Allowance'), findsOneWidget);
    expect(find.textContaining('real bank'), findsNothing);
    expect(find.textContaining('No real money'), findsNothing);
    expect(find.text('AVAILABLE BALANCE'), findsOneWidget);
    expect(find.text('1,234,567.89'), findsOneWidget);
    expect(find.bySemanticsLabel('PHP 1,234,567.89'), findsOneWidget);
    expect(find.textContaining('Alex Scholar'), findsOneWidget);
    expect(find.textContaining('Maya'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    final card = find.byType(CashoutBalanceHeroCard);
    final label = find.text('AVAILABLE BALANCE');
    expect(
      tester.getTopLeft(label).dx - tester.getRect(card).left,
      greaterThanOrEqualTo(20),
    );
    expect(
      tester.getRect(find.text('1,234,567.89')).right,
      lessThanOrEqualTo(tester.getRect(card).right - 44),
    );

    final clip = tester.widget<ClipRRect>(
      find.descendant(of: card, matching: find.byType(ClipRRect)).first,
    );
    expect(clip.borderRadius, BorderRadius.circular(28));

    final amount = tester.widget<Text>(find.text('1,234,567.89'));
    expect(amount.style?.fontSize, CardNumberStyles.hero.fontSize! - 4);

    final reviewButton = find.text('Review and Withdraw');
    await tester.scrollUntilVisible(
      reviewButton,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(reviewButton, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
