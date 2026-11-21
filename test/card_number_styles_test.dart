import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholar_wallet/theme/app_theme.dart';
import 'package:scholar_wallet/widgets/widgets.dart';

void main() {
  testWidgets('hero and stat numbers use shared standard sizes and scale down',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(
      width: 320,
      textScale: 1,
      heroValue: '19,000.00',
      statValue: '13,000.00',
    ));

    expect(tester.widget<Text>(find.text('19,000.00')).style!.fontSize, 30);
    expect(tester.widget<Text>(find.text('PHP').first).style!.fontSize, 16);
    expect(tester.widget<Text>(find.text('13,000.00')).style!.fontSize, 22);
    expect(tester.widget<Text>(find.text('PHP').last).style!.fontSize, 12);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(320, 640);
    await tester.pumpWidget(_app(
      width: 230,
      textScale: 1.3,
      heroValue: '1,234,567,890.00',
      statValue: '1,234,567,890.00',
    ));

    expect(find.text('1,234,567,890.00'), findsNWidgets(2));
    final heroValue = find.text('1,234,567,890.00').first;
    final statValue = find.text('1,234,567,890.00').last;
    expect(tester.getRect(heroValue).width, lessThan(190));
    expect(tester.getRect(statValue).width, lessThan(190));
    expect(tester.takeException(), isNull);
  });
}

Widget _app({
  required double width,
  required double textScale,
  required String heroValue,
  required String statValue,
}) {
  return MaterialApp(
    theme: AppTheme.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
      ),
      child: child!,
    ),
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: width,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _NumberStylesContent(
              heroValue: heroValue,
              statValue: statValue,
            ),
          ),
        ),
      ),
    ),
  );
}

class _NumberStylesContent extends StatelessWidget {
  final String heroValue;
  final String statValue;

  const _NumberStylesContent({
    required this.heroValue,
    required this.statValue,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        HeroAmountText(
          prefix: 'PHP',
          amount: heroValue,
          color: Colors.white,
        ),
        StatNumberText(
          prefix: 'PHP',
          value: statValue,
          color: const Color(0xFF1A2530),
        ),
      ],
    );
  }
}
