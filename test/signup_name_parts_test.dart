import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholar_wallet/models/models.dart';
import 'package:scholar_wallet/screens/admin/registration_review_screen.dart';
import 'package:scholar_wallet/screens/signup_screen.dart';
import 'package:scholar_wallet/services/scholarship_catalog_service.dart';
import 'package:scholar_wallet/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('composes a normalized full name with or without a middle name', () {
    expect(composeFullName(' Juan  ', '  Santos ', 'Dela  Cruz '),
        'Juan Santos Dela Cruz');
    expect(composeFullName('Juan', '', 'Dela Cruz'), 'Juan Dela Cruz');
  });

  test('validates birthdates against the supported range and current day', () {
    final today = DateTime(2026, 11, 21);
    expect(isValidBirthdate(DateTime(2000, 1, 1), today: today), isTrue);
    expect(isValidBirthdate(DateTime(2026, 11, 22), today: today), isFalse);
    expect(isValidBirthdate(DateTime(1899, 12, 31), today: today), isFalse);
    expect(isValidBirthdate(null, today: today), isFalse);
  });

  test('AppUser maps name parts and date, and accepts missing values', () {
    final withNameParts = AppUser.fromMap({
      'id': 'student-1',
      'full_name': 'Juan Santos Dela Cruz',
      'last_name': 'Dela Cruz',
      'first_name': 'Juan',
      'middle_name': 'Santos',
      'birthdate': '2000-01-02',
      'email': 'juan@example.edu',
    });
    expect(withNameParts.lastName, 'Dela Cruz');
    expect(withNameParts.firstName, 'Juan');
    expect(withNameParts.middleName, 'Santos');
    expect(withNameParts.birthdate, DateTime(2000, 1, 2));
    final legacyUser = AppUser.fromMap({
      'id': 'legacy',
      'full_name': 'Legacy Scholar',
      'email': 'legacy@example.edu',
    });
    expect(legacyUser.lastName, isNull);
    expect(legacyUser.firstName, isNull);
    expect(legacyUser.middleName, isNull);
    expect(legacyUser.birthdate, isNull);
    expect(
      AppUser.fromMap({
        'id': 'invalid-date',
        'full_name': '',
        'email': '',
        'birthdate': 'not-a-date',
      }).birthdate,
      isNull,
    );
  });

  test('admin detail omits scholarship reference whether present or absent',
      () {
    final users = [
      AppUser(
        id: 'with-reference',
        fullName: 'Juan Dela Cruz',
        email: 'juan@example.edu',
        scholarshipReference: 'AWARD-2026-123',
      ),
      AppUser(
        id: 'without-reference',
        fullName: 'Juan Dela Cruz',
        email: 'juan@example.edu',
      ),
    ];

    for (final user in users) {
      expect(
        registrationDetailRows(user).map((row) => row.key),
        isNot(contains('Award reference')),
      );
    }
  });

  test('admin detail includes a formatted date only when present', () {
    AppUser user(DateTime? date) => AppUser(
          id: 'student-1',
          fullName: 'Juan Dela Cruz',
          email: 'juan@example.edu',
          birthdate: date,
        );

    final withDate = registrationDetailRows(user(DateTime(2000, 1, 2)));
    expect(
      withDate.singleWhere((row) => row.key == 'Birthdate').value,
      'Jan 2, 2000',
    );
    expect(
      registrationDetailRows(user(null)).any((row) => row.key == 'Birthdate'),
      isFalse,
    );
  });

  testWidgets(
      'signup Step 1 validates required data and continues with an optional middle name',
      (tester) async {
    tester.view.physicalSize = const Size(320, 780);
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
        home: SignupScreen(catalogService: _TestCatalogService()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Last name'), findsOneWidget);
    expect(find.text('First name'), findsOneWidget);
    expect(find.text('Middle name (optional)'), findsOneWidget);
    expect(find.text('Birthdate'), findsOneWidget);
    expect(find.text('Dela Cruz'), findsOneWidget);
    expect(find.text('Juan'), findsOneWidget);
    expect(find.text('Santos'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(
        find.text('Enter a last name (up to 60 characters).'), findsOneWidget);
    expect(
        find.text('Enter a first name (up to 60 characters).'), findsOneWidget);
    expect(find.text('Enter a valid birthdate.'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'Dela  Cruz');
    await tester.enterText(find.byType(TextField).at(1), 'Juan');
    await tester.enterText(find.byType(TextField).at(2), '');
    await tester.ensureVisible(find.byType(TextField).at(3));
    await tester.tap(find.byType(TextField).at(3));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(4), '20243771');
    await tester.enterText(find.byType(TextField).at(5), 'Example University');
    await tester.enterText(find.byType(TextField).at(6), 'Computer Science');
    await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1st Year College').last);
    await tester.pumpAndSettle();

    expect(find.text('EXISTING SCHOLARSHIP'), findsNothing);
    expect(find.text('I am already a scholar'), findsNothing);
    expect(
      find.text(
        'Scholar Wallet is only for existing scholarship beneficiaries.',
      ),
      findsNothing,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            (widget.data?.toLowerCase().contains('reference') == true ||
                widget.data?.toLowerCase().contains('award id') == true),
      ),
      findsNothing,
    );
    expect(find.byType(Switch), findsNothing);

    await tester.ensureVisible(find.text('Scholarship'));
    await tester.tap(find.byKey(const ValueKey('scholarship-picker-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('This field is required.'), findsOneWidget);
    expect(find.text('Secure your account'), findsNothing);

    await tester.enterText(find.byType(TextField).last, 'Test scholarship');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Secure your account'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _TestCatalogService implements ScholarshipCatalogService {
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
