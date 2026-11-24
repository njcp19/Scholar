import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart'
    show setupFirebaseCoreMocks;
// ignore: depend_on_referenced_packages
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scholar_wallet/models/models.dart';
import 'package:scholar_wallet/providers/app_state.dart';
import 'package:scholar_wallet/screens/admin/activity_log_screen.dart';
import 'package:scholar_wallet/screens/admin/allowance_settings_screen.dart';
import 'package:scholar_wallet/screens/admin/funding_account_screen.dart';
import 'package:scholar_wallet/screens/linked_accounts_screen.dart';
import 'package:scholar_wallet/screens/settings_screen.dart';
import 'package:scholar_wallet/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    FirebaseAuthPlatform.instance = _SignedOutAuthPlatform();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://localhost:54321',
      publishableKey: 'test-publishable-key',
    );
  });

  testWidgets('scholar Profile opens linked accounts only', (tester) async {
    final state = AppState()
      ..user = AppUser(
        id: 'scholar-1',
        fullName: 'Test Scholar',
        email: 'scholar@example.test',
      );
    addTearDown(state.dispose);

    await _pumpProfile(tester, state);

    expect(find.text('Linked accounts'), findsOneWidget);
    expect(
        find.text('Accounts you withdraw your allowance to'), findsOneWidget);
    expect(find.text('Allowance amount'), findsNothing);
    expect(find.text('Funding account'), findsNothing);
    expect(find.text('Activity log'), findsNothing);

    await _openShortcut<LinkedAccountsScreen>(tester, 'Linked accounts');
  });

  testWidgets('admin Profile opens each admin shortcut only', (tester) async {
    final state = AppState()
      ..user = AppUser(
        id: 'admin-1',
        fullName: 'Test Admin',
        email: 'admin@example.test',
        role: UserRole.admin,
      );
    addTearDown(state.dispose);

    await _pumpProfile(tester, state);

    expect(find.text('Linked accounts'), findsNothing);
    expect(find.text('Allowance amount'), findsOneWidget);
    expect(find.text('Set the allowance for each scholar'), findsOneWidget);
    expect(find.text('Funding account'), findsOneWidget);
    expect(find.text('Account used to allocate funds'), findsOneWidget);
    expect(find.text('Activity log'), findsOneWidget);
    expect(find.text('Review what happened in the system'), findsOneWidget);

    await _openShortcut<AllowanceSettingsScreen>(tester, 'Allowance amount');
    await _openShortcut<FundingAccountScreen>(tester, 'Funding account');
    await _openShortcut<ActivityLogScreen>(tester, 'Activity log');
  });
}

Future<void> _pumpProfile(WidgetTester tester, AppState state) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<AppState>.value(
      value: state,
      child: MaterialApp(
        theme: AppTheme.light,
        home: const SettingsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openShortcut<T extends Widget>(
  WidgetTester tester,
  String label,
) async {
  final shortcut = find.text(label);
  await tester.drag(find.byType(ListView).first, const Offset(0, -280));
  await tester.pumpAndSettle();
  await tester.ensureVisible(shortcut);
  await tester.tap(shortcut);
  await tester.pumpAndSettle();
  expect(find.byType(T), findsOneWidget);
  Navigator.of(tester.element(find.byType(T))).pop();
  await tester.pumpAndSettle();
}

class _SignedOutAuthPlatform extends FirebaseAuthPlatform {
  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseAuthPlatform setInitialValues({
    PigeonUserDetails? currentUser,
    String? languageCode,
  }) =>
      this;

  @override
  UserPlatform? get currentUser => null;
}
