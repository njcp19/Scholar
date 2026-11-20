import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholar_wallet/theme/app_theme.dart';
import 'package:scholar_wallet/widgets/receipt_layout.dart';

void main() {
  void setCompactViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget app(Widget home) => MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.3),
          ),
          child: child!,
        ),
        home: home,
      );

  ReceiptLayout layout() => ReceiptLayout(
        heading: 'Receipt test',
        amount: 125,
        dateTime: DateTime(2026, 11, 20, 9, 15),
        rows: const [
          ReceiptDetailRow(label: 'Missing value'),
          ReceiptDetailRow(label: 'Empty value', value: '  '),
          ReceiptDetailRow(label: 'Visible value', value: 'Available'),
        ],
        note: 'Test note.',
        footer: 'Test footer.',
      );

  testWidgets('hides rows with missing or empty values without overflow',
      (tester) async {
    setCompactViewport(tester);
    await tester.pumpWidget(app(layout()));
    await tester.pump();

    expect(find.text('Missing value'), findsNothing);
    expect(find.text('Empty value'), findsNothing);
    expect(find.text('Visible value'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Done pops the receipt', (tester) async {
    setCompactViewport(tester);
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute<void>(builder: (_) => layout()),
              ),
              child: const Text('Open receipt'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open receipt'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Done'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('Open receipt'), findsOneWidget);
    expect(find.text('Receipt test'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
