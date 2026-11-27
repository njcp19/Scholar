import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:scholar_wallet/models/models.dart';
import 'package:scholar_wallet/providers/app_state.dart';
import 'package:scholar_wallet/services/qr_service.dart';
import 'package:scholar_wallet/screens/payout_confirmation_screen.dart';
import 'package:scholar_wallet/screens/verification_screen.dart';
import 'package:scholar_wallet/theme/app_theme.dart';

Map<String, dynamic> profile(
        {String status = 'pending',
        bool active = false,
        String role = 'scholar'}) =>
    {
      'id': 'student-1',
      'full_name': 'Test Scholar',
      'email': 'test@school.edu',
      'verification_status': status,
      'is_active': active,
      'role': role,
      'declared_scholar': true,
      'scholarship_name': 'School Merit Award',
    };

void main() {
  group('registration eligibility', () {
    for (final status in [
      'pending',
      'under_review',
      'needs_info',
      'rejected'
    ]) {
      test(
          '$status cannot receive allowance even if active was incorrectly set',
          () {
        expect(
            AppUser.fromMap(profile(status: status, active: true))
                .canReceiveAllowance,
            false);
      });
    }
    test('approved and active scholar can receive allowance', () {
      expect(
          AppUser.fromMap(profile(status: 'approved', active: true))
              .canReceiveAllowance,
          true);
    });
    test('approved but suspended scholar cannot receive', () {
      expect(AppUser.fromMap(profile(status: 'approved')).canReceiveAllowance,
          false);
    });
    test('admin is not a scholar payout recipient', () {
      expect(
          AppUser.fromMap(
                  profile(status: 'approved', active: true, role: 'admin'))
              .canReceiveAllowance,
          false);
    });
    test('old profile without verification fields fails closed', () {
      expect(
          AppUser.fromMap(
                  {'id': 'old', 'full_name': 'Legacy', 'is_active': true})
              .canReceiveAllowance,
          false);
    });
    test('unknown status fails closed', () {
      expect(
          AppUser.fromMap(profile(status: 'anything', active: true))
              .canReceiveAllowance,
          false);
    });
    test('database status round trips', () {
      for (final status in VerificationStatus.values) {
        expect(verificationStatusFrom(status.databaseValue), status);
      }
    });
    test('scholar declarations stay distinct from verified status', () {
      final user = AppUser.fromMap(profile());
      expect(user.declaredScholar, true);
      expect(user.scholarshipName, 'School Merit Award');
      expect(user.canReceiveAllowance, false);
    });
  });

  group('selfie profile fields', () {
    test('older profile defaults to no selfie and no retake request', () {
      final user = AppUser.fromMap(profile());
      expect(user.selfiePath, isNull);
      expect(user.selfieSubmittedAt, isNull);
      expect(user.selfieRetakeAllowed, isFalse);
    });

    test('maps submitted selfie fields', () {
      final submittedAt = DateTime.parse('2026-11-19T10:30:00Z');
      final user = AppUser.fromMap({
        ...profile(),
        'selfie_path': 'student-1/123.jpg',
        'selfie_submitted_at': submittedAt.toIso8601String(),
        'selfie_retake_allowed': true,
      });

      expect(user.selfiePath, 'student-1/123.jpg');
      expect(user.selfieSubmittedAt, submittedAt);
      expect(user.selfieRetakeAllowed, isTrue);
    });
  });

  group('payout QR vs event QR', () {
    const payload = ClaimQrPayload(
        token: '1234567890abcdefghijklmnopqrstuv',
        claimId: '12',
        scholarId: 'student-1',
        amount: 5000);
    test('valid payout payload round trips', () {
      final result = ClaimQrPayload.tryParse(payload.encode());
      expect(result?.token, payload.token);
      expect(result?.claimId, '12');
      expect(result?.amount, 5000);
    });
    test('generated claim QR is understood by scanner', () {
      final c = AllowanceClaim(
          id: '12',
          batchId: 'b',
          batchTitle: 'Allowance',
          scholarId: 'student-1',
          scholarName: 'Scholar',
          amount: 5000,
          token: payload.token);
      expect(ClaimQrPayload.tryParse(c.qrPayload)?.token, payload.token);
    });
    test('attendance and generic event QR rejected', () {
      expect(
          ClaimQrPayload.tryParse(
              '{"t":"event_attendance_v1","tok":"${payload.token}"}'),
          null);
      expect(ClaimQrPayload.tryParse('https://example.org/events/123'), null);
    });
    test('empty token rejected', () {
      expect(
          ClaimQrPayload.tryParse('{"t":"scholar_wallet_claim_v1","tok":""}'),
          null);
    });
    test('invalid JSON and empty input rejected', () {
      for (final text in ['', '  ', '{bad}', '[1,2]', '123']) {
        expect(ClaimQrPayload.tryParse(text), null);
      }
    });
    test('printed 32-character code supported', () {
      expect(ClaimQrPayload.tryParse(payload.token)?.token, payload.token);
    });
  });

  const claim = _ClaimFixture();
  testWidgets(
      'amount, recipient, payout event and biometric action are visible',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: PayoutConfirmationScreen(claim: claim.build())));
    expect(find.text('Review Allowance Amount'), findsOneWidget);
    expect(find.text('AMOUNT TO RECEIVE'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Amount to receive, PHP 5,000.00'),
      findsOneWidget,
    );
    expect(find.text('Payout event'), findsOneWidget);
    expect(find.text('October Allowance'), findsOneWidget);
    expect(find.text('Recipient'), findsOneWidget);
    expect(find.text('Test Scholar'), findsOneWidget);
    expect(find.text('Payout reference'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Continue to Biometrics'),
      200,
    );
    await tester.pumpAndSettle();
    expect(find.text('Continue to Biometrics'), findsOneWidget);
    expect(
      find.textContaining(
        'This records allowance receipt in Scholar Wallet and adds it to your balance.',
      ),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('cancel returns false without confirming receipt',
      (tester) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () async {
                      result = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                              builder: (_) => PayoutConfirmationScreen(
                                  claim: claim.build())));
                    },
                    child: const Text('Open'))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Cancel'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, false);
  });

  testWidgets(
      'continue requests biometrics without claiming payout on amount screen',
      (tester) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () async {
                      result = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                              builder: (_) => PayoutConfirmationScreen(
                                  claim: claim.build())));
                    },
                    child: const Text('Open'))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Continue to Biometrics'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue to Biometrics'));
    await tester.pumpAndSettle();
    expect(result, true);
  });

  testWidgets('payout confirmation fits 320dp at 1.3 text scale',
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
        home: PayoutConfirmationScreen(claim: claim.build()),
      ),
    );
    await tester.pump();

    expect(find.text('AMOUNT TO RECEIVE'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(find.text('Payout event'), findsOneWidget);
    expect(find.text('Recipient'), findsOneWidget);
    expect(find.text('Payout reference'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Continue to Biometrics'),
      200,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('pending verification screen does not show the old sequence',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = _VerificationFixtureAppState(
      AppUser.fromMap({
        ...profile(),
        'verification_status': 'pending',
        'selfie_path': 'student-1/selfie.jpg',
        'selfie_retake_allowed': false,
      }),
    );
    addTearDown(state.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const VerificationScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Registration'), findsOneWidget);
    expect(find.text('Admin verification'), findsOneWidget);
    expect(find.text('Approved scholar'), findsOneWidget);
    expect(find.textContaining('Then: Payout QR'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('needs-info screen and resubmit omit scholarship reference',
      (tester) async {
    final referenceText = find.byWidgetPredicate(
      (widget) =>
          widget is Text &&
          (widget.data?.toLowerCase().contains('reference') == true ||
              widget.data?.toLowerCase().contains('award id') == true),
    );
    final state = _VerificationFixtureAppState(
      AppUser.fromMap({
        ...profile(status: 'needs_info'),
        'scholarship_reference': 'AWARD-2026-123',
      }),
    );
    addTearDown(state.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const VerificationScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(referenceText, findsNothing);
    expect(find.text('AWARD-2026-123'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Update requested information'),
      200,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Update requested information'));
    await tester.pumpAndSettle();

    expect(find.text('Update verification details'), findsOneWidget);
    expect(referenceText, findsNothing);
    expect(find.text('AWARD-2026-123'), findsNothing);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('inactive approved scholar sees inactive payout access',
      (tester) async {
    final state = _VerificationFixtureAppState(
      AppUser.fromMap({
        ...profile(status: 'approved'),
        'selfie_path': 'student-1/selfie.jpg',
      }),
    );
    addTearDown(state.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const VerificationScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.textContaining('payout access is currently inactive.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

class _VerificationFixtureAppState extends ChangeNotifier implements AppState {
  _VerificationFixtureAppState(this.user);

  @override
  AppUser? user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ClaimFixture {
  const _ClaimFixture();
  AllowanceClaim build() => AllowanceClaim(
      id: '12',
      batchId: 'batch-1',
      batchTitle: 'October Allowance',
      scholarId: 'student-1',
      scholarName: 'Test Scholar',
      amount: 5000,
      token: '1234567890abcdefghijklmnopqrstuv');
}
