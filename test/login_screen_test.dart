import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart'
    show setupFirebaseCoreMocks;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scholar_wallet/providers/app_state.dart';
import 'package:scholar_wallet/screens/login_screen.dart';
import 'package:scholar_wallet/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://localhost:54321',
      publishableKey: 'test-publishable-key',
    );
  });

  testWidgets('login fits 360x640 and 390x844 without overflow',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewPadding);

    tester.view.physicalSize = const Size(360, 640);
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(),
        child: MaterialApp(
          theme: AppTheme.light,
          home: const LoginScreen(),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expectResponsiveLoginRow(tester);

    tester.view.physicalSize = const Size(390, 844);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expectResponsiveLoginRow(tester);

    expect(find.text('QR payouts'), findsNothing);

    final forgotText = tester.widget<Text>(find.text('Forgot password?'));
    expect(forgotText.style?.fontSize, 13);
    expect(forgotText.style?.fontWeight, FontWeight.w600);
    expect(forgotText.style?.color, AppTheme.primaryBlue);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

void expectResponsiveLoginRow(WidgetTester tester) {
  final rememberRect = tester.getRect(find.text('Remember me'));
  final forgotRect = tester.getRect(find.text('Forgot password?'));
  expect(forgotRect.left - rememberRect.right, greaterThanOrEqualTo(12));
}
