import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholar_wallet/screens/admin/issue_payout_screen.dart';
import 'package:scholar_wallet/screens/cashout_screen.dart';
import 'package:scholar_wallet/theme/app_theme.dart';
import 'package:scholar_wallet/widgets/receipt_layout.dart';
import 'package:scholar_wallet/widgets/widgets.dart';
import 'helpers/card_layering_test_utils.dart';

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
      find
          .descendant(
            of: find.byType(CardDecorShapes),
            matching: find.byType(Stack),
          )
          .first,
    );
    expect(stack.clipBehavior, Clip.none);
    expect(stack.children, hasLength(2));
    expect(stack.children.first, isA<Positioned>());
    expect(stack.children.last.key, const ValueKey('decorated-content'));
    expect(
      find.ancestor(
        of: find.byKey(const ValueKey('decorated-content')),
        matching: find.byType(ClipRRect),
      ),
      findsNothing,
    );
    expectNoForegroundPaint(tester, find.byType(CardDecorShapes));
    expectCardDecorShapesLayeredBehindContent(
      tester,
      find.byType(CardDecorShapes),
    );
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
      final card = find.byWidget(cardCase.card);
      expectNoForegroundPaint(tester, card);
      expectCardDecorShapesLayeredBehindContent(tester, card);

      if (cardCase.card is IssuePayoutAmountCard) {
        expect(
          find.text(
            'Set once for everybody. Every selected scholar gets exactly this amount.',
          ),
          findsOneWidget,
        );
        expect(find.text('Change standard amount'), findsOneWidget);
        final amountCardShapes = tester.widget<CardDecorShapes>(
          find.byType(CardDecorShapes).first,
        );
        final amountCardStack = tester.widget<Stack>(
          find
              .descendant(
                of: find.byType(IssuePayoutAmountCard),
                matching: find.byType(Stack),
              )
              .first,
        );
        expect(amountCardStack.children.first, isA<CardDecorShapes>());
        expect(amountCardShapes.circleSize, 45);
        expect(amountCardShapes.blobSize, 38);
      }

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

  testWidgets('enough-funds status uses compact sizing', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: IssuePayoutFundStatusBanner(
              enoughFunds: true,
              shortfall: 0,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Enough funds for this payout.'), findsOneWidget);
    final statusBox = find
        .descendant(
          of: find.byType(IssuePayoutFundStatusBanner),
          matching: find.byType(Container),
        )
        .first;
    final bannerRow = tester.widget<Row>(
      find.descendant(
        of: find.byType(IssuePayoutFundStatusBanner),
        matching: find.byType(Row),
      ),
    );
    final statusText = tester.widget<Text>(
      find.text('Enough funds for this payout.'),
    );
    expect(
      tester.getSize(statusBox).height,
      inInclusiveRange(44, 48),
    );
    expect(bannerRow.mainAxisAlignment, MainAxisAlignment.center);
    expect(bannerRow.mainAxisSize, MainAxisSize.min);
    expect(statusText.textAlign, TextAlign.center);
    expect(statusText.maxLines, 2);
    expect(statusText.overflow, TextOverflow.clip);
    expect(statusText.style?.fontSize, 13);
    expect(statusText.style?.fontWeight, FontWeight.w600);
    expect(statusText.style?.height, 1.1);
    expect(
      tester.getRect(find.byType(Row).first).center.dx,
      closeTo(tester.getRect(statusBox).center.dx, 2),
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.3),
          ),
          child: child!,
        ),
        home: const Scaffold(
          body: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: IssuePayoutFundStatusBanner(
              enoughFunds: true,
              shortfall: 0,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Enough funds for this payout.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('insufficient-funds status stays compact at narrow scaled size',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: IssuePayoutFundStatusBanner(
              enoughFunds: false,
              shortfall: 12345.67,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final standardStatusBox = find
        .descendant(
          of: find.byType(IssuePayoutFundStatusBanner),
          matching: find.byType(Container),
        )
        .first;
    expect(
      tester.getSize(standardStatusBox).height,
      lessThanOrEqualTo(56),
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.3),
          ),
          child: child!,
        ),
        home: const Scaffold(
          body: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: IssuePayoutFundStatusBanner(
              enoughFunds: false,
              shortfall: 12345.67,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('Not enough funds.'), findsOneWidget);
    final statusBox = find
        .descendant(
          of: find.byType(IssuePayoutFundStatusBanner),
          matching: find.byType(Container),
        )
        .first;
    expect(
      tester.getSize(statusBox).height,
      lessThanOrEqualTo(64),
    );
    final statusRow = find.descendant(
      of: find.byType(IssuePayoutFundStatusBanner),
      matching: find.byType(Row),
    );
    expect(
      tester.getRect(statusRow).center.dx,
      closeTo(tester.getRect(statusBox).center.dx, 2),
    );
    final statusText = tester.widget<Text>(
      find.textContaining('Not enough funds.'),
    );
    expect(statusText.textAlign, TextAlign.center);
    expect(statusText.maxLines, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('change standard amount keeps its callback', (tester) async {
    var changed = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: IssuePayoutAmountCard(
            amount: 500,
            onChangeStandardAmount: () => changed = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Change standard amount'));
    expect(changed, isTrue);
  });
}

class _CardCase {
  final Widget card;
  final String label;

  const _CardCase(this.card, this.label);
}

void _noop() {}
