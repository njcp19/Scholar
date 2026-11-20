import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholar_wallet/models/models.dart';
import 'package:scholar_wallet/screens/admin/registration_review_screen.dart';
import 'package:scholar_wallet/theme/app_theme.dart';

void main() {
  const prompts = <({
    VerificationStatus status,
    String title,
    String message,
    String confirmLabel,
    bool askForNewSelfie,
  })>[
    (
      status: VerificationStatus.approved,
      title: 'Approve this scholar?',
      message:
          'They will be able to receive allowances once their account is active.',
      confirmLabel: 'Approve',
      askForNewSelfie: false,
    ),
    (
      status: VerificationStatus.underReview,
      title: 'Mark as under review?',
      message: 'The scholar stays pending while you check the details.',
      confirmLabel: 'Mark under review',
      askForNewSelfie: false,
    ),
    (
      status: VerificationStatus.needsInfo,
      title: 'Request more information?',
      message: 'Your review note will be shown to the scholar.\n'
          'The scholar will also be asked for a new selfie.',
      confirmLabel: 'Send request',
      askForNewSelfie: true,
    ),
    (
      status: VerificationStatus.rejected,
      title: 'Reject this registration?',
      message: 'Your review note will be shown to the scholar.',
      confirmLabel: 'Reject',
      askForNewSelfie: false,
    ),
  ];

  for (final prompt in prompts) {
    testWidgets('${prompt.status.name} decision uses specific copy',
        (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (builderContext) {
              context = builderContext;
              return const Scaffold();
            },
          ),
        ),
      );

      final result = showRegistrationDecisionDialog(
        context,
        status: prompt.status,
        scholarName: 'Jamie Scholar',
        askForNewSelfie: prompt.askForNewSelfie,
      );
      await tester.pumpAndSettle();

      expect(find.text(prompt.title), findsOneWidget);
      expect(find.text(prompt.message), findsOneWidget);
      expect(find.text('Jamie Scholar'), findsOneWidget);
      expect(find.text(prompt.confirmLabel), findsOneWidget);

      await tester.tap(find.text(prompt.confirmLabel));
      await tester.pumpAndSettle();
      expect(await result, isTrue);
    });
  }

  testWidgets('request information omits selfie line when not requested',
      (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (builderContext) {
            context = builderContext;
            return const Scaffold();
          },
        ),
      ),
    );

    showRegistrationDecisionDialog(
      context,
      status: VerificationStatus.needsInfo,
      scholarName: 'Jamie Scholar',
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Your review note will be shown to the scholar.'),
      findsOneWidget,
    );
    expect(
      find.text('The scholar will also be asked for a new selfie.'),
      findsNothing,
    );
  });
}
