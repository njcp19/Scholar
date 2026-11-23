import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
