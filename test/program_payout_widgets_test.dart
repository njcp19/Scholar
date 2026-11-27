import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:scholar_wallet/models/models.dart';
import 'package:scholar_wallet/providers/app_state.dart';
import 'package:scholar_wallet/screens/admin/issue_payout_screen.dart';
import 'package:scholar_wallet/screens/admin/program_payout_qr_screen.dart';
import 'package:scholar_wallet/services/qr_service.dart';
import 'package:scholar_wallet/services/scholarship_catalog_service.dart';
import 'package:scholar_wallet/services/wallet_service.dart';
import 'package:scholar_wallet/theme/app_theme.dart';
import 'package:scholar_wallet/widgets/widgets.dart';

void main() {
  test('event QR reuses the established claim v1 payload envelope', () {
    final claim = AllowanceClaim(
      id: 'batch-1',
      batchId: 'batch-1',
      batchTitle: 'Semester payout',
      scholarId: '',
      scholarName: 'STEM Scholars',
      amount: 5000,
      token: 'event-token',
    );

    final payload = jsonDecode(claim.qrPayload) as Map<String, dynamic>;

    expect(payload, {
      't': 'scholar_wallet_claim_v1',
      'tok': 'event-token',
      'cid': 'batch-1',
      'sid': '',
      'amt': 5000,
    });
    expect(ClaimQrPayload.tryParse(claim.qrPayload)?.isProgramEvent, isTrue);
  });

  testWidgets('program picker lists and selects a catalog program',
      (tester) async {
    const program = ScholarshipCatalogItem(
      id: 1,
      name: 'STEM Scholars',
      isActive: true,
    );
    ScholarshipCatalogItem? selected;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ProgramPayoutPicker(
            programs: const [program],
            selectedProgram: selected,
            onChanged: (value) => selected = value,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('program-payout-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('STEM Scholars').last);
    await tester.pumpAndSettle();

    expect(selected, same(program));
  });

  testWidgets('program roster displays names and selected count',
      (tester) async {
    const roster = [
      ProgramRosterScholar(
        id: 'scholar-1',
        fullName: 'Alex Scholar',
        scholarshipName: 'STEM Scholars',
      ),
      ProgramRosterScholar(
        id: 'scholar-2',
        fullName: 'Jamie Scholar',
        scholarshipName: 'STEM Scholars',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ProgramRosterChecklist(
            roster: roster,
            selectedIds: const {'scholar-1', 'scholar-2'},
            loading: false,
            hasProgram: true,
            onToggle: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Alex Scholar'), findsOneWidget);
    expect(find.text('Jamie Scholar'), findsOneWidget);
    expect(find.text('2 of 2 selected'), findsOneWidget);
  });

  testWidgets('over-budget warning disables issue action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ProgramPayoutIssueAction(
            canIssue: false,
            overBudget: true,
            insufficientFunds: false,
            loading: false,
            onPressed: () {},
          ),
        ),
      ),
    );

    expect(
      find.text("This payout is over the program's remaining budget."),
      findsOneWidget,
    );
    final button = tester.widget<PrimaryButton>(
      find.byKey(const ValueKey('issue-program-payout')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('program event QR is not rendered for a scholar', (tester) async {
    final state = _ScholarAppState();
    addTearDown(state.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ProgramPayoutQrScreen(
            batchId: 'batch-1',
            programName: 'STEM Scholars',
            title: 'Semester payout',
            amountPerScholar: 5000,
            recipientNames: ['Alex Scholar'],
            eventToken: 'secret-event-token',
          ),
        ),
      ),
    );

    expect(find.text('This page is available to admins only.'), findsOneWidget);
    expect(find.byType(ClaimQrPanel), findsNothing);
    expect(find.text('secret-event-token'), findsNothing);
  });
}

class _ScholarAppState extends ChangeNotifier implements AppState {
  @override
  final WalletService wallet = _UnusedWalletService();

  @override
  AppUser? user = AppUser(
    id: 'scholar-1',
    fullName: 'Alex Scholar',
    email: 'alex@example.test',
    role: UserRole.scholar,
    verificationStatus: VerificationStatus.approved,
    isActive: true,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnusedWalletService implements WalletService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
