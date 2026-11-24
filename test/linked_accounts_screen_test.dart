import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:scholar_wallet/models/models.dart';
import 'package:scholar_wallet/providers/app_state.dart';
import 'package:scholar_wallet/screens/linked_accounts_screen.dart';
import 'package:scholar_wallet/services/wallet_service.dart';
import 'package:scholar_wallet/theme/app_theme.dart';

class _LinkedWallet implements WalletService {
  @override
  Future<List<LinkedAccount>> getLinkedAccounts(String scholarId) async => [
        LinkedAccount(
          id: 1,
          provider: PayoutProvider.maya,
          bankName: '',
          accountName: 'Alex Scholar',
          accountNumber: '123456789012',
        ),
        LinkedAccount(
          id: 2,
          provider: PayoutProvider.gcash,
          bankName: '',
          accountName: 'Morgan Scholar',
          accountNumber: '098765432109',
        ),
      ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _LinkedAppState extends ChangeNotifier implements AppState {
  @override
  final WalletService wallet = _LinkedWallet();

  @override
  AppUser? user = AppUser(
    id: 'linked-test-scholar',
    fullName: 'Alex Scholar',
    email: 'scholar@example.test',
    verificationStatus: VerificationStatus.approved,
    isActive: true,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('linked accounts omit prototype and account warning copy',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = _LinkedAppState();
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
          home: const LinkedAccountsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'before opening menu');

    expect(find.textContaining('real bank'), findsNothing);
    expect(find.textContaining('No real money'), findsNothing);
    expect(
      find.text('Do not enter real account numbers; use test data.'),
      findsNothing,
    );
    expect(find.text('Alex Scholar'), findsOneWidget);
    expect(find.textContaining('Maya'), findsOneWidget);
    expect(find.textContaining('9012'), findsOneWidget);
    expect(find.text('Link account'), findsOneWidget);

    final menuButton = find.byType(PopupMenuButton<String>).first;
    await tester.ensureVisible(menuButton);
    final menuButtonRect = tester.getRect(menuButton);
    final nextCardName = find.text('Morgan Scholar');
    final nextCardMenuButton = find.byType(PopupMenuButton<String>).last;
    await tester.tap(menuButton);
    await tester.pumpAndSettle();

    expect(find.text('Remove'), findsOneWidget);
    final removeItemFinder = find.byType(PopupMenuItem<String>);
    final removeItem = tester.widget<PopupMenuItem<String>>(removeItemFinder);
    expect(removeItem.height, 40);
    expect(removeItem.padding, EdgeInsets.zero);
    final removeRect = tester.getRect(removeItemFinder);
    final removePill = find
        .ancestor(
          of: find.text('Remove'),
          matching: find.byType(Container),
        )
        .first;
    expect(tester.getRect(removePill), removeRect);
    expect(removeRect.height, 40);
    expect(removeRect.top, closeTo(menuButtonRect.bottom, 1));
    expect(removeRect.right, closeTo(menuButtonRect.right, 1));
    expect(removeRect.overlaps(tester.getRect(nextCardName)), isFalse);
    expect(removeRect.overlaps(tester.getRect(nextCardMenuButton)), isFalse);
    final popup = tester.widget<PopupMenuButton<String>>(menuButton);
    expect(popup.constraints, const BoxConstraints(minWidth: 0));
    expect(popup.menuPadding, EdgeInsets.zero);
    expect(tester.takeException(), isNull);
  });
}
