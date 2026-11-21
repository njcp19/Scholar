import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholar_wallet/theme/app_theme.dart';
import 'package:scholar_wallet/widgets/widgets.dart';

void main() {
  testWidgets('shared card shapes preserve the child without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: Center(
            child: SizedBox(
              width: 280,
              height: 160,
              child: CardDecorShapes(
                color: Colors.white,
                borderRadius: BorderRadius.all(Radius.circular(28)),
                child: Center(
                  key: ValueKey('decorated-content'),
                  child: Text('Decorated child remains visible'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Decorated child remains visible'), findsOneWidget);
    final clip = tester.widget<ClipRRect>(
      find.descendant(
        of: find.byType(CardDecorShapes),
        matching: find.byType(ClipRRect),
      ),
    );
    expect(clip.borderRadius, BorderRadius.circular(28));

    final stack = tester.widget<Stack>(
      find.descendant(
        of: find.byType(CardDecorShapes),
        matching: find.byType(Stack),
      ),
    );
    expect(stack.clipBehavior, Clip.hardEdge);
    expect(stack.children, hasLength(3));
    for (final shape in stack.children.take(2)) {
      expect(shape, isA<Positioned>());
      final positioned = shape as Positioned;
      expect(positioned.left, isNull);
      expect(positioned.right, isNotNull);
      expect(positioned.child, isA<IgnorePointer>());
    }
    expect(stack.children.last.key, const ValueKey('decorated-content'));
    expect(tester.takeException(), isNull);
  });
}
