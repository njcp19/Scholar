import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import 'package:scholar_wallet/models/models.dart';
import 'package:scholar_wallet/providers/app_state.dart';
import 'package:scholar_wallet/screens/fingerprint_screen.dart';
import 'package:scholar_wallet/services/biometric_service.dart';
import 'package:scholar_wallet/theme/app_theme.dart';
import 'package:scholar_wallet/widgets/widgets.dart';
import 'helpers/card_layering_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('enabled biometrics screen fits and scrolls at compact scale',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = _BiometricScreenState();
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
          home: const FingerprintScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final titleFinder = find.text('Device biometrics enabled');
    final title = tester.widget<Text>(titleFinder);
    expect(title.style?.color, Colors.white);
    expect(title.style?.fontSize, 22);
    expect(title.style?.fontWeight, FontWeight.w800);
    final dateFinder = find.textContaining('Enabled ');
    expect(dateFinder, findsOneWidget);
    expect(
      tester.widget<Text>(dateFinder).style?.color,
      Colors.white.withValues(alpha: .85),
    );

    final decorFinder = find.byKey(const ValueKey('biometric-hero-shapes'));
    final clip = tester.widget<ClipRRect>(
      find.descendant(of: decorFinder, matching: find.byType(ClipRRect)),
    );
    expect(clip.borderRadius, BorderRadius.circular(28));
    expectNoForegroundPaint(tester, decorFinder);
    expectCardDecorShapesLayeredBehindContent(tester, decorFinder);

    for (final step in [
      'Confirm with device biometrics',
      'Confirm on your device',
      'Receive your allowance',
    ]) {
      await tester.scrollUntilVisible(
        find.text(step),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(step), findsOneWidget);
    }

    final availabilityLabel = find.text('Available on this device:');
    await tester.scrollUntilVisible(
      availabilityLabel,
      100,
      scrollable: find.byType(Scrollable).first,
    );
    final availableCard = find.ancestor(
      of: availabilityLabel,
      matching: find.byType(AppCard),
    );
    expect(
      find.descendant(
        of: availableCard.first,
        matching: find.text('Device biometrics'),
      ),
      findsOneWidget,
    );
    final listRect = tester.getRect(find.byType(ListView));
    expect(tester.getRect(availableCard.first).bottom,
        lessThanOrEqualTo(listRect.bottom));

    final enableButton = find.ancestor(
      of: find.text('Enable again'),
      matching: find.byType(OutlinedButton),
    );
    expect(tester.widget<OutlinedButton>(enableButton).onPressed, isNotNull);
    expect(tester.getSize(enableButton).height, greaterThanOrEqualTo(48));

    final removeButton = find.ancestor(
      of: find.text('Remove device biometrics'),
      matching: find.byType(TextButton),
    );
    expect(tester.widget<TextButton>(removeButton).onPressed, isNotNull);
    expect(tester.getSize(removeButton).height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
  });
}

class _ReadyBiometricService extends BiometricService {
  @override
  Future<bool> deviceSupportsBiometrics() async => true;

  @override
  Future<List<BiometricType>> enrolledBiometrics() async =>
      [BiometricType.fingerprint];
}

class _BiometricScreenState extends ChangeNotifier implements AppState {
  @override
  final BiometricService biometric = _ReadyBiometricService();

  @override
  bool fingerprintRegistered = true;

  @override
  DateTime? fingerprintEnrolledAt = DateTime(2026, 11, 21, 10, 30);

  @override
  AppUser? user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
