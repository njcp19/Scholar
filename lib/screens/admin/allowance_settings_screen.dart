import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../data/demo_allowance_repository.dart';
import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';
import '../../widgets/app_icons.dart';

/// Admin: change the ONE standard allowance. There is no per-scholar input —
/// the amount, once saved, is what every scholar receives.
class AllowanceSettingsScreen extends StatefulWidget {
  const AllowanceSettingsScreen({super.key});
  @override
  State<AllowanceSettingsScreen> createState() =>
      _AllowanceSettingsScreenState();
}

class _AllowanceSettingsScreenState extends State<AllowanceSettingsScreen> {
  final _amount = TextEditingController();
  final _label = TextEditingController();
  final _expectedRelease = TextEditingController();
  DateTime? _expectedReleaseDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final a = context.read<AppState>().allowance;
    _amount.text = a.allowanceAmount.toStringAsFixed(2);
    _label.text = a.label;
    _expectedReleaseDate = DemoAllowanceRepository.instance.expectedReleaseDate;
    _expectedRelease.text = _formatDate(_expectedReleaseDate);
  }

  String _formatDate(DateTime? date) =>
      date == null ? '' : DateFormat('MMM d, yyyy').format(date);

  @override
  void dispose() {
    _amount.dispose();
    _label.dispose();
    _expectedRelease.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amount.text.replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      showMsg(context, 'Enter a valid amount greater than zero.', error: true);
      return;
    }
    final currentAmount = context.read<AppState>().allowance.allowanceAmount;
    final currentDate = DemoAllowanceRepository.instance.expectedReleaseDate;
    final currentRelease =
        currentDate == null ? 'None' : _formatDate(currentDate);
    final newRelease = _expectedReleaseDate == null
        ? 'None'
        : _formatDate(_expectedReleaseDate);
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Confirm allowance changes',
      message: 'Current amount: PHP ${fmtPhp(currentAmount)}\n'
          'New amount: PHP ${fmtPhp(amount)}\n'
          'Current expected release: $currentRelease\n'
          'New expected release: $newRelease\n\n'
          'This applies to future Payout Events. Payouts already reserved '
          'keep their amount.',
      confirmLabel: 'Confirm and save',
      rows: [
        ConfirmDialogRow(
          label: 'Amount',
          currentValue: 'PHP ${fmtPhp(currentAmount)}',
          newValue: 'PHP ${fmtPhp(amount)}',
        ),
        ConfirmDialogRow(
          label: 'Release',
          currentValue: currentRelease,
          newValue: newRelease,
        ),
      ],
      note: 'This applies to future Payout Events. Payouts already reserved '
          'keep their amount.',
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await context
          .read<AppState>()
          .updateAllowance(amount, label: _label.text.trim());
      DemoAllowanceRepository.instance
          .setExpectedReleaseDate(_expectedReleaseDate);
      if (!mounted) return;
      showMsg(context,
          'Standard allowance set to PHP ${fmtPhp(amount)} for all scholars.');
      Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        showMsg(context, 'Could not save Allowance settings. Please try again.',
            error: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickExpectedReleaseDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _expectedReleaseDate ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _expectedReleaseDate =
          DateTime(selected.year, selected.month, selected.day);
      _expectedRelease.text = _formatDate(_expectedReleaseDate);
    });
  }

  void _clearExpectedReleaseDate() {
    setState(() {
      _expectedReleaseDate = null;
      _expectedRelease.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final normalFieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: colors.border, width: 1),
    );
    final amountFieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: colors.brand, width: 2),
    );

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
          'Standard Allowance',
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
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          InfoBanner(
            icon: AppIcons.info,
            message: 'This amount is applied to EVERY scholar. You cannot give '
                'one scholar a different amount — that keeps the payout fair '
                'and auditable.',
            maxLines: 12,
            backgroundColor: colors.brandTint,
            iconColor: colors.brand,
            textColor: colors.brand,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            borderRadius: 20,
            fontSize: 12.5,
            textHeight: 1.5,
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colors.surface,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(AppIcons.info, color: colors.brand, size: 19),
            ),
          ),
          const SizedBox(height: 18),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            radius: 22,
            shadow: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _fieldLabel('Allowance amount (PHP)', colors.textLabel),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 64),
                  child: AppTextField(
                    controller: _amount,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                    decoration: InputDecoration(
                      prefixText: '₱',
                      prefixStyle: TextStyle(
                        color: colors.textBody,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                      hintText: '5000.00',
                      isDense: true,
                      filled: true,
                      fillColor: colors.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: amountFieldBorder,
                      enabledBorder: amountFieldBorder,
                      focusedBorder: amountFieldBorder,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [1000, 2500, 5000, 7500, 10000].map((value) {
                    final selected =
                        double.tryParse(_amount.text.replaceAll(',', '')) ==
                            value.toDouble();
                    return SizedBox(
                      height: 38,
                      child: ActionChip(
                        label: Text(
                          '₱${NumberFormat('#,##0').format(value)}',
                          style: TextStyle(
                            color: selected ? colors.brand : colors.textLabel,
                            fontSize: 13.5,
                            fontWeight:
                                selected ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                        onPressed: () => setState(
                          () => _amount.text =
                              value.toDouble().toStringAsFixed(2),
                        ),
                        backgroundColor:
                            selected ? colors.brandTint : colors.surface,
                        side: BorderSide(
                          color: selected ? colors.brand : colors.border,
                          width: selected ? 1.5 : 1,
                        ),
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                _fieldLabel('Label shown to scholars', colors.textLabel),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 50),
                  child: AppTextField(
                    controller: _label,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: 'e.g. November 2025 Allowance',
                      isDense: true,
                      filled: true,
                      fillColor: colors.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      border: normalFieldBorder,
                      enabledBorder: normalFieldBorder,
                      focusedBorder: normalFieldBorder,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Expected release date',
                        style: TextStyle(
                          color: colors.textLabel,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 50),
                  child: AppTextField(
                    controller: _expectedRelease,
                    readOnly: true,
                    onTap: _pickExpectedReleaseDate,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Select a date (optional)',
                      isDense: true,
                      filled: true,
                      fillColor: colors.surface,
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(left: 14, right: 10),
                        child: Icon(
                          AppIcons.calendar,
                          color: colors.textBody,
                          size: 19,
                        ),
                      ),
                      prefixIconConstraints: const BoxConstraints(
                        minWidth: 43,
                        minHeight: 50,
                      ),
                      suffixIcon: IconButton(
                        tooltip: _expectedReleaseDate == null
                            ? 'Choose date'
                            : 'Clear expected release date',
                        onPressed: _expectedReleaseDate == null
                            ? _pickExpectedReleaseDate
                            : _clearExpectedReleaseDate,
                        style: IconButton.styleFrom(
                          fixedSize: const Size(34, 34),
                          minimumSize: const Size(34, 34),
                          padding: EdgeInsets.zero,
                          backgroundColor: colors.background,
                          foregroundColor: colors.textBody,
                          shape: const CircleBorder(),
                        ),
                        icon: Icon(
                          _expectedReleaseDate == null
                              ? AppIcons.calendar
                              : AppIcons.close,
                          size: 19,
                        ),
                      ),
                      suffixIconConstraints: const BoxConstraints(
                        minWidth: 50,
                        minHeight: 50,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 0,
                        vertical: 14,
                      ),
                      border: normalFieldBorder,
                      enabledBorder: normalFieldBorder,
                      focusedBorder: normalFieldBorder,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Shown to scholars as an expected date. Nothing is released automatically.',
                  style: TextStyle(
                    color: colors.textBody,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          PrimaryButton(
            label: 'Save Standard Allowance',
            onPressed: _saving ? null : _save,
            loading: _saving,
            minHeight: 56,
            borderRadius: 18,
            shadow: true,
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String text, Color color) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      );
}
