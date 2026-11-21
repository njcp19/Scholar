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
      action: SnackBarAction(label: 'REVIEW', onPressed: () {}),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    final message = tester.widget<Text>(
      find.text(
        'A long notification message that must stay within two lines on a narrow screen.',
      ),
    );
    expect(snackBar.behavior, SnackBarBehavior.floating);
    expect(snackBar.duration, const Duration(seconds: 4));
    expect(snackBar.margin, const EdgeInsets.fromLTRB(16, 0, 16, 16));
    expect(snackBar.backgroundColor, const Color(0xFFFDECEC));
    expect(message.maxLines, 2);
    expect(message.style?.color, const Color(0xFFA52A2A));
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
    await tester.pump(const Duration(milliseconds: 300));
    final infoSnackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    final infoMessage = tester.widget<Text>(find.text('Newest info'));
    expect(find.text(message.data!), findsNothing);
    expect(infoSnackBar.backgroundColor, const Color(0xFFEAF2FE));
    expect(infoMessage.style?.color, const Color(0xFF1E5AA8));
    expect(
        tester.widget<Icon>(find.byType(Icon)).color, const Color(0xFF1E5AA8));

    showAppSnackBar(context, 'Saved', type: AppSnackBarType.success);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final successSnackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    final successMessage = tester.widget<Text>(find.text('Saved'));
    expect(successSnackBar.backgroundColor, const Color(0xFFE5F8F0));
    expect(successMessage.style?.color, const Color(0xFF08734D));
    expect(
        tester.widget<Icon>(find.byType(Icon)).color, const Color(0xFF08734D));
    expect(tester.takeException(), isNull);
  });
}
