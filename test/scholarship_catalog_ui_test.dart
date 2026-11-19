import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholar_wallet/screens/admin/scholarship_programs_screen.dart';
import 'package:scholar_wallet/screens/signup_screen.dart';
import 'package:scholar_wallet/services/scholarship_catalog_service.dart';
import 'package:scholar_wallet/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('signup picker selects catalog value at narrow scaled size',
      (tester) async {
    _setViewport(tester);
    final service = _FakeScholarshipCatalogService(
      programs: [
        const ScholarshipCatalogItem(
          id: 1,
          name: 'Test-only selectable program',
          isActive: true,
        ),
      ],
    );

    await tester.pumpWidget(_app(SignupScreen(catalogService: service)));
    await tester.ensureVisible(find.text('Scholarship'));
    await tester.tap(find.byKey(const ValueKey('scholarship-picker-field')));
    await tester.pumpAndSettle();

    expect(find.text('Choose your scholarship'), findsOneWidget);
    expect(find.text('Pick the one you already belong to.'), findsOneWidget);
    expect(find.text('Test-only selectable program'), findsOneWidget);
    await tester.tap(find.text('Test-only selectable program'));
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('Test-only selectable program'), findsOneWidget);
    expect(service.includeInactiveValues, [false]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('signup falls back to manual entry for empty or unavailable list',
      (tester) async {
    _setViewport(tester);

    for (final service in [
      _FakeScholarshipCatalogService(),
      _FakeScholarshipCatalogService(failList: true),
    ]) {
      await tester.pumpWidget(_app(SignupScreen(catalogService: service)));
      await tester.ensureVisible(find.text('Scholarship'));
      await tester.tap(find.byKey(const ValueKey('scholarship-picker-field')));
      await tester.pumpAndSettle();

      expect(find.text('Scholarship name'), findsOneWidget);
      expect(find.text('Choose your scholarship'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('admin can add, rename, and toggle a program at narrow size',
      (tester) async {
    _setViewport(tester);
    final service = _FakeScholarshipCatalogService();
    await tester.pumpWidget(
      _app(ScholarshipProgramsScreen(catalogService: service)),
    );
    await tester.pumpAndSettle();

    expect(find.text('No scholarships yet'), findsOneWidget);
    expect(
      find.text(
        'Students pick from this list when they sign up. '
        'Turning one off hides it from new sign-ups; existing scholars keep theirs.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Add scholarship'));
    await tester.pumpAndSettle();
    expect(find.text('Use the official name, as students know it.'),
        findsOneWidget);
    expect(
      find.text('2 to 80 characters. Each name can be listed once.'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField), 'Test-only program');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Test-only program'), findsOneWidget);
    expect(find.text('Shown in Sign up'), findsOneWidget);
    expect(find.text('SCHOLARSHIPS (1)'), findsOneWidget);
    expect(service.addedNames, ['Test-only program']);

    await tester.tap(find.byTooltip('Rename scholarship'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Renamed test-only program');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Renamed test-only program'), findsOneWidget);
    expect(service.renamedNames, ['Renamed test-only program']);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('Hidden'), findsOneWidget);
    expect(service.activeChanges, [false]);
    expect(tester.takeException(), isNull);
  });
}

void _setViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _app(Widget home) {
  return MaterialApp(
    theme: AppTheme.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: const TextScaler.linear(1.3),
      ),
      child: child!,
    ),
    home: home,
  );
}

class _FakeScholarshipCatalogService implements ScholarshipCatalogService {
  _FakeScholarshipCatalogService({
    List<ScholarshipCatalogItem> programs = const [],
    this.failList = false,
  }) : programs = List.of(programs);

  final List<ScholarshipCatalogItem> programs;
  final bool failList;
  final List<bool> includeInactiveValues = [];
  final List<String> addedNames = [];
  final List<String> renamedNames = [];
  final List<bool> activeChanges = [];
  int _nextId = 2;

  @override
  Future<List<ScholarshipCatalogItem>> list({
    required bool includeInactive,
  }) async {
    includeInactiveValues.add(includeInactive);
    if (failList) throw StateError('test list failure');
    return List.of(programs);
  }

  @override
  Future<void> add({required String name}) async {
    addedNames.add(name);
    programs.add(
      ScholarshipCatalogItem(id: _nextId++, name: name, isActive: true),
    );
  }

  @override
  Future<void> rename({
    required int id,
    required String name,
  }) async {
    renamedNames.add(name);
    final index = programs.indexWhere((program) => program.id == id);
    programs[index] = ScholarshipCatalogItem(
      id: id,
      name: name,
      isActive: programs[index].isActive,
    );
  }

  @override
  Future<void> setActive({
    required int id,
    required bool active,
  }) async {
    activeChanges.add(active);
    final index = programs.indexWhere((program) => program.id == id);
    programs[index] = ScholarshipCatalogItem(
      id: id,
      name: programs[index].name,
      isActive: active,
    );
  }
}
