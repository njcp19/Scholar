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
import 'package:scholar_wallet/screens/settings_screen.dart';
import 'package:scholar_wallet/theme/app_theme.dart';
import 'package:scholar_wallet/widgets/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'helpers/card_layering_test_utils.dart';

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

  testWidgets('profile header fits long scholar details at narrow size',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const fullName =
        'Alexandra Watanabe Scholar Candidate with an Extremely Long Profile Name';
    const email =
        'alexandra.watanabe.scholar.candidate.with.a.long.address@example.edu';
    const studentNumber = '2026-123456789012345678901234567890123456';
    final state = AppState()
      ..user = AppUser(
        id: 'student-1',
        fullName: fullName,
        email: email,
        studentNumber: studentNumber,
        verificationStatus: VerificationStatus.approved,
        isActive: true,
      );

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
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text(fullName), findsOneWidget);
    expect(find.text(email), findsOneWidget);
    expect(find.text('Scholar account'), findsOneWidget);
    expect(find.text('AN'), findsOneWidget);
    expect(find.byType(ProfileAvatar), findsOneWidget);
    expect(tester.widget<ProfileAvatar>(find.byType(ProfileAvatar)).size, 52);
    final hero = _profileHeroCard();
    expect(find.text('Scholar account'), findsOneWidget);
    expectNoForegroundPaint(tester, hero);
    _expectRoundedProfileHeader(tester);
    _expectProfileTextInset(tester, fullName, email);

    final name = tester.widget<Text>(find.text(fullName));
    expect(name.maxLines, 2);
    expect(name.overflow, TextOverflow.ellipsis);
    final emailText = tester.widget<Text>(find.text(email));
    expect(emailText.maxLines, 2);
    expect(emailText.overflow, TextOverflow.ellipsis);
    final idChip = tester.widget<Text>(
      find.byWidgetPredicate(
        (widget) => widget is Text && widget.data == 'ID: $studentNumber',
      ),
    );
    expect(idChip.maxLines, 1);
    expect(idChip.overflow, TextOverflow.ellipsis);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('admin profile header fits long details at narrow size',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const fullName = 'Alexandra Watanabe Administrator With A Very Long Name';
    const email =
        'alexandra.watanabe.administrator.with.a.long.address@example.edu';
    final state = AppState()
      ..user = AppUser(
        id: 'admin-1',
        fullName: fullName,
        email: email,
        role: UserRole.admin,
        isActive: true,
      );

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
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text(fullName), findsOneWidget);
    expect(find.text(email), findsOneWidget);
    expect(find.text('Administrator account'), findsOneWidget);
    expect(find.text('Administrator'), findsOneWidget);
    expect(find.byKey(const ValueKey('profile_hero_avatar')), findsOneWidget);
    expect(find.text('AN'), findsOneWidget);
    final hero = _profileHeroCard();
    expect(find.text('Administrator account'), findsOneWidget);
    expectNoForegroundPaint(tester, hero);
    _expectRoundedProfileHeader(tester);
    _expectProfileTextInset(tester, fullName, email);
    expect(tester.takeException(), isNull);

    final name = tester.widget<Text>(find.text(fullName));
    expect(name.maxLines, 2);
    expect(name.overflow, TextOverflow.ellipsis);
    final emailText = tester.widget<Text>(find.text(email));
    expect(emailText.maxLines, 2);
    expect(emailText.overflow, TextOverflow.ellipsis);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });
}

void _expectProfileTextInset(
  WidgetTester tester,
  String fullName,
  String email,
) {
  final hero = _profileHeroCard();
  final cardLeft = tester.getRect(hero).left;
  final nameLeft = tester.getTopLeft(find.text(fullName)).dx;
  final emailLeft = tester.getTopLeft(find.text(email)).dx;
  expect(nameLeft - cardLeft, greaterThanOrEqualTo(20));
  expect(emailLeft, closeTo(nameLeft, 1));
}

void _expectRoundedProfileHeader(WidgetTester tester) {
  final cardContainer = tester.widget<Container>(
    _profileHeroCard(),
  );
  final decoration = cardContainer.decoration! as BoxDecoration;
  expect(decoration.borderRadius, BorderRadius.circular(28));
}

Finder _profileHeroCard() => find
    .ancestor(
      of: find.byKey(const ValueKey('profile_hero_avatar')),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration! as BoxDecoration).gradient != null,
      ),
    )
    .first;

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
