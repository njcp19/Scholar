import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/scholarship_catalog_service.dart';
import '../theme/app_theme.dart';
import '../utils/scholarship_formatters.dart';
import '../widgets/app_icons.dart';
import '../widgets/widgets.dart';

class ScholarshipDetailsScreen extends StatelessWidget {
  final ScholarshipCatalogItem program;

  const ScholarshipDetailsScreen({
    super.key,
    required this.program,
  });

  String get _description {
    final description = program.description?.trim() ?? '';
    return description.isEmpty ? 'No description yet.' : description;
  }

  String get _allowance {
    final amount = program.allowanceAmount;
    if (amount == null || !amount.isFinite) return 'Not set yet';
    return 'PHP ${NumberFormat('#,##0.00').format(amount)}';
  }

  String get _paid {
    return switch (program.payoutFrequency) {
      'monthly' => 'Every month',
      'semester' => 'Every semester',
      _ => 'Not set yet',
    };
  }

  String get _support {
    final fromYear = program.supportFromYear;
    final toYear = program.supportToYear;
    if (fromYear == null || toYear == null) return 'Not set yet';
    return '${ordinalNumber(fromYear)} year to ${ordinalNumber(toYear)} year';
  }

  String get _slots {
    final limit = program.slots;
    if (limit == null) return 'No slot limit set';
    final remaining =
        limit <= 0 ? 0 : (limit - program.slotsTaken).clamp(0, limit).toInt();
    return '$remaining of $limit slots left';
  }

  double? get _usedSlotsProgress {
    final limit = program.slots;
    if (limit == null) return null;
    if (limit <= 0) return 0;
    return (program.slotsTaken / limit).clamp(0.0, 1.0).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        leadingWidth: 70,
        leading: Padding(
          padding: const EdgeInsets.only(left: 26),
          child: IconButton(
            onPressed: () => Navigator.maybePop(context),
            style: IconButton.styleFrom(
              fixedSize: const Size(42, 42),
              padding: EdgeInsets.zero,
              backgroundColor: colors.surface,
              foregroundColor: colors.textPrimary,
              shape: const CircleBorder(),
              side: BorderSide(color: colors.borderSoft),
            ),
            icon: const Icon(AppIcons.back, size: 20),
          ),
        ),
        title: Text(
          'Scholarship details',
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
        backgroundColor: colors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              children: [
                _headerCard(context),
                const SizedBox(height: 16),
                _allowanceCard(context),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _statTile(
                        context,
                        icon: AppIcons.calendar,
                        label: 'SUPPORT',
                        value: _support,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _statTile(
                        context,
                        icon: AppIcons.users,
                        label: 'SLOTS',
                        value: _slots,
                        progress: _usedSlotsProgress,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                InfoBanner(
                  icon: AppIcons.info,
                  message:
                      'Slots are shown for information. The admin decides on approval.',
                  maxLines: 3,
                  backgroundColor: colors.brandTint,
                  iconColor: colors.brand,
                  textColor: colors.textBody,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  borderRadius: 16,
                  fontSize: 12,
                  textHeight: 1.4,
                ),
                const SizedBox(height: 16),
                _descriptionCard(context),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              child: PrimaryButton(
                label: 'Select this scholarship',
                onPressed: () => Navigator.pop(context, program.name),
                minHeight: 56,
                borderRadius: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerCard(BuildContext context) {
    final colors = context.colors;
    return AppCard(
      padding: EdgeInsets.zero,
      radius: 28,
      shadow: true,
      borderColor: Colors.transparent,
      borderWidth: 0,
      clipBehavior: Clip.antiAlias,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [colors.header, colors.receiptHeroEnd],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: colors.onHeader.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Icon(
                AppIcons.award,
                color: colors.onHeader,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Scholarship',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.onHeader.withValues(alpha: .82),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    program.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.onHeader,
                      fontSize: 18,
                      height: 1.2,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _allowanceCard(BuildContext context) {
    final colors = context.colors;
    final amount = program.allowanceAmount;
    final amountIsSet = amount != null && amount.isFinite;
    return AppCard(
      padding: EdgeInsets.zero,
      radius: 22,
      shadow: true,
      borderColor: Colors.transparent,
      borderWidth: 0,
      clipBehavior: Clip.antiAlias,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [colors.balanceHeroStart, colors.balanceHeroEnd],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionLabel(
                    'ALLOWANCE',
                    labelColor: colors.balanceHeroText.withValues(alpha: .72),
                    fontSize: 10,
                    letterSpacing: 1.1,
                  ),
                  const SizedBox(height: 8),
                  if (amountIsSet)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _allowance,
                        maxLines: 1,
                        style: TextStyle(
                          color: colors.balanceHeroText,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                    )
                  else
                    Text(
                      _allowance,
                      style: TextStyle(
                        color: colors.balanceHeroText.withValues(alpha: .72),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              constraints: const BoxConstraints(maxWidth: 150),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: colors.balanceHeroText.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _paid,
                  maxLines: 1,
                  style: TextStyle(
                    color: colors.balanceHeroText.withValues(
                      alpha: program.payoutFrequency == null ? .68 : 1,
                    ),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    double? progress,
  }) {
    final colors = context.colors;
    return AppCard(
      padding: const EdgeInsets.all(12),
      radius: 22,
      shadow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: colors.brandTint,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: colors.brand, size: 20),
          ),
          const SizedBox(height: 12),
          SectionLabel(
            label,
            labelColor: colors.hintContrast,
            fontSize: 10,
            letterSpacing: 1,
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (progress != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: colors.brandTint,
                valueColor: AlwaysStoppedAnimation<Color>(colors.brand),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _descriptionCard(BuildContext context) {
    final colors = context.colors;
    final isSet = program.description?.trim().isNotEmpty ?? false;
    return AppCard(
      padding: const EdgeInsets.all(16),
      radius: 22,
      shadow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(
            'DESCRIPTION',
            labelColor: colors.hintContrast,
            fontSize: 10,
            letterSpacing: 1,
          ),
          const SizedBox(height: 10),
          Text(
            _description,
            style: TextStyle(
              color: isSet ? colors.textBody : colors.hintContrast,
              fontSize: 14,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}
