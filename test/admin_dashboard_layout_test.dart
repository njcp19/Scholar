import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart'
    show setupFirebaseCoreMocks;
// ignore: depend_on_referenced_packages
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:scholar_wallet/models/models.dart';
import 'package:scholar_wallet/providers/app_state.dart';
import 'package:scholar_wallet/screens/admin/admin_dashboard_screen.dart';
import 'package:scholar_wallet/screens/admin/scholarship_programs_screen.dart';
import 'package:scholar_wallet/services/scholarship_catalog_service.dart';
import 'package:scholar_wallet/services/wallet_service.dart';
import 'package:scholar_wallet/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:scholar_wallet/widgets/widgets.dart';

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

  testWidgets('Admin Home fits at 360dp at standard and enlarged text',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final textScale in [1.0, 1.3]) {
      final state = _AdminDashboardTestState();
      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: state,
          child: MaterialApp(
            theme: AppTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(textScale),
              ),
              child: child!,
            ),
            home: const AdminDashboardScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(tester.takeException(), isNull);
      final label = find.text('DISBURSE ALLOWANCE');
      expect(label, findsOneWidget);
      expect(
        find.text(
          'Generate a payout batch and scholars scan their QR to receive it.',
        ),
        findsOneWidget,
      );
      final card =
          find.ancestor(of: label, matching: find.byType(AppCard)).first;
      expect(tester.widget<AppCard>(card).radius, 28);
      final labelLeft = tester.getTopLeft(label).dx;
      expect(
        labelLeft - tester.getRect(card).left,
        greaterThanOrEqualTo(20),
      );
      expect(
        tester
            .getTopLeft(
              find.text(
                'Generate a payout batch and scholars scan their QR to receive it.',
              ),
            )
            .dx,
        closeTo(labelLeft, 1),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
    }
  });

  testWidgets('Scholarship programs summary totals only budgeted programs',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = _AdminDashboardTestState();
    const catalog = _DashboardCatalogService(
      programs: [
        ScholarshipCatalogItem(
          id: 1,
          name: 'STEM Scholars',
          isActive: true,
          slots: 20,
          slotsTaken: 17,
        ),
        ScholarshipCatalogItem(
          id: 2,
          name: 'Arts Fund',
          isActive: true,
          slots: 8,
          slotsTaken: 2,
        ),
        ScholarshipCatalogItem(
          id: 3,
          name: 'Health Fund',
          isActive: true,
          slots: 12,
          slotsTaken: 6,
        ),
        ScholarshipCatalogItem(
          id: 4,
          name: 'Inactive Fund',
          isActive: false,
        ),
      ],
      budgets: [
        ScholarshipProgramBudget(
          programName: 'STEM Scholars',
          programBudget: 10000,
          budgetUsed: 8500,
          budgetRemaining: 1500,
        ),
        ScholarshipProgramBudget(
          programName: 'Arts Fund',
          programBudget: null,
          budgetUsed: 900,
          budgetRemaining: null,
        ),
        ScholarshipProgramBudget(
          programName: 'Health Fund',
          programBudget: 5000,
          budgetUsed: 1000,
          budgetRemaining: 4000,
        ),
        ScholarshipProgramBudget(
          programName: 'Inactive Fund',
          programBudget: 30000,
          budgetUsed: 1000,
          budgetRemaining: 29000,
        ),
      ],
    );

    await _pumpAdminHome(tester, state, catalog, textScale: 1.3);
    await tester.ensureVisible(find.text('Scholarship programs'));

    expect(find.text('3 active programs'), findsOneWidget);
    expect(find.text('PHP 15,000.00'), findsOneWidget);
    expect(find.text('PHP 9,500.00'), findsOneWidget);
    expect(find.text('PHP 5,500.00'), findsOneWidget);
    expect(find.text('Total budget'), findsOneWidget);
    expect(find.text('Used'), findsOneWidget);
    expect(find.text('Remaining'), findsOneWidget);
    expect(find.text('Arts Fund'), findsOneWidget);
    expect(find.text('Health Fund'), findsOneWidget);
    expect(find.text('STEM Scholars'), findsOneWidget);
    expect(find.text('2 of 8 slots'), findsOneWidget);
    expect(find.text('6 of 12 slots'), findsOneWidget);
    expect(
      find.text('Programs without a budget are not included'),
      findsOneWidget,
    );
    expect(find.text('No budget'), findsOneWidget);
    expect(find.text('No budget set'), findsNothing);
    final healthProgress = tester.widget<LinearProgressIndicator>(
      find.byKey(const ValueKey('admin-program-progress-Health Fund')),
    );
    expect(healthProgress.value, closeTo(0.2, 0.001));
    expect(healthProgress.valueColor!.value, const Color(0xFF1E5AA8));
    final stemProgress = tester.widget<LinearProgressIndicator>(
      find.byKey(const ValueKey('admin-program-progress-STEM Scholars')),
    );
    expect(stemProgress.value, closeTo(0.85, 0.001));
    expect(stemProgress.valueColor!.value, const Color(0xFFF0A020));
    expect(tester.takeException(), isNull);
    expect(
      tester
          .widget<AppCard>(
            find.byKey(const ValueKey('admin-program-summary-card')),
          )
          .radius,
      22,
    );

    await tester.tap(find.text('Scholarship programs'));
    await tester.pumpAndSettle();
    expect(find.byType(ScholarshipProgramsScreen), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('no-budget programs show one summary line and muted chips',
      (tester) async {
    final state = _AdminDashboardTestState();
    const catalog = _DashboardCatalogService(
      programs: [
        ScholarshipCatalogItem(
          id: 1,
          name: 'Community Scholars',
          isActive: true,
        ),
        ScholarshipCatalogItem(
          id: 2,
          name: 'Regional Scholars',
          isActive: true,
        ),
      ],
      budgets: [],
    );

    await _pumpAdminHome(tester, state, catalog);
    await tester.ensureVisible(find.text('Scholarship programs'));

    expect(find.text('2 active programs'), findsOneWidget);
    expect(find.text('No budgets set yet'), findsOneWidget);
    expect(find.text('Community Scholars'), findsOneWidget);
    expect(find.text('Regional Scholars'), findsOneWidget);
    expect(find.text('No budget'), findsNWidgets(2));
    expect(find.text('No budget set'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('program list sorts names and links to all programs',
      (tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = _AdminDashboardTestState();
    const catalog = _DashboardCatalogService(
      programs: [
        ScholarshipCatalogItem(id: 1, name: 'Zeta Fund', isActive: true),
        ScholarshipCatalogItem(id: 2, name: 'Beta Fund', isActive: true),
        ScholarshipCatalogItem(id: 3, name: 'Alpha Fund', isActive: true),
        ScholarshipCatalogItem(id: 4, name: 'Delta Fund', isActive: true),
        ScholarshipCatalogItem(id: 5, name: 'Gamma Fund', isActive: true),
      ],
      budgets: [],
    );

    await _pumpAdminHome(tester, state, catalog);
    await tester.ensureVisible(find.text('View all 5 programs'));

    expect(find.text('Alpha Fund'), findsOneWidget);
    expect(find.text('Beta Fund'), findsOneWidget);
    expect(find.text('Delta Fund'), findsOneWidget);
    expect(find.text('Gamma Fund'), findsNothing);
    expect(find.text('Zeta Fund'), findsNothing);
    expect(find.text('View all 5 programs'), findsOneWidget);

    await tester.tap(find.text('View all 5 programs'));
    await tester.pumpAndSettle();
    expect(find.byType(ScholarshipProgramsScreen), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('long program names wrap at compact width and enlarged text',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = _AdminDashboardTestState();
    const programName = 'National Science and Technology Scholarship Fund';
    const catalog = _DashboardCatalogService(
      programs: [
        ScholarshipCatalogItem(
          id: 1,
          name: programName,
          isActive: true,
          slots: 20,
          slotsTaken: 13,
        ),
      ],
      budgets: [],
    );

    await _pumpAdminHome(tester, state, catalog, textScale: 1.3);
    await tester.ensureVisible(find.text(programName));

    final name = find.text(programName);
    expect(tester.widget<Text>(name).maxLines, 2);
    expect(tester.getSize(name).height, greaterThan(24));
    expect(find.text('13 of 20 slots'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('separate stats card shows all three existing metrics',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final claims = [
      for (var index = 0; index < 2; index++)
        AllowanceClaim(
          id: 'waiting-$index',
          batchId: 'batch',
          batchTitle: 'Payout',
          scholarId: 'waiting-scholar-$index',
          scholarName: 'Waiting Scholar $index',
          amount: 1000,
          token: 'waiting-token-$index',
        ),
      AllowanceClaim(
        id: 'received-1',
        batchId: 'batch',
        batchTitle: 'Payout',
        scholarId: 'received-scholar',
        scholarName: 'Received Scholar',
        amount: 1000,
        token: 'received-token',
        status: ClaimStatus.received,
      ),
    ];
    final state = _AdminDashboardTestState(
      scholarCount: 42,
      claims: claims,
    );

    await _pumpAdminHome(
      tester,
      state,
      const _DashboardCatalogService(programs: [], budgets: []),
      textScale: 1.3,
    );
    await tester.drag(find.byType(ListView).first, const Offset(0, -900));
    await tester.pumpAndSettle();
    final statsCard = find.byKey(const ValueKey('admin-home-stats-card'));
    await tester.ensureVisible(statsCard);

    expect(find.descendant(of: statsCard, matching: find.text('42')),
        findsOneWidget);
    expect(find.descendant(of: statsCard, matching: find.text('2')),
        findsOneWidget);
    expect(find.descendant(of: statsCard, matching: find.text('1')),
        findsOneWidget);
    expect(
      find.descendant(
        of: statsCard,
        matching: find.text('Active scholars'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: statsCard,
        matching: find.text('Waiting for scan'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: statsCard, matching: find.text('Received')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: statsCard,
        matching: find.text('PHP 2,000.00 reserved'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });
}

Future<void> _pumpAdminHome(
  WidgetTester tester,
  _AdminDashboardTestState state,
  ScholarshipCatalogService catalog, {
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<AppState>.value(
      value: state,
      child: MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        ),
        home: AdminDashboardScreen(catalogService: catalog),
      ),
    ),
  );
  await tester.pump(const Duration(seconds: 1));
  await tester.drag(find.byType(ListView).first, const Offset(0, -600));
  await tester.pumpAndSettle();
}

class _AdminDashboardTestState extends AppState {
  final _AdminDashboardTestWallet _wallet;

  _AdminDashboardTestState({
    int scholarCount = 0,
    List<AllowanceClaim> claims = const [],
  }) : _wallet = _AdminDashboardTestWallet(
          scholarCount: scholarCount,
          claims: claims,
        ) {
    user = AppUser(
      id: 'admin-test',
      fullName: 'Test Admin',
      email: 'admin@example.test',
      role: UserRole.admin,
      isActive: true,
    );
  }

  @override
  WalletService get wallet => _wallet;
}

class _AdminDashboardTestWallet implements WalletService {
  final int scholarCount;
  final List<AllowanceClaim> claims;

  const _AdminDashboardTestWallet({
    this.scholarCount = 0,
    this.claims = const [],
  });

  @override
  Future<int> getActiveScholarCount() async => scholarCount;

  @override
  Future<List<AllowanceClaim>> getAllClaims({int limit = 200}) async => claims;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DashboardCatalogService implements ScholarshipCatalogService {
  final List<ScholarshipCatalogItem> programs;
  final List<ScholarshipProgramBudget> budgets;

  const _DashboardCatalogService({
    required this.programs,
    required this.budgets,
  });

  @override
  Future<List<ScholarshipCatalogItem>> list({
    required bool includeInactive,
  }) async =>
      programs
          .where((program) => includeInactive || program.isActive)
          .toList(growable: false);

  @override
  Future<List<ScholarshipProgramBudget>> getProgramBudgets() async => budgets;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
