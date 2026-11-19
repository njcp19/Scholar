import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart'
    show setupFirebaseCoreMocks;
// ignore: depend_on_referenced_packages
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scholar_wallet/models/models.dart';
import 'package:scholar_wallet/providers/app_state.dart';
import 'package:scholar_wallet/screens/claims_screen.dart';
import 'package:scholar_wallet/screens/home_screen.dart';
import 'package:scholar_wallet/theme/app_theme.dart';
import 'package:scholar_wallet/widgets/shell_tab_controller.dart';
import 'package:scholar_wallet/widgets/widgets.dart';
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

  testWidgets('Home fits both viewport sizes without overflow', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewPadding);

    await _pumpHome(tester, const Size(360, 640));
    _expectCompactHome(tester);

    tester.view.physicalSize = const Size(390, 844);
    await tester.pump();
    expect(tester.takeException(), isNull);
    _expectCompactHome(tester);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Received allowance card fits both viewport sizes',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewPadding);

    Widget app() => MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: MonthlyAllowanceCard(
                  title: 'Monthly Allowance',
                  amount: 6000,
                  state: AllowanceCardState.received,
                  issuedDate: 'Nov 1, 2026',
                  receivedDate: 'Nov 2, 2026',
                  statusOnRight: true,
                  radius: 22,
                  iconTileSize: 40,
                  amountFontSize: 22,
                ),
              ),
            ),
          ),
        );

    for (final size in [const Size(360, 640), const Size(390, 844)]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(app());
      expect(tester.takeException(), isNull);
      expect(find.text('PHP 6,000.00'), findsOneWidget);
      expect(find.byType(Divider), findsOneWidget);
      expect(find.text('Received'), findsNWidgets(2));
    }

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Home Monthly Allowance card keeps only requested labels',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewPadding);
    final today = DateTime.now();
    final expectedDate = DateTime(today.year, today.month, today.day + 12);

    Widget card() => MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: MonthlyAllowanceCard(
                  title: 'Monthly Allowance',
                  amount: 5000,
                  state: AllowanceCardState.notReleased,
                  expectedReleaseDate: expectedDate,
                  academicPeriod: '1st Semester AY 2026-2027',
                  statusOnRight: true,
                ),
              ),
            ),
          ),
        );

    for (final size in [const Size(360, 640), const Size(390, 844)]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(card());
      expect(tester.takeException(), isNull);
      expect(find.text('MONTHLY ALLOWANCE'), findsOneWidget);
      expect(find.text('Monthly Allowance'), findsNothing);
      expect(find.text('PHP 5,000.00'), findsOneWidget);
      expect(find.textContaining('No allowance released yet'), findsOneWidget);
      expect(find.textContaining('Expected release:'), findsOneWidget);
      expect(
        find.text(DateFormat('MMM d, yyyy').format(expectedDate)),
        findsOneWidget,
      );
      expect(find.text('In 12 days'), findsOneWidget);
      expect(find.text('1st Semester AY 2026-2027'), findsOneWidget);
      expect(find.text('Demo data'), findsNothing);
      expect(
        tester.widget<AppCard>(find.byType(AppCard)).padding,
        const EdgeInsets.all(16),
      );
      final wraps = tester.widgetList<Wrap>(find.byType(Wrap));
      expect(wraps, hasLength(2));
      for (final wrap in wraps) {
        expect(wrap.spacing, 8);
        expect(wrap.runSpacing, 8);
      }
    }

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('My Payouts fits both viewport sizes without overflow',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewPadding);

    for (final size in [const Size(360, 640), const Size(390, 844)]) {
      tester.view.physicalSize = size;
      final state = AppState()
        ..user = AppUser(id: 'test-user', fullName: 'Test Scholar', email: '');
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AppState>(create: (_) => state),
            ChangeNotifierProvider<ShellTabController>(
              create: (_) => ShellTabController(),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const ClaimsScreen(embedded: true),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('My Payouts'), findsOneWidget);
      expect(find.text('TOTAL RECEIVED'), findsOneWidget);
      expect(find.text('Waiting for scan'), findsOneWidget);
      expect(find.text('Received'), findsOneWidget);
      expect(find.text('PHP 0.00'), findsOneWidget);

      final totalHero = find
          .ancestor(
            of: find.text('TOTAL RECEIVED'),
            matching: find.byType(Container),
          )
          .first;
      expect(
        tester.getSize(totalHero).height,
        ProfileHeroMetrics.height,
      );
      final totalText = tester.widget<Text>(find.text('PHP 0.00'));
      final amountSpan =
          (totalText.textSpan as TextSpan).children!.last as TextSpan;
      expect(amountSpan.style?.fontSize, ProfileHeroMetrics.amountFontSize);

      final waitingCard = find
          .ancestor(
            of: find.text('Waiting for scan'),
            matching: find.byType(AppCard),
          )
          .first;
      final receivedCard = find
          .ancestor(
            of: find.text('Received'),
            matching: find.byType(AppCard),
          )
          .first;
      expect(
        tester.getSize(waitingCard).height,
        tester.getSize(receivedCard).height,
      );
    }

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Future<void> _pumpHome(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        theme: AppTheme.light,
        home: const HomeScreen(),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump();
  expect(tester.takeException(), isNull);
}

void _expectCompactHome(WidgetTester tester) {
  expect(find.text('CURRENT BALANCE'), findsOneWidget);
  expect(find.text('Cash Out'), findsOneWidget);
  expect(find.text('Simulated'), findsNothing);
  final balanceCard = find
      .ancestor(
        of: find.text('CURRENT BALANCE'),
        matching: find.byType(AppCard),
      )
      .first;
  expect(tester.getSize(balanceCard).height, ProfileHeroMetrics.height);
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
