import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholar_wallet/widgets/widgets.dart';

void expectNoForegroundPaint(WidgetTester tester, Finder card) {
  final foregroundPainters = find.descendant(
    of: card,
    matching: find.byWidgetPredicate((widget) {
      if (widget is Container) return widget.foregroundDecoration != null;
      if (widget is CustomPaint) return widget.foregroundPainter != null;
      return false;
    }),
  );
  final appForegroundPainters = foregroundPainters.evaluate().where((element) {
    final widget = element.widget;
    if (widget is CustomPaint && widget.foregroundPainter != null) {
      return element.findAncestorWidgetOfExactType<Material>() == null;
    }
    return true;
  });
  expect(appForegroundPainters, isEmpty);
}

void expectCardDecorShapesLayeredBehindContent(
  WidgetTester tester,
  Finder card,
) {
  final shapesFinder =
      find.descendant(of: card, matching: find.byType(CardDecorShapes));
  final shapesWidgets = <CardDecorShapes>[
    for (final element in card.evaluate())
      if (element.widget is CardDecorShapes) element.widget as CardDecorShapes,
    ...tester.widgetList<CardDecorShapes>(shapesFinder),
  ];
  expect(shapesWidgets, isNotEmpty);

  for (final shapes in shapesWidgets) {
    final shapesWidget = find.byWidget(shapes);
    final stack = tester.widget<Stack>(
      find
          .descendant(
            of: shapesWidget,
            matching: find.byType(Stack),
          )
          .first,
    );
    expect(stack.clipBehavior, Clip.none);
    expect(stack.children, hasLength(2));
    expect(stack.children.first, isA<Positioned>());
    expect(stack.children.last, same(shapes.child));

    final shapeLayer = stack.children.first as Positioned;
    expect(shapeLayer.child, isA<ClipRRect>());
    final shapeStack = tester.widget<Stack>(
      find
          .descendant(
            of: find.byWidget(shapeLayer.child),
            matching: find.byType(Stack),
          )
          .first,
    );
    expect(shapeStack.clipBehavior, Clip.hardEdge);
    expect(shapeStack.children, hasLength(2));
    for (final shape in shapeStack.children) {
      expect(shape, isA<Positioned>());
      final positioned = shape as Positioned;
      expect(positioned.left, isNull);
      expect(positioned.right, isNotNull);
      expect(positioned.child, isA<IgnorePointer>());
    }
  }
}
