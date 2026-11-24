import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholar_wallet/widgets/widgets.dart';

void main() {
  testWidgets('shared snackbar fits 360dp above bottom navigation',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (buildContext) {
              context = buildContext;
              return const SizedBox.expand();
            },
          ),
          bottomNavigationBar: const SizedBox(
            key: ValueKey('bottom-navigation'),
            height: 72,
          ),
        ),
      ),
    );

    showAppSnackBar(
      context,
      'A long notification message that must stay within two lines on a narrow screen.',
      type: AppSnackBarType.error,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final errorSnackBarFinder = find.ancestor(
      of: find.text(
        'A long notification message that must stay within two lines on a narrow screen.',
      ),
      matching: find.byType(SnackBar),
    );
    final snackBar = tester.widget<SnackBar>(errorSnackBarFinder);
    final message = tester.widget<Text>(
      find.text(
        'A long notification message that must stay within two lines on a narrow screen.',
      ),
    );
    final errorSurfaceFinder = find.descendant(
      of: errorSnackBarFinder,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Material && widget.color == const Color(0xFFFDECEC),
      ),
    );
    final errorSnackBarSize = tester.getSize(errorSurfaceFinder);
    expect(snackBar.behavior, SnackBarBehavior.floating);
    expect(snackBar.duration, const Duration(seconds: 4));
    expect(snackBar.margin, const EdgeInsets.fromLTRB(16, 0, 16, 16));
    expect(snackBar.backgroundColor, const Color(0xFFFDECEC));
    expect((snackBar.content as SizedBox).height, 56);
    expect(errorSnackBarSize.height, greaterThan(56));
    expect(message.maxLines, 2);
    expect(message.style?.color, const Color(0xFFA52A2A));
    expect(message.style?.fontSize, 14);
    expect(message.style?.fontWeight, FontWeight.w600);
    expect(tester.widget<Icon>(find.byType(Icon)).size, 20);
    expect(
      (snackBar.shape as RoundedRectangleBorder).borderRadius,
      BorderRadius.circular(14),
    );
    expect(
      (snackBar.shape as RoundedRectangleBorder).side.color,
      const Color(0xFFF0B8B8),
    );
    expect(
        tester.widget<Icon>(find.byType(Icon)).color, const Color(0xFFA52A2A));
    expect(
      tester.getRect(find.byType(SnackBar)).bottom,
      lessThanOrEqualTo(
        tester.getRect(find.byKey(const ValueKey('bottom-navigation'))).top,
      ),
    );
    expect(tester.takeException(), isNull);

    showAppSnackBar(context, 'Newest info', type: AppSnackBarType.info);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    final infoSnackBarFinder = find.ancestor(
      of: find.text('Newest info'),
      matching: find.byType(SnackBar),
    );
    final infoSnackBar = tester.widget<SnackBar>(infoSnackBarFinder);
    final infoMessage = tester.widget<Text>(find.text('Newest info'));
    final infoSurfaceFinder = find.descendant(
      of: infoSnackBarFinder,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Material && widget.color == const Color(0xFFEAF2FE),
      ),
    );
    expect(find.text(message.data!), findsNothing);
    expect(infoSnackBar.backgroundColor, const Color(0xFFEAF2FE));
    expect(infoMessage.style?.color, const Color(0xFF1E5AA8));
    expect(infoSnackBar.margin, snackBar.margin);
    expect(tester.getSize(infoSurfaceFinder), errorSnackBarSize);
    expect(infoMessage.style?.fontSize, message.style?.fontSize);
    expect(infoMessage.style?.fontWeight, message.style?.fontWeight);
    expect(tester.widget<Icon>(find.byType(Icon)).size, 20);
    expect(
        tester.widget<Icon>(find.byType(Icon)).color, const Color(0xFF1E5AA8));

    showAppSnackBar(
      context,
      'Saved',
      type: AppSnackBarType.success,
      action: SnackBarAction(label: 'REVIEW', onPressed: () {}),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    final successSnackBarFinder = find.ancestor(
      of: find.text('Saved'),
      matching: find.byType(SnackBar),
    );
    final successSnackBar = tester.widget<SnackBar>(successSnackBarFinder);
    final successMessage = tester.widget<Text>(find.text('Saved'));
    expect(successSnackBar.backgroundColor, const Color(0xFFE5F8F0));
    expect(successSnackBar.action, isNotNull);
    expect(successMessage.style?.color, const Color(0xFF08734D));
    expect(successSnackBar.margin, snackBar.margin);
    expect((successSnackBar.content as SizedBox).height, 56);
    expect(successMessage.style?.fontSize, message.style?.fontSize);
    expect(successMessage.style?.fontWeight, message.style?.fontWeight);
    expect(tester.widget<Icon>(find.byType(Icon)).size, 20);
    expect(
        tester.widget<Icon>(find.byType(Icon)).color, const Color(0xFF08734D));
    expect(tester.takeException(), isNull);
  });
}
