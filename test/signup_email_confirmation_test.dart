import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholar_wallet/screens/signup_screen.dart';
import 'package:scholar_wallet/services/scholarship_catalog_service.dart';
import 'package:scholar_wallet/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'email confirmation validates on submit and blur, accepts case differences, and revalidates',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
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
        home: SignupScreen(catalogService: _EmptyCatalogService()),
      ),
    );
    await tester.pumpAndSettle();
    await _openSecurityStep(tester);

    TextField field(int index) =>
        tester.widget<TextField>(find.byType(TextField).at(index));

    expect(field(1).keyboardType, TextInputType.emailAddress);
    expect(field(1).autofillHints, isEmpty);

    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();
    expect(field(1).decoration?.errorText, 'This field is required.');

    await tester.enterText(fieldFinder(0), 'student@example.edu');
    await tester.enterText(fieldFinder(1), 'different@example.edu');
    await tester.ensureVisible(fieldFinder(2));
    await tester.tap(fieldFinder(2));
    await tester.pumpAndSettle();
    expect(field(1).decoration?.errorText, 'Emails do not match.');

    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();
    expect(field(1).decoration?.errorText, 'Emails do not match.');

    await tester.ensureVisible(fieldFinder(1));
    await tester.tap(fieldFinder(1));
    await tester.enterText(fieldFinder(1), 'STUDENT@EXAMPLE.EDU');
    await tester.ensureVisible(fieldFinder(2));
    await tester.tap(fieldFinder(2));
    await tester.pumpAndSettle();
    expect(field(1).decoration?.errorText, isNull);

    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();
    expect(field(1).decoration?.errorText, isNull);
    expect(field(2).decoration?.errorText, 'This field is required.');

    await tester.ensureVisible(fieldFinder(0));
    await tester.tap(fieldFinder(0));
    await tester.enterText(fieldFinder(0), 'changed@example.edu');
    await tester.pumpAndSettle();
    expect(field(1).decoration?.errorText, 'Emails do not match.');
    expect(tester.takeException(), isNull);
  });
}

Finder fieldFinder(int index) => find.byType(TextField).at(index);

Future<void> _openSecurityStep(WidgetTester tester) async {
  await tester.enterText(fieldFinder(0), 'Dela Cruz');
  await tester.enterText(fieldFinder(1), 'Juan');
  await tester.enterText(fieldFinder(2), '');
  await tester.ensureVisible(fieldFinder(3));
  await tester.tap(fieldFinder(3));
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();

  await tester.enterText(fieldFinder(4), '20243771');
  await tester.enterText(fieldFinder(5), 'Example University');
  await tester.enterText(fieldFinder(6), 'Computer Science');
  await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
  await tester.tap(find.byType(DropdownButtonFormField<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text('1st Year College').last);
  await tester.pumpAndSettle();

  await tester.ensureVisible(find.text('Scholarship'));
  await tester.tap(find.byKey(const ValueKey('scholarship-picker-field')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).last, 'Test scholarship');
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();
  expect(find.text('Secure your account'), findsOneWidget);
}

class _EmptyCatalogService implements ScholarshipCatalogService {
  @override
  Future<List<ScholarshipProgramBudget>> getProgramBudgets() async => const [];

  @override
  Future<void> setProgramBudget({
    required String program,
    required double? budget,
  }) async {}

  @override
  Future<List<ScholarshipCatalogItem>> list({
    required bool includeInactive,
  }) async =>
      const [];

  @override
  Future<void> add({required String name}) async {}

  @override
  Future<void> rename({required int id, required String name}) async {}

  @override
  Future<void> setActive({required int id, required bool active}) async {}

  @override
  Future<void> setDetails({
    required int id,
    String? description,
    double? allowanceAmount,
    String? payoutFrequency,
    int? supportFromYear,
    int? supportToYear,
    int? slots,
  }) async {}
}
