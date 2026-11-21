import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:scholar_wallet/models/models.dart';
import 'package:scholar_wallet/providers/app_state.dart';
import 'package:scholar_wallet/screens/admin/claims_monitor_screen.dart';
import 'package:scholar_wallet/screens/admin/manage_scholars_screen.dart';
import 'package:scholar_wallet/services/wallet_service.dart';
import 'package:scholar_wallet/theme/app_theme.dart';
import 'package:scholar_wallet/widgets/app_icons.dart';
import 'package:scholar_wallet/widgets/destructive_confirm_dialog.dart';
import 'package:scholar_wallet/widgets/widgets.dart';

class _AdminHeroWallet implements WalletService {
  final List<AllowanceClaim> payouts;

  _AdminHeroWallet({
    this.payouts = const [],
  });

  @override
  Future<List<AllowanceClaim>> getAllClaims({int limit = 200}) async => payouts;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ManageScholarsWallet implements WalletService {
  _ManageScholarsWallet(this.scholar);

  final Scholar scholar;
  final List<String> deletedIds = [];

  @override
  Future<List<Scholar>> getScholars() async => [scholar];

  @override
  Future<void> deleteScholar(String id) async {
    deletedIds.add(id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AdminHeroState extends ChangeNotifier implements AppState {
  _AdminHeroState(this._wallet);

  final WalletService _wallet;

  @override
  WalletService get wallet => _wallet;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('Manage Scholars delete dialog fits a long name at narrow scale',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final longName = List.filled(40, 'S').join();
    final title = 'Delete $longName?';
    final body = 'This will permanently remove $longName and all of their '
        'transaction, payout, linked-account, and registration-review records. '
        'Accounts with a balance cannot be deleted. This cannot be undone.';
    bool? dialogResult;

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
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () async {
                  dialogResult = await DestructiveConfirmDialog.show(
                    context,
                    title: title,
                    message: body,
                    dismissLabel: 'Cancel',
                    confirmLabel: 'Delete',
                    semanticsLabel: 'Delete scholar confirmation',
                    icon: AppIcons.delete,
                    dismissButtonKey:
                        const ValueKey('manage-scholar-delete-cancel'),
                    confirmButtonKey:
                        const ValueKey('manage-scholar-delete-confirm'),
                  );
                },
                child: const Text('Open dialog'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();
    expect(find.text(title), findsOneWidget);
    expect(find.text(body), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    expect(
      tester.widgetList<Semantics>(find.byType(Semantics)).where(
            (widget) =>
                widget.properties.label == 'Delete scholar confirmation',
          ),
      hasLength(1),
    );
    expect(tester.takeException(), isNull);

    await tester
        .tap(find.byKey(const ValueKey('manage-scholar-delete-cancel')));
    await tester.pumpAndSettle();
    expect(dialogResult, isFalse);

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(const ValueKey('manage-scholar-delete-confirm')));
    await tester.pumpAndSettle();
    expect(dialogResult, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Manage Scholars deletes only after confirmation',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final scholar = Scholar(
      id: 'test-scholar',
      studentId: '12345',
      name: 'Test Scholar',
      balance: 0,
      verificationStatus: VerificationStatus.approved,
    );
    final wallet = _ManageScholarsWallet(scholar);
    final state = _AdminHeroState(wallet);
    addTearDown(state.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ManageScholarsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete').first);
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(const ValueKey('manage-scholar-delete-cancel')));
    await tester.pumpAndSettle();
    expect(wallet.deletedIds, isEmpty);
    expect(find.text('Test Scholar'), findsOneWidget);

    await tester.tap(find.text('Delete').first);
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(const ValueKey('manage-scholar-delete-confirm')));
    await tester.pumpAndSettle();
    expect(wallet.deletedIds, ['test-scholar']);
    expect(find.text('Test Scholar'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Manage Scholars hero fits a thousand at narrow scale',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.3),
          ),
          child: child!,
        ),
        home: const Scaffold(
          body: Center(
            child: SizedBox(
              width: 280,
              child: ManageScholarsHeroCard(
                scholarCount: 1000,
                verifiedCount: 0,
                activeCount: 0,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final hero = find.byType(CardDecorShapes);
    expect(find.text('TOTAL SCHOLARS'), findsOneWidget);
    expect(find.text('1000'), findsOneWidget);
    expect(find.text('0 verified'), findsOneWidget);
    expect(find.text('0 allowance on'), findsOneWidget);
    expect(find.byType(HeroAmountText), findsOneWidget);
    final label = find.text('TOTAL SCHOLARS');
    final amount = find.bySemanticsLabel('1000');
    final labelLeft = tester.getTopLeft(label).dx;
    expect(labelLeft - tester.getRect(hero).left, greaterThanOrEqualTo(20));
    expect(tester.getTopLeft(amount).dx, closeTo(labelLeft, 1));
    expect(
      tester
          .getRect(
            find
                .ancestor(
                  of: find.text('0 verified'),
                  matching: find.byType(Container),
                )
                .first,
          )
          .left,
      closeTo(labelLeft, 1),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Payout Monitor hero and stat cards fit at narrow scale',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = _AdminHeroState(
      _AdminHeroWallet(payouts: _payouts()),
    );
    addTearDown(state.dispose);

    await tester.pumpWidget(
      _app(state, const ClaimsMonitorScreen(), textScale: 1),
    );
    await tester.pumpAndSettle();

    final hero = find.byType(CardDecorShapes);
    expect(tester.getSize(hero).height, inInclusiveRange(120, 130));

    tester.view.physicalSize = const Size(320, 640);
    await tester.pumpWidget(
      _app(state, const ClaimsMonitorScreen(), textScale: 1.3),
    );
    await tester.pumpAndSettle();

    expect(find.text('TOTAL PAID OUT'), findsOneWidget);
    final label = find.text('TOTAL PAID OUT');
    final amount = find.bySemanticsLabel('PHP 1,234,567.89');
    final labelLeft = tester.getTopLeft(label).dx;
    expect(labelLeft - tester.getRect(hero).left, greaterThanOrEqualTo(20));
    expect(tester.getTopLeft(amount).dx, closeTo(labelLeft, 1));
    final statusPill = find
        .ancestor(
          of: find.text('1 payout verified by QR'),
          matching: find.byType(Container),
        )
        .first;
    expect(tester.getRect(statusPill).left, closeTo(labelLeft, 1));
    expect(
      amount,
      findsOneWidget,
    );
    expect(find.text('1 payout verified by QR'), findsOneWidget);
    expect(find.bySemanticsLabel('PHP 13,000.00'), findsOneWidget);

    final waiting = find
        .ancestor(of: find.text('Waiting'), matching: find.byType(AppCard))
        .first;
    final received = find
        .ancestor(of: find.text('Received'), matching: find.byType(AppCard))
        .first;
    final reserved = find
        .ancestor(of: find.text('Reserved'), matching: find.byType(AppCard))
        .first;
    expect(tester.getSize(waiting).height, tester.getSize(received).height);
    expect(tester.getSize(received).height, tester.getSize(reserved).height);
    expect(tester.takeException(), isNull);
  });
}

Widget _app(
  AppState state,
  Widget home, {
  required double textScale,
}) {
  return ChangeNotifierProvider<AppState>.value(
    value: state,
    child: MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: home,
    ),
  );
}

List<AllowanceClaim> _payouts() {
  final date = DateTime(2026, 8, 15, 10);
  return [
    AllowanceClaim(
      id: 'waiting-1',
      batchId: 'batch-1',
      batchTitle: 'First payout',
      scholarId: 'scholar-1',
      scholarName: 'Test Scholar',
      amount: 6000,
      token: 'token-1',
      issuedAt: date,
    ),
    AllowanceClaim(
      id: 'waiting-2',
      batchId: 'batch-2',
      batchTitle: 'Second payout',
      scholarId: 'scholar-1',
      scholarName: 'Test Scholar',
      amount: 7000,
      token: 'token-2',
      issuedAt: date,
    ),
    AllowanceClaim(
      id: 'received-1',
      batchId: 'batch-3',
      batchTitle: 'Third payout',
      scholarId: 'scholar-1',
      scholarName: 'Test Scholar',
      amount: 1234567.89,
      token: 'token-3',
      status: ClaimStatus.received,
      issuedAt: date,
      claimedAt: date,
    ),
  ];
}
