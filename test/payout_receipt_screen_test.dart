import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:scholar_wallet/models/models.dart';
import 'package:scholar_wallet/providers/app_state.dart';
import 'package:scholar_wallet/screens/payout_receipt_screen.dart';
import 'package:scholar_wallet/theme/app_theme.dart';
import 'package:scholar_wallet/widgets/receipt_layout.dart';
import 'package:scholar_wallet/widgets/widgets.dart';

class _TestAppState extends ChangeNotifier implements AppState {
  _TestAppState(this.user);

  @override
  AppUser? user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('receipt handles missing student ID and receipt date', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = _TestAppState(
      AppUser(
        id: 'scholar-1',
        fullName: 'Alex Scholar',
        email: 'alex@example.edu',
      ),
    );
    addTearDown(state.dispose);
    final claim = AllowanceClaim(
      id: 'payout-1',
      batchId: 'batch-1',
      batchTitle: 'Monthly Allowance',
      scholarId: 'scholar-1',
      scholarName: 'Alex Scholar',
      amount: 6000,
      token: 'token',
      status: ClaimStatus.received,
    );

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
            home: PayoutReceiptScreen(claim: claim),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Receipt'), findsOneWidget);
      expect(find.text('Payout received'), findsOneWidget);
      expect(find.byType(ReceiptHeroCard), findsOneWidget);
      expect(find.byType(CardDecorShapes), findsOneWidget);
      expect(find.text('Not available'), findsOneWidget);
      expect(find.text('Student ID'), findsNothing);
      expect(find.text('RECEIVED'), findsOneWidget);
      expect(find.text('Share receipt'), findsNothing);
      expect(find.text('Save as image'), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });
}
