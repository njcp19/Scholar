import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../theme/app_theme.dart';
import 'app_icons.dart';
import 'widgets.dart';

class ReceiptDetailRow {
  final String label;
  final String? value;
  final String? statusLabel;
  final Color? statusColor;
  final Color? statusBackgroundColor;

  const ReceiptDetailRow({
    required this.label,
    this.value,
    this.statusLabel,
    this.statusColor,
    this.statusBackgroundColor,
  });

  bool get isVisible =>
      (value?.trim().isNotEmpty ?? false) ||
      (statusLabel?.trim().isNotEmpty ?? false);

  String get shareValue =>
      statusLabel?.trim().isNotEmpty == true ? statusLabel! : value!;
}

class ReceiptHeroCard extends StatelessWidget {
  final String heading;
  final double amount;
  final String? dateLabel;
  final Widget? leading;
  final Widget? supportingContent;

  const ReceiptHeroCard({
    super.key,
    required this.heading,
    required this.amount,
    this.dateLabel,
    this.leading,
    this.supportingContent,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final mutedHeroText = colors.onHeader.withValues(alpha: .84);
    return AppCard(
      radius: 28,
      shadow: true,
      clipBehavior: Clip.hardEdge,
      borderColor: Colors.transparent,
      borderWidth: 0,
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 22),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [colors.header, colors.receiptHeroEnd],
      ),
      child: Stack(
        children: [
          CardDecorShapes(
            color: colors.onHeader,
            borderRadius: BorderRadius.circular(28),
            circleSize: 115,
            blobSize: 125,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                leading ??
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: colors.onHeader.withValues(alpha: .18),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: colors.success,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          AppIcons.check,
                          color: colors.onHeader,
                          size: 36,
                        ),
                      ),
                    ),
                const SizedBox(height: 14),
                Text(
                  heading,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: mutedHeroText,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                HeroAmountText(
                  prefix: 'PHP ',
                  amount: fmtPhp(amount),
                  color: colors.onHeader,
                  alignment: Alignment.center,
                  letterSpacing: -1,
                ),
                if (dateLabel != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    dateLabel!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: mutedHeroText,
                      fontSize: 12.5,
                    ),
                  ),
                ],
                if (supportingContent != null) ...[
                  const SizedBox(height: 12),
                  supportingContent!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ReceiptLayout extends StatelessWidget {
  final String heading;
  final double amount;
  final DateTime dateTime;
  final List<ReceiptDetailRow> rows;
  final String? note;
  final String footer;
  final String shareSubject;

  const ReceiptLayout({
    super.key,
    required this.heading,
    required this.amount,
    required this.dateTime,
    required this.rows,
    this.note,
    required this.footer,
    this.shareSubject = 'Scholar Wallet receipt',
  });

  String get _formattedDate =>
      DateFormat('MMM d, yyyy · h:mm a').format(dateTime);

  List<ReceiptDetailRow> get _visibleRows =>
      rows.where((row) => row.isVisible).toList(growable: false);

  String get _shareText => [
        heading,
        'PHP ${fmtPhp(amount)}',
        for (final row in _visibleRows) '${row.label}: ${row.shareValue}',
        if (note != null) note!,
        footer,
      ].join('\n');

  Future<void> _share(BuildContext context) async {
    try {
      final result = await SharePlus.instance.share(
        ShareParams(
          text: _shareText,
          subject: shareSubject,
        ),
      );
      if (result.status == ShareResultStatus.unavailable && context.mounted) {
        showMsg(context, 'Could not share the receipt on this device.',
            error: true);
      }
    } catch (_) {
      if (context.mounted) {
        showMsg(context, 'Could not share the receipt. Please try again.',
            error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: context.colors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leadingWidth: 70,
        leading: Padding(
          padding: const EdgeInsets.only(left: 26),
          child: Material(
            color: context.colors.surface,
            shape: CircleBorder(
              side: BorderSide(color: context.colors.borderSoft),
            ),
            child: IconButton(
              onPressed: () => Navigator.maybePop(context),
              tooltip: 'Back',
              constraints: const BoxConstraints.tightFor(
                width: 44,
                height: 44,
              ),
              padding: EdgeInsets.zero,
              icon: Icon(
                AppIcons.back,
                color: context.colors.textPrimary,
                size: 21,
              ),
            ),
          ),
        ),
        title: Text(
          'Receipt',
          style: TextStyle(
            color: context.colors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 26),
            child: Material(
              color: context.colors.surface,
              shape: CircleBorder(
                side: BorderSide(color: context.colors.borderSoft),
              ),
              child: IconButton(
                onPressed: () => _share(context),
                tooltip: 'Share receipt',
                constraints: const BoxConstraints.tightFor(
                  width: 44,
                  height: 44,
                ),
                padding: EdgeInsets.zero,
                icon: Icon(
                  Icons.share_outlined,
                  color: context.colors.brand,
                  size: 21,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            _hero,
            const SizedBox(height: 16),
            AppCard(
              radius: 22,
              shadow: true,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var index = 0; index < _visibleRows.length; index++) ...[
                    if (index > 0)
                      const Divider(
                        height: 1,
                        thickness: 1,
                        color: Color(0xFFEEF1F6),
                      ),
                    _detailRow(context, _visibleRows[index]),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Done',
              icon: AppIcons.check,
              minHeight: 56,
              borderRadius: 18,
              shadow: true,
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(height: 10),
            SecondaryButton(
              label: 'Share receipt',
              icon: Icons.share_outlined,
              foregroundColor: context.colors.brand,
              iconColor: context.colors.brand,
              minHeight: 52,
              borderColor: const Color(0xFFE3E8EF),
              borderRadius: 18,
              onPressed: () => _share(context),
            ),
            const SizedBox(height: 24),
            Text(
              footer,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.colors.textBody,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget get _hero => ReceiptHeroCard(
        heading: heading,
        amount: amount,
        dateLabel: _formattedDate,
      );

  Widget _detailRow(BuildContext context, ReceiptDetailRow row) {
    final value = row.statusLabel?.trim().isNotEmpty == true
        ? Align(
            alignment: Alignment.centerRight,
            child: StatusChip(
              row.statusLabel!,
              color: row.statusColor ?? context.colors.successText,
              bg: row.statusBackgroundColor ?? context.colors.successBg,
              borderRadius: 10,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              fontSize: 11,
              letterSpacing: .3,
            ),
          )
        : Text(
            row.value!,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              row.label,
              style: TextStyle(
                color: context.colors.textBody,
                fontSize: 13.5,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerRight,
              child: value,
            ),
          ),
        ],
      ),
    );
  }
}
