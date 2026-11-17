import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:scholar_wallet/providers/app_state.dart';
import 'package:scholar_wallet/screens/admin/reports_screen.dart';
import 'package:scholar_wallet/services/wallet_service.dart';
import 'package:scholar_wallet/theme/app_theme.dart';

class _TestWalletService implements WalletService {
  @override
  Future<List<Map<String, dynamic>>> getDisbursements() async => [
        {
          'title': 'Monthly Allowance 2026',
          'created_at': '2026-11-05T00:00:00Z',
          'recipient_count': 1,
          'amount_per_scholar': 6000,
        },
      ];

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
}
