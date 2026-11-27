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
import 'helpers/card_layering_test_utils.dart';

class _AdminHeroWallet implements WalletService {
  final List<AllowanceClaim> payouts;
  final List<Map<String, dynamic>> disbursements;

  _AdminHeroWallet({
    this.payouts = const [],
    this.disbursements = const [],
  });

  @override
  Future<List<AllowanceClaim>> getAllClaims({int limit = 200}) async => payouts;

  @override
  Future<List<Map<String, dynamic>>> getDisbursements() async => disbursements;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ManageScholarsWallet implements WalletService {
  _ManageScholarsWallet(this.scholars);

  final List<Scholar> scholars;
  final List<String> deletedIds = [];
  final List<String> toggledIds = [];
  final List<bool> activeValues = [];

  @override
  Future<List<Scholar>> getScholars() async => List.of(scholars);

  @override
  Future<void> setScholarActive(String id, bool active) async {
    toggledIds.add(id);
    activeValues.add(active);
  }

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
    final wallet = _ManageScholarsWallet([scholar]);
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

  testWidgets('Manage Scholars shows scholarship chips only when named',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final longScholarshipName =
        '${List.filled(12, 'Scholarship').join(' ')} Award';
    final wallet = _ManageScholarsWallet([
      Scholar(
        id: 'named-scholar',
        studentId: 'NAMED-1',
        name: 'Named Scholar',
        balance: 0,
        scholarshipName: longScholarshipName,
        verificationStatus: VerificationStatus.approved,
      ),
      Scholar(
        id: 'unnamed-scholar',
        studentId: 'EMPTY-1',
        name: 'Unnamed Scholar',
        balance: 0,
        scholarshipName: '',
        verificationStatus: VerificationStatus.approved,
      ),
    ]);
    final state = _AdminHeroState(wallet);
    addTearDown(state.dispose);

    await tester.pumpWidget(
      _app(state, const ManageScholarsScreen(), textScale: 1.3),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Named Scholar'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text(longScholarshipName), findsOneWidget);
    expect(
      find.byKey(const ValueKey('scholarship-chip-named-scholar')),
      findsOneWidget,
    );
    expect(find.text('Verified'), findsNWidgets(2));
    await tester.scrollUntilVisible(
      find.text('Unnamed Scholar'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Unnamed Scholar'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('scholarship-chip-unnamed-scholar')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Manage Scholars delete aligns with switch at multiple card widths',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final wallet = _ManageScholarsWallet([
      Scholar(
        id: 'width-alignment-scholar',
        studentId: 'WIDTH-1',
        name: 'Width Alignment Scholar',
        balance: 1000,
        active: true,
        verificationStatus: VerificationStatus.approved,
      ),
    ]);
    final state = _AdminHeroState(wallet);
    addTearDown(state.dispose);

    await tester.pumpWidget(
      _app(state, const ManageScholarsScreen(), textScale: 1),
    );
    await tester.pumpAndSettle();

    for (final width in [360.0, 390.0, 1200.0]) {
      tester.view.physicalSize = Size(width, 800);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Receives allowance'),
        160,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('PHP 1,000.00'), findsNothing);
      _expectCardActionRightEdges(tester, 'Receives allowance');
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
      'Manage Scholars centers captions and preserves card callbacks at narrow scale',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final longName = List.filled(40, 'N').join();
    final wallet = _ManageScholarsWallet([
      Scholar(
        id: 'alignment-scholar',
        studentId: 'ALIGN-1',
        name: longName,
        balance: 1000,
        active: true,
        verificationStatus: VerificationStatus.approved,
      ),
      Scholar(
        id: 'paused-alignment-scholar',
        studentId: 'PAUSED-1',
        name: 'Paused Scholar',
        balance: 0,
        active: false,
        verificationStatus: VerificationStatus.approved,
      ),
    ]);
    final state = _AdminHeroState(wallet);
    addTearDown(state.dispose);

    await tester.pumpWidget(
      _app(state, const ManageScholarsScreen(), textScale: 1.3),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text(longName),
      240,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Receives allowance'), findsOneWidget);
    expect(find.text('PHP 1,000.00'), findsNothing);
    _expectToggleCaptionInsideCard(tester, 'Receives allowance');
    _expectCardActionRightEdges(tester, 'Receives allowance');
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.text('Inactive'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Inactive'), findsOneWidget);
    _expectToggleCaptionInsideCard(tester, 'Inactive');
    _expectCardActionRightEdges(tester, 'Inactive');

    await tester.scrollUntilVisible(
      find.text(longName),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    final switchFinder = find.byType(Switch).first;
    final deleteTarget = find
        .ancestor(
          of: find.text('Delete').first,
          matching: find.byType(InkWell),
        )
        .first;
    final activeCaption = tester.getRect(find.text('Receives allowance'));
    expect(tester.getRect(switchFinder).right, closeTo(activeCaption.right, 1));
    expect(
      tester.getRect(find.text(longName)).right,
      lessThanOrEqualTo(activeCaption.left - 8),
    );
    expect(tester.getSize(deleteTarget).height, greaterThanOrEqualTo(44));

    await tester.tap(deleteTarget);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('manage-scholar-delete-cancel')),
    );
    await tester.pumpAndSettle();
    expect(wallet.deletedIds, isEmpty);

    await tester.tap(switchFinder);
    await tester.pumpAndSettle();
    expect(wallet.toggledIds, ['alignment-scholar']);
    expect(wallet.activeValues, [false]);

    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Manage Scholars excludes rejected registrations from metrics and search',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final wallet = _ManageScholarsWallet([
      Scholar(
        id: 'approved-id',
        studentId: 'APP-1',
        name: 'Approved Scholar',
        balance: 0,
        active: true,
        verificationStatus: VerificationStatus.approved,
      ),
      Scholar(
        id: 'pending-id',
        studentId: 'PEN-1',
        name: 'Pending Scholar',
        balance: 0,
        active: false,
        verificationStatus: VerificationStatus.pending,
      ),
      Scholar(
        id: 'under-review-id',
        studentId: 'REV-1',
        name: 'Under Review Scholar',
        balance: 0,
        active: false,
        verificationStatus: VerificationStatus.underReview,
      ),
      Scholar(
        id: 'rejected-id',
        studentId: 'REJ-1',
        name: 'Rejected Applicant',
        balance: 0,
        active: true,
        verificationStatus: VerificationStatus.rejected,
      ),
    ]);
    final state = _AdminHeroState(wallet);
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
          home: const ManageScholarsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('TOTAL SCHOLARS'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('1 verified'), findsOneWidget);
    expect(find.text('1 allowance on'), findsOneWidget);
    final heroCard = find.byType(ManageScholarsHeroCard);
    expectNoForegroundPaint(tester, heroCard);
    expect(
      find.text('SCHOLARS (3) · TOGGLE TO CONTROL ALLOWANCE'),
      findsOneWidget,
    );
    expect(find.text('Approved Scholar'), findsOneWidget);
    expect(find.text('Pending Scholar'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Under Review Scholar'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Under Review Scholar'), findsOneWidget);
    expect(find.text('Rejected Applicant'), findsNothing);
    expect(tester.takeException(), isNull);

    final searchField = find.byType(TextField).first;
    await tester.ensureVisible(searchField);
    await tester.enterText(searchField, 'Rejected Applicant');
    await tester.pumpAndSettle();

    expect(find.text('REJ-1'), findsNothing);
    expect(find.text('No matching scholars'), findsOneWidget);
    expect(
      find.text('SCHOLARS (0) · TOGGLE TO CONTROL ALLOWANCE'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Manage Scholars shows its empty state when only rejected are returned',
      (tester) async {
    final state = _AdminHeroState(
      _ManageScholarsWallet([
        Scholar(
          id: 'rejected-id',
          studentId: 'REJ-1',
          name: 'Rejected Applicant',
          balance: 0,
          verificationStatus: VerificationStatus.rejected,
        ),
      ]),
    );
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

    expect(find.text('No scholars registered yet'), findsOneWidget);
    expect(
      find.text('SCHOLARS (0) · TOGGLE TO CONTROL ALLOWANCE'),
      findsOneWidget,
    );
    expect(find.text('Rejected Applicant'), findsNothing);
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

    final hero = find.byType(ManageScholarsHeroCard);
    expect(find.text('TOTAL SCHOLARS'), findsOneWidget);
    expect(find.text('1000'), findsOneWidget);
    expectNoForegroundPaint(tester, hero);
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

    final hero = find
        .ancestor(
          of: find.text('TOTAL PAID OUT'),
          matching: find.byType(Container),
        )
        .first;
    expect(tester.getSize(hero).height, inInclusiveRange(120, 130));

    tester.view.physicalSize = const Size(320, 640);
    await tester.pumpWidget(
      _app(state, const ClaimsMonitorScreen(), textScale: 1.3),
    );
    await tester.pumpAndSettle();

    expect(find.text('TOTAL PAID OUT'), findsOneWidget);
    final label = find.text('TOTAL PAID OUT');
    final amount = find.bySemanticsLabel('PHP 1,234,567.89');
    expectNoForegroundPaint(tester, hero);
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

  testWidgets('Payout Monitor wraps a long scholar name to two lines',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const name = 'Kuro Marie Cuadro Penera';
    final claim = _monitorClaim(id: 'long-name', name: name);
    final state = _AdminHeroState(_AdminHeroWallet(payouts: [claim]));
    addTearDown(state.dispose);

    await tester.pumpWidget(
      _app(state, const ClaimsMonitorScreen(), textScale: 1.3),
    );
    await tester.pumpAndSettle();
    await _showMonitorRows(tester);

    final nameFinder = find.text(name);
    final nameText = tester.widget<Text>(nameFinder);
    expect(nameText.maxLines, 2);
    expect(nameText.softWrap, isTrue);
    expect(nameText.overflow, TextOverflow.ellipsis);
    expect(tester.getSize(nameFinder).height, greaterThan(30));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Payout Monitor status chip shows its full text', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = _AdminHeroState(
      _AdminHeroWallet(
        payouts: [_monitorClaim(id: 'status-chip', name: 'Jordan Lee')],
      ),
    );
    addTearDown(state.dispose);

    await tester.pumpWidget(
      _app(state, const ClaimsMonitorScreen(), textScale: 1.3),
    );
    await tester.pumpAndSettle();
    await _showMonitorRows(tester);

    final statusFinder = find.text('Waiting for scan');
    expect(statusFinder, findsOneWidget);
    expect(
      find.ancestor(of: statusFinder, matching: find.byType(Wrap)),
      findsOneWidget,
    );
    expect(tester.getSize(statusFinder).width, greaterThan(90));
    expect(tester.takeException(), isNull);
  });

  testWidgets('legacy payout row shows its QR button below the amount',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final claim = _monitorClaim(id: 'legacy-qr', name: 'Jordan Lee');
    final state = _AdminHeroState(_AdminHeroWallet(payouts: [claim]));
    addTearDown(state.dispose);

    await tester.pumpWidget(
      _app(state, const ClaimsMonitorScreen(), textScale: 1.3),
    );
    await tester.pumpAndSettle();
    await _showMonitorRows(tester);

    final qrButton = find.byTooltip('View QR');
    expect(qrButton, findsOneWidget);
    expect(
      tester.getTopLeft(qrButton).dy,
      greaterThan(tester.getBottomLeft(find.text('PHP 1,000.00')).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Payout Monitor All excludes cancelled rows and QR follows status',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = _AdminHeroState(
      _AdminHeroWallet(
        payouts: [
          _monitorClaim(id: 'legacy-waiting', name: 'Legacy Waiting'),
          _monitorClaim(
            id: 'legacy-received',
            name: 'Legacy Received',
            status: ClaimStatus.received,
          ),
          _monitorClaim(
            id: 'legacy-cancelled',
            name: 'Legacy Cancelled',
            status: ClaimStatus.voided,
          ),
        ],
      ),
    );
    addTearDown(state.dispose);

    await tester.pumpWidget(
      _app(state, const ClaimsMonitorScreen(), textScale: 1.3),
    );
    await tester.pumpAndSettle();
    await _showMonitorRows(tester);

    expect(find.text('Cancelled'), findsNothing);
    expect(find.text('Legacy Cancelled'), findsNothing);
    expect(find.text('Legacy Waiting'), findsOneWidget);
    expect(find.text('Legacy Received'), findsOneWidget);
    expect(find.text('AUGUST 2026 · 2 PAYOUTS'), findsOneWidget);
    expect(find.byTooltip('View QR'), findsOneWidget);

    await _showMonitorFilters(tester);
    final receivedFilter = find.ancestor(
      of: find.text('Received'),
      matching: find.byType(ChoiceChip),
    );
    await tester.tap(receivedFilter);
    await tester.pumpAndSettle();
    await _showMonitorRows(tester);
    expect(find.text('Legacy Received'), findsOneWidget);
    expect(find.byTooltip('View QR'), findsNothing);

    await _showMonitorFilters(tester);
    final waitingFilter = find.ancestor(
      of: find.text('Waiting'),
      matching: find.byType(ChoiceChip),
    );
    await tester.tap(waitingFilter);
    await tester.pumpAndSettle();
    await _showMonitorRows(tester);
    expect(find.text('Legacy Waiting'), findsOneWidget);
    expect(find.byTooltip('View QR'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('program payout row hides the per-row QR button', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final claim = _monitorClaim(
      id: 'program-row',
      name: 'Jordan Lee',
      batchId: 'program-batch',
    );
    final state = _AdminHeroState(
      _AdminHeroWallet(
        payouts: [
          claim,
          _monitorClaim(
            id: 'program-row-second',
            name: 'Taylor Kim',
            batchId: 'program-batch',
          ),
          _monitorClaim(
            id: 'program-row-received',
            name: 'Casey Park',
            batchId: 'program-batch',
            status: ClaimStatus.received,
          ),
          _monitorClaim(
            id: 'program-received-only',
            name: 'Received Program Scholar',
            batchId: 'received-program-batch',
            status: ClaimStatus.received,
          ),
        ],
        disbursements: const [
          {'id': 'program-batch', 'program_name': 'STEM Scholars'},
          {
            'id': 'received-program-batch',
            'program_name': 'Arts Scholars',
          },
        ],
      ),
    );
    addTearDown(state.dispose);

    await tester.pumpWidget(
      _app(state, const ClaimsMonitorScreen(), textScale: 1.3),
    );
    await tester.pumpAndSettle();
    await _showMonitorRows(tester);

    expect(find.byTooltip('View QR'), findsNothing);
    expect(find.text('Show event QR'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('payout-row-program-received-only')),
        matching: find.text('Show event QR'),
      ),
      findsNothing,
    );
    await _showMonitorFilters(tester);
    final receivedFilter = find.ancestor(
      of: find.text('Received'),
      matching: find.byType(ChoiceChip),
    );
    await tester.tap(receivedFilter);
    await tester.pumpAndSettle();
    await _showMonitorRows(tester);
    expect(find.text('Show event QR'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('payout-row-program-received-only')),
        matching: find.text('Show event QR'),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _showMonitorRows(WidgetTester tester) async {
  await tester.drag(find.byType(ListView).last, const Offset(0, -900));
  await tester.pumpAndSettle();
}

Future<void> _showMonitorFilters(WidgetTester tester) async {
  await tester.drag(find.byType(ListView).last, const Offset(0, 900));
  await tester.pumpAndSettle();
}

AllowanceClaim _monitorClaim({
  required String id,
  required String name,
  String batchId = 'legacy-batch',
  ClaimStatus status = ClaimStatus.issued,
  DateTime? claimedAt,
}) =>
    AllowanceClaim(
      id: id,
      batchId: batchId,
      batchTitle: 'Payout event',
      scholarId: 'scholar-1',
      scholarName: name,
      amount: 1000,
      token: 'token-$id',
      status: status,
      issuedAt: DateTime(2026, 8, 15, 10),
      claimedAt: claimedAt,
    );

void _expectToggleCaptionInsideCard(WidgetTester tester, String caption) {
  final captionFinder = find.text(caption);
  final cardFinder =
      find.ancestor(of: captionFinder, matching: find.byType(AppCard)).first;
  final captionRect = tester.getRect(captionFinder);
  final cardRect = tester.getRect(cardFinder);
  final text = tester.widget<Text>(captionFinder);

  expect(captionRect.right, lessThanOrEqualTo(cardRect.right - 8));
  expect(captionRect.left, greaterThanOrEqualTo(cardRect.left + 8));
  expect(text.maxLines, 2);
  expect(text.softWrap, isTrue);
  expect(text.textAlign, TextAlign.end);
  expect(text.overflow, TextOverflow.clip);
  expect(text.style?.fontSize, 11);
}

void _expectCardActionRightEdges(WidgetTester tester, String caption) {
  final card = find
      .ancestor(
        of: find.text(caption),
        matching: find.byType(AppCard),
      )
      .first;
  final switchRect = tester.getRect(
    find.descendant(of: card, matching: find.byType(Switch)),
  );
  final deleteLabel = find.descendant(of: card, matching: find.text('Delete'));
  final deleteButton = find.ancestor(
    of: deleteLabel,
    matching: find.byType(InkWell),
  );
  final deleteVisual = find.ancestor(
    of: deleteLabel,
    matching: find.byType(Ink),
  );
  final cardRect = tester.getRect(card);
  expect(switchRect.right, closeTo(tester.getRect(deleteButton).right, 1));
  expect(switchRect.right, closeTo(tester.getRect(deleteVisual).right, 1));
  expect(switchRect.right, closeTo(cardRect.right - 16, 1));
  expect(switchRect.height, greaterThanOrEqualTo(48));
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
