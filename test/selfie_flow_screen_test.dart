import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholar_wallet/screens/selfie_flow_screen.dart';
import 'package:scholar_wallet/theme/app_theme.dart';

void main() {
  test('selfie errors use friendly messages', () {
    expect(
      selfieFriendlyErrorMessage(Exception('SELFIE_ALREADY_SUBMITTED')),
      'Your selfie was already submitted.',
    );
    expect(
      selfieFriendlyErrorMessage(Exception('SCHOLAR_NOT_ELIGIBLE')),
      "This account can't submit a selfie right now.",
    );
    expect(
      selfieFriendlyErrorMessage(Exception('BAD_PATH')),
      "The upload didn't finish. Please try again.",
    );
    expect(
      selfieFriendlyErrorMessage(Exception('SELFIE_REQUIRED')),
      'A selfie is required before approval.',
    );
    expect(
      selfieFriendlyErrorMessage(Exception('NO_SELFIE_YET')),
      'This scholar has not submitted a selfie yet.',
    );
    expect(
      selfieFriendlyErrorMessage(
        PlatformException(code: 'camera_access_denied'),
      ),
      'Camera permission is needed to take your selfie. You can allow it in Settings.',
    );
    expect(
      selfieFriendlyErrorMessage(Exception('unknown')),
      'Something went wrong. Please try again.',
    );
  });

  testWidgets('selfie introduction fits narrow screens and shows guidance',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final size in [const Size(360, 640), const Size(390, 844)]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.3),
            ),
            child: child!,
          ),
          home: SelfieIntroScreen(onSubmitted: () async {}),
        ),
      );
      await tester.pump();

      expect(find.text('Step 3 of 3'), findsOneWidget);
      expect(find.text('Take a selfie'), findsOneWidget);
      expect(find.text('Center your face inside the oval'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Good lighting'), 160);
      expect(find.text('Good lighting'), findsOneWidget);
      expect(find.text('No mask or sunglasses'), findsOneWidget);
      expect(find.text('Face the camera'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });

  testWidgets('selfie review keeps upload warning and actions available',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
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
        home: SelfieReviewScreen(photo: File('missing-selfie-preview.jpg')),
      ),
    );
    await tester.pump();

    expect(find.text('Review your selfie'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Submit selfie'), 160);
    expect(
      find.text(
        'Used to verify your registration and shown as your profile picture. Only you and an administrator can see it. You can submit your selfie once. If it is not clear, retake it now.',
      ),
      findsOneWidget,
    );
    expect(find.text('Submit selfie'), findsOneWidget);
    expect(find.text('Retake'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
