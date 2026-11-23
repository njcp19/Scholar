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
}

class _AdminDashboardTestState extends AppState {
  final _wallet = _AdminDashboardTestWallet();

  _AdminDashboardTestState() {
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

  @override
  Future<void> loadAllowanceSettings() async {}
}

class _AdminDashboardTestWallet implements WalletService {
  @override
  Future<int> getActiveScholarCount() async => 0;

  @override
  Future<List<AllowanceClaim>> getAllClaims({int limit = 200}) async => [];

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
