import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholar_wallet/screens/admin/issue_payout_screen.dart';
import 'package:scholar_wallet/screens/cashout_screen.dart';
import 'package:scholar_wallet/theme/app_theme.dart';
import 'package:scholar_wallet/widgets/receipt_layout.dart';
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

  testWidgets('highlight cards clip and layer shared shapes behind content', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final cards = [
      const _CardCase(
        CashoutBalanceHeroCard(balance: 1234567.89),
        'AVAILABLE BALANCE',
      ),
      const _CardCase(
        IssuePayoutAmountCard(
          amount: 1234567.89,
          onChangeStandardAmount: _noop,
        ),
        'AMOUNT PER SCHOLAR (FIXED)',
      ),
      const _CardCase(
        ReceiptHeroCard(
          heading: 'Payout received',
          amount: 1234567.89,
        ),
        'Payout received',
      ),
    ];

    for (final cardCase in cards) {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.3),
            ),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: cardCase.card,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(cardCase.label), findsOneWidget);
      expect(find.bySemanticsLabel('PHP 1,234,567.89'), findsOneWidget);

      final shapes = tester.widget<CardDecorShapes>(
        find.byType(CardDecorShapes).first,
      );
      expect(shapes.borderRadius, BorderRadius.circular(28));
      final clip = tester.widget<ClipRRect>(
        find.descendant(
          of: find.byType(CardDecorShapes).first,
          matching: find.byType(ClipRRect),
        ),
      );
      expect(clip.borderRadius, BorderRadius.circular(28));

      expect(
        tester.widgetList<Stack>(find.byType(Stack)).any(
              (stack) =>
                  stack.children.isNotEmpty &&
                  stack.children.first is CardDecorShapes,
            ),
        isTrue,
      );
      expect(tester.takeException(), isNull, reason: cardCase.label);
    }
  });
}

class _CardCase {
  final Widget card;
  final String label;

  const _CardCase(this.card, this.label);
}

void _noop() {}
