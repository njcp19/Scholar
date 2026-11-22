import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:scholar_wallet/models/models.dart';
import 'package:scholar_wallet/providers/app_state.dart';
import 'package:scholar_wallet/screens/admin/funding_account_screen.dart';
import 'package:scholar_wallet/services/wallet_service.dart';
import 'package:scholar_wallet/theme/app_theme.dart';
import 'package:scholar_wallet/widgets/widgets.dart';
import 'helpers/card_layering_test_utils.dart';

class _FundingWallet implements WalletService {
  @override
  Future<FundingAccount?> getFundingAccount() async => FundingAccount(
        bankName: 'Sample Bank',
        accountName: 'Scholar Fund',
        last4: '1234',
        linkedAt: DateTime(2026, 8, 15),
      );

  @override
  Future<FundSummary> getFundSummary() async => const FundSummary(
        available: 1234567.89,
        reserved: 2000,
        disbursed: 3000,
      );

  @override
  Future<List<FundEntry>> getFundActivity({int limit = 30}) async => [
        FundEntry(
          id: 1,
          kind: FundEntryKind.topup,
          amount: 5000,
          note: 'Simulated top-up',
          createdAt: DateTime(2026, 8, 15),
        ),
      ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FundingAppState extends ChangeNotifier implements AppState {
  @override
  final WalletService wallet = _FundingWallet();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('allocation sheet fits a long action label at compact scale',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = _FundingAppState();
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
          home: const FundingAccountScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Allocate Funds'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '25000');
    await tester.pumpAndSettle();

    final actionLabel = find.text('Allocate PHP 25,000.00');
    await tester.scrollUntilVisible(
      actionLabel,
      240,
      scrollable: find.byType(Scrollable).last,
    );
    expect(actionLabel, findsOneWidget);
    expect(find.text('Sample Bank'), findsWidgets);
    expect(find.text('•••• 1234'), findsOneWidget);
    expect(find.textContaining('real bank'), findsNothing);
    expect(find.textContaining('No real money'), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fund summary clips shapes and fits a large amount',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = _FundingAppState();
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
          home: const FundingAccountScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AVAILABLE FUND'), findsOneWidget);
    final amount = find.bySemanticsLabel('PHP 1,234,567.89');
    expect(amount, findsOneWidget);
    expect(find.text('Reserved for payouts'), findsOneWidget);
    expect(find.text('Disbursed so far'), findsOneWidget);
    expect(find.text('Allocate Funds'), findsOneWidget);

    final label = find.text('AVAILABLE FUND');
    final labelLeft = tester.getTopLeft(label).dx;
    expect(
      labelLeft - tester.getRect(find.byType(CardDecorShapes)).left,
      greaterThanOrEqualTo(20),
    );
    expect(tester.getTopLeft(amount).dx, closeTo(labelLeft, 1));

    final summaryCard = find
        .ancestor(
          of: find.text('AVAILABLE FUND'),
          matching: find.byType(AppCard),
        )
        .first;
    expectNoForegroundPaint(tester, summaryCard);
    expectCardDecorShapesLayeredBehindContent(tester, summaryCard);
    final shapeClip = tester.widget<ClipRRect>(
      find
          .descendant(
            of: summaryCard,
            matching: find.byType(ClipRRect),
          )
          .first,
    );
    expect(shapeClip.borderRadius, BorderRadius.circular(28));

    await tester.scrollUntilVisible(find.text('FUND ACTIVITY'), 300);
    await tester.pumpAndSettle();
    expect(find.text('Allocate Funds'), findsNWidgets(2));
    expect(find.textContaining('Funds allocated'), findsOneWidget);
    expect(find.textContaining('Simulated top-up'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
