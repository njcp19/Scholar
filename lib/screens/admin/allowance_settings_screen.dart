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
    final dateSummary = currentDate == null
        ? 'Current expected release: None'
        : 'Current expected release: ${_formatDate(currentDate)}';
    final newDateSummary = _expectedReleaseDate == null
        ? 'New expected release: None'
        : 'New expected release: ${_formatDate(_expectedReleaseDate)}';
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Confirm allowance changes',
      message: 'Current amount: PHP ${fmtPhp(currentAmount)}\n'
          'New amount: PHP ${fmtPhp(amount)}\n'
          '$dateSummary\n'
          '$newDateSummary\n\n'
          'This applies to future Payout Events. Payouts already reserved '
          'keep their amount.',
      confirmLabel: 'Confirm and save',
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
    } catch (e) {
      if (mounted) showMsg(context, 'Failed: $e', error: true);
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
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: Icon(
            AppIcons.back,
            color: context.colors.textPrimary,
          ),
        ),
        title: const Text('Standard Allowance'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const InfoBanner(
            icon: AppIcons.info,
            message: 'This amount is applied to EVERY scholar. You cannot give '
                'one scholar a different amount — that keeps the payout fair '
                'and auditable.',
          ),
          const SizedBox(height: 20),
          _label2('Allowance Amount (PHP)'),
          AppTextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            hintText: '5000.00',
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [1000, 2500, 5000, 7500, 10000]
                .map((v) => ActionChip(
                      label: Text('₱${v.toString()}',
                          style: const TextStyle(fontSize: 11)),
                      onPressed: () => setState(
                          () => _amount.text = v.toDouble().toStringAsFixed(2)),
                    ))
                .toList(),
          ),
          const SizedBox(height: 18),
          _label2('Label shown to scholars'),
          AppTextField(
            controller: _label,
            hintText: 'e.g. November 2025 Monthly Allowance',
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _label2('Expected release date')),
              if (_expectedReleaseDate != null)
                StatusChip(
                  'Demo data',
                  color: context.colors.textBody,
                  bg: context.colors.borderSoft,
                ),
            ],
          ),
          AppTextField(
            controller: _expectedRelease,
            readOnly: true,
            onTap: _pickExpectedReleaseDate,
            hintText: 'Select a date (optional)',
            suffixIcon: IconButton(
              tooltip: _expectedReleaseDate == null
                  ? 'Choose date'
                  : 'Clear expected release date',
              onPressed: _expectedReleaseDate == null
                  ? _pickExpectedReleaseDate
                  : _clearExpectedReleaseDate,
              icon: Icon(
                _expectedReleaseDate == null
                    ? AppIcons.calendar
                    : AppIcons.close,
                color: context.colors.textBody,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Shown to scholars as an expected date. Nothing is released automatically.',
            style: TextStyle(
              color: context.colors.textBody,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 28),
          PrimaryButton(
            label: 'Save Standard Allowance',
            onPressed: _saving ? null : _save,
            loading: _saving,
          ),
        ],
      ),
    );
  }

  Widget _label2(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.colors.textPrimary)),
      );
}
