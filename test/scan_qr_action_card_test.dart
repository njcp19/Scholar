import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholar_wallet/screens/scan_claim_screen.dart';
import 'package:scholar_wallet/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'manual scan action fits at compact size and increased text scale',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final textScale in [1.0, 1.3]) {
      await tester.pumpWidget(_app(textScale));
      await tester.pumpAndSettle();

      final title = find.text('Device biometrics confirm the payout');
      final description = find.text("You'll be asked right after scanning");
      final manualLabel = find.text('Enter code');
      expect(title, findsOneWidget);
      expect(description, findsOneWidget);
      expect(find.text('From gallery'), findsNothing);
      expect(manualLabel, findsOneWidget);

      expect(
        tester.renderObject<RenderParagraph>(manualLabel).didExceedMaxLines,
        isFalse,
      );
      expect(
        tester.renderObject<RenderParagraph>(description).didExceedMaxLines,
        isFalse,
      );

      final infoRow =
          find.ancestor(of: title, matching: find.byType(Row)).first;
      final manualButton = find
          .ancestor(of: manualLabel, matching: find.byType(ElevatedButton))
          .first;
      expect(
        tester.getBottomLeft(infoRow).dy,
        lessThan(tester.getTopLeft(manualButton).dy),
      );
      expect(
        tester.getSize(manualButton).width,
        greaterThan(200),
      );
      expect(
        tester.getSize(manualButton).height,
        greaterThanOrEqualTo(48),
      );
      expect(tester.takeException(), isNull);
    }
  });
}

Widget _app(double textScale) {
  return MaterialApp(
    theme: AppTheme.dark,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
      ),
      child: child!,
    ),
    home: Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              width: double.infinity,
              child: ScanQrActionCard(
                fingerprintRegistered: true,
                onBiometricTap: () {},
                onManualPressed: () {},
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
