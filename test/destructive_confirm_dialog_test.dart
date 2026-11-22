import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholar_wallet/theme/app_theme.dart';
import 'package:scholar_wallet/widgets/app_icons.dart';
import 'package:scholar_wallet/widgets/destructive_confirm_dialog.dart';

void main() {
  Widget app(Widget child) => MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.3),
          ),
          child: child!,
        ),
        home: child,
      );

  void setCompactViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('delete confirmation returns false or true without overflow',
      (tester) async {
    setCompactViewport(tester);
    final longName = List.filled(40, 'S').join();
    final title = 'Delete $longName?';
    final message = 'This will permanently remove $longName and all of their '
        'transaction, payout, linked-account, and registration-review records. '
        'Accounts with a balance cannot be deleted. This cannot be undone.';
    bool? result;
    var confirmActions = 0;

    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await DestructiveConfirmDialog.show(
                  context,
                  title: title,
                  message: message,
                  dismissLabel: 'Cancel',
                  confirmLabel: 'Delete',
                  semanticsLabel: 'Delete scholar confirmation',
                  icon: AppIcons.delete,
                );
                if (result == true) confirmActions++;
              },
              child: const Text('Open delete confirmation'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open delete confirmation'));
    await tester.pumpAndSettle();
    expect(find.text(title), findsOneWidget);
    expect(find.text(message), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Delete scholar confirmation',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
    expect(confirmActions, 0);

    await tester.tap(find.text('Open delete confirmation'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
    expect(confirmActions, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('payout cancellation handles a large amount at narrow size',
      (tester) async {
    setCompactViewport(tester);
    const scholarName = 'SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS';
    const title = 'Cancel this payout?';
    const message = 'PHP 1,234,567.89 reserved for $scholarName will be '
        'released. Their QR code will stop working.';
    bool? result;
    var confirmActions = 0;

    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await DestructiveConfirmDialog.show(
                  context,
                  title: title,
                  message: message,
                  dismissLabel: 'Keep',
                  confirmLabel: 'Cancel payout',
                  semanticsLabel: 'Cancel payout confirmation',
                  icon: AppIcons.cancel,
                );
                if (result == true) confirmActions++;
              },
              child: const Text('Open payout confirmation'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open payout confirmation'));
    await tester.pumpAndSettle();
    expect(find.text(title), findsOneWidget);
    expect(find.text(message), findsOneWidget);
    expect(find.text('Keep'), findsOneWidget);
    expect(find.text('Cancel payout'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Cancel payout confirmation',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Keep'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
    expect(confirmActions, 0);

    await tester.tap(find.text('Open payout confirmation'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel payout'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
    expect(confirmActions, 1);
    expect(tester.takeException(), isNull);
  });
}
