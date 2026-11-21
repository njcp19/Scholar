import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:scholar_wallet/providers/app_state.dart';
import 'package:scholar_wallet/screens/admin/reports_screen.dart';
import 'package:scholar_wallet/services/wallet_service.dart';
import 'package:scholar_wallet/theme/app_theme.dart';
import 'package:scholar_wallet/widgets/widgets.dart';

class _TestWalletService implements WalletService {
  _TestWalletService({
    this.amountPerScholar = 6000,
    this.batchCount = 1,
  });

  final double amountPerScholar;
  final int batchCount;

  @override
  Future<List<Map<String, dynamic>>> getDisbursements() async => List.generate(
        batchCount,
        (index) => {
          'title': index == 0
              ? 'Monthly Allowance 2026'
              : 'Monthly Allowance 2026 $index',
          'created_at': DateTime.utc(2026, 11, 5 + index).toIso8601String(),
          'recipient_count': 1,
          'amount_per_scholar': amountPerScholar,
        },
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestAppState extends ChangeNotifier implements AppState {
  _TestAppState(this.wallet);

  @override
  final WalletService wallet;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('reports use loaded batch data and omit unavailable export data',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = _TestAppState(_TestWalletService());
    addTearDown(state.dispose);

    for (final theme in [AppTheme.light, AppTheme.dark]) {
      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: state,
          child: MaterialApp(
            theme: theme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.3),
              ),
              child: child!,
            ),
            home: const ReportsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('TOTAL DISBURSED (ALL BATCHES)'), findsOneWidget);
      expect(find.text('1 batch recorded'), findsOneWidget);
      expect(find.text('Monthly Allowance 2026'), findsOneWidget);
      expect(
        find.text('Nov 5, 2026 · 1 scholar × PHP 6,000.00'),
        findsOneWidget,
      );
      expect(find.text('PDF'), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byTooltip('Export report'));
      await tester.pumpAndSettle();

      expect(find.text('Choose a file format for the disbursement report'),
          findsOneWidget);
      expect(find.text('PDF'), findsOneWidget);
      expect(find.text('CSV'), findsOneWidget);
      expect(find.text('Batch summary'), findsOneWidget);
      expect(find.text('Scholar list per batch'), findsNothing);
      expect(find.text('Export PDF'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('reports summary clips shapes at narrow scaled size',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = _TestAppState(
      _TestWalletService(amountPerScholar: 137174.21, batchCount: 9),
    );
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
          home: const ReportsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('TOTAL DISBURSED (ALL BATCHES)'), findsOneWidget);
    expect(find.text('9 batches recorded'), findsOneWidget);
    final label = find.text('TOTAL DISBURSED (ALL BATCHES)');
    final amount = find.bySemanticsLabel('PHP 1,234,567.89');
    final count = find.text('9 batches recorded');
    final card = find.byType(CardDecorShapes);
    final labelLeft = tester.getTopLeft(label).dx;
    expect(labelLeft - tester.getRect(card).left, greaterThanOrEqualTo(20));
    expect(tester.getTopLeft(amount).dx, closeTo(labelLeft, 1));
    expect(tester.getTopLeft(count).dx, closeTo(labelLeft, 1));
    expect(
      amount,
      findsOneWidget,
    );
    final summaryCard = find
        .ancestor(
          of: find.text('TOTAL DISBURSED (ALL BATCHES)'),
          matching: find.byType(AppCard),
        )
        .first;
    final shapeClip = tester.widget<ClipRRect>(
      find
          .descendant(
            of: summaryCard,
            matching: find.byType(ClipRRect),
          )
          .first,
    );
    expect(shapeClip.borderRadius, BorderRadius.circular(28));
    expect(tester.takeException(), isNull);
  });
}
