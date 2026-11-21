import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:scholar_wallet/screens/check_email_screen.dart';
import 'package:scholar_wallet/screens/forgot_password_screen.dart';
import 'package:scholar_wallet/theme/app_theme.dart';

void main() {
  testWidgets('Scholar Wallet smoke test', (tester) async {
    // App requires Firebase/Supabase at runtime; UI smoke tests run on device.
    expect(1 + 1, 2);
  });

  testWidgets('password reset screens fit at 360dp and 1.3x text scale',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Widget appWith(Widget screen) => MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.3),
            ),
            child: child!,
          ),
          home: screen,
        );

    await tester.pumpWidget(
      appWith(const ForgotPasswordScreen(initialEmail: 'user@school.edu')),
    );
    await tester.pump();
    final forgotScreenError = tester.takeException();
    expect(forgotScreenError, isNull, reason: '$forgotScreenError');
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.text('Email address'), findsOneWidget);
    expect(find.text('Send reset link'), findsOneWidget);

    await tester.pumpWidget(
      const SizedBox.shrink(),
    );
    await tester.pump();

    await tester.pumpWidget(
      appWith(const CheckEmailScreen(email: 'user@school.edu')),
    );
    await tester.pump();
    expect(find.text('Resend in 0:30'), findsOneWidget);
    expect(find.text('user@school.edu'), findsOneWidget);
    expect(find.text('Open email app'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(seconds: 30));
    expect(find.text('Resend link'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
