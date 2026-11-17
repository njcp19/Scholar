import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:scholar_wallet/models/models.dart';
import 'package:scholar_wallet/providers/app_state.dart';
import 'package:scholar_wallet/screens/admin/activity_log_screen.dart';
import 'package:scholar_wallet/services/wallet_service.dart';
import 'package:scholar_wallet/theme/app_theme.dart';

class _TestWalletService implements WalletService {
  _TestWalletService(this.loadClaims);

  final Future<List<AllowanceClaim>> Function(int limit) loadClaims;
  int? requestedLimit;

  @override
  Future<List<AllowanceClaim>> getAllClaims({int limit = 200}) {
    requestedLimit = limit;
    return loadClaims(limit);
  }

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

AllowanceClaim _claim({
  required String id,
  required ClaimStatus status,
  required DateTime? issuedAt,
  DateTime? claimedAt,
}) {
  return AllowanceClaim(
    id: id,
    batchId: 'batch-$id',
    batchTitle: 'Monthly Allowance',
    scholarId: 'scholar-$id',
    scholarName: 'Alex Scholar',
    amount: 6000,
    token: 'token-$id',
    status: status,
    issuedAt: issuedAt,
    claimedAt: claimedAt,
  );
}

void main() {
  testWidgets('activity log uses available payout events in both themes',
      (tester) async {
    tester.view.physicalSize = const Size(360, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _TestWalletService(
      (_) async => [
        _claim(
          id: 'received',
          status: ClaimStatus.received,
          issuedAt: DateTime(2026, 11, 5, 20, 52),
          claimedAt: DateTime(2026, 11, 5, 20, 57),
        ),
        _claim(
          id: 'voided',
          status: ClaimStatus.voided,
          issuedAt: DateTime(2026, 11, 6, 10, 37),
        ),
        _claim(
          id: 'issued',
          status: ClaimStatus.issued,
          issuedAt: DateTime(2026, 11, 11, 16, 9),
        ),
      ],
    );
    final state = _TestAppState(service);
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
            home: const ActivityLogScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(service.requestedLimit, 200);
      expect(find.text('Activity Log'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Payouts'), findsOneWidget);
      expect(
          find.text(
              'Read-only. This list is built from existing payout records.'),
          findsOneWidget);
      expect(
          find.text(
              'Cancelled entries show the available payout-record date; the cancellation time is not stored.'),
          findsOneWidget);
      expect(find.text('Showing the latest 200 records.'), findsNothing);
      expect(find.text('Scholars'), findsNothing);
      expect(find.text('Settings'), findsNothing);
      expect(find.text('Cash Outs'), findsNothing);
      expect(tester.takeException(), isNull);

      expect(find.text('Payout issued'), findsNWidgets(3));
      expect(find.text('Payout received'), findsOneWidget);
      expect(find.text('Payout cancelled'), findsOneWidget);
      expect(find.textContaining('confirmed with device biometrics'),
          findsOneWidget);

      await tester.tap(find.text('Payouts'));
      await tester.pumpAndSettle();
      expect(find.text('Payout received'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
      'activity log scrolls on a compact screen at increased text scale',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _TestWalletService(
      (_) async => [
        _claim(
          id: 'received',
          status: ClaimStatus.received,
          issuedAt: DateTime(2026, 11, 5, 20, 52),
          claimedAt: DateTime(2026, 11, 5, 20, 57),
        ),
      ],
    );
    final state = _TestAppState(service);
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
          home: const ActivityLogScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.drag(find.byType(ListView).last, const Offset(0, -240));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('activity log notes when the 200-record limit is reached',
      (tester) async {
    final service = _TestWalletService(
      (_) async => List.generate(
        200,
        (index) => _claim(
          id: 'record-$index',
          status: ClaimStatus.issued,
          issuedAt: DateTime(2026, 11, 11).subtract(Duration(minutes: index)),
        ),
      ),
    );
    final state = _TestAppState(service);
    addTearDown(state.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ActivityLogScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Showing the latest 200 records.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('activity log shows an empty state and retries load errors',
      (tester) async {
    var attempts = 0;
    final service = _TestWalletService((_) async {
      attempts++;
      if (attempts == 1) throw StateError('offline');
      return [];
    });
    final state = _TestAppState(service);
    addTearDown(state.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ActivityLogScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not load activity.'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('No activity yet.'), findsOneWidget);
    expect(attempts, 2);
    expect(tester.takeException(), isNull);
  });
}
