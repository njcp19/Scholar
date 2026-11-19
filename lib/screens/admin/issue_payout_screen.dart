import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../data/demo_allowance_repository.dart';
import '../../models/models.dart';
import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';
import '../../widgets/app_icons.dart';
import '../fingerprint_screen.dart';
import 'allowance_settings_screen.dart';
import 'funding_account_screen.dart';

/// Admin: issue a payout batch. The amount comes from the single standard
/// allowance setting and is NOT editable here, so every scholar is paid the
/// same. After generating, the admin gets one single-use QR per scholar.
class IssuePayoutScreen extends StatefulWidget {
  const IssuePayoutScreen({super.key});
  @override
  State<IssuePayoutScreen> createState() => _IssuePayoutScreenState();
}

class _IssuePayoutScreenState extends State<IssuePayoutScreen> {
  final _batchTitle = TextEditingController();
  final _academicPeriod = TextEditingController();
  final _distributionDate = TextEditingController();
  DateTime? _selectedDistributionDate;
  List<Scholar> _scholars = [];
  FundingAccount? _fundingAccount;
  FundSummary? _fundSummary;
  bool _fundingAccountLoaded = false;
  bool _loading = true;
  bool _busy = false;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _batchTitle.dispose();
    _academicPeriod.dispose();
    _distributionDate.dispose();
    super.dispose();
  }

  Future<void> _pickDistributionDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedDistributionDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _selectedDistributionDate =
          DateTime(selected.year, selected.month, selected.day);
      _distributionDate.text =
          DateFormat('MMM d, yyyy').format(_selectedDistributionDate!);
    });
  }

  Future<void> _load() async {
    _fundingAccount = null;
    _fundSummary = null;
    _fundingAccountLoaded = false;
    try {
      final state = context.read<AppState>();
      await state.loadAllowanceSettings();
      final all = await state.wallet.getScholars();
      // Deactivated scholars cannot receive a payout.
      _scholars = all
          .where((s) =>
              s.active && s.verificationStatus == VerificationStatus.approved)
          .toList();
      _batchTitle.text = '${state.allowance.label} • ${DateTime.now().year}';

      try {
        _fundingAccount = await state.wallet.getFundingAccount();
        _fundingAccountLoaded = true;
      } catch (_) {
        _fundingAccount = null;
      }

      try {
        _fundSummary = await state.wallet.getFundSummary();
      } catch (_) {
        _fundSummary = null;
      }
    } catch (_) {
      _scholars = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _openFundingAccount() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FundingAccountScreen()),
    );
    if (mounted) await _load();
  }

  Future<void> _generate() async {
    if (_generating) return;
    final state = context.read<AppState>();
    final selected = _scholars.where((s) => s.selected).toList();
    if (selected.isEmpty) {
      showMsg(context, 'Select at least one scholar.', error: true);
      return;
    }
    final distributionDate = _selectedDistributionDate;
    if (distributionDate == null) {
      showMsg(context, 'Select a distribution date.', error: true);
      return;
    }
    setState(() => _generating = true);
    try {
      // FR-29: the admin confirms the disbursement with the device biometric
      // prompt before any QR is generated or any amount is reserved.
      if (!state.fingerprintRegistered) {
        await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const FingerprintScreen(required: true)));
        if (!mounted || !state.fingerprintRegistered) return;
      }
      final selectedCount = selected.length;
      final total = selectedCount * state.allowance.allowanceAmount;
      final scholarWord = selectedCount == 1 ? 'scholar' : 'scholars';
      final confirmationMessage =
          'Disburse PHP ${fmtPhp(total)} to $selectedCount $scholarWord?';
      final confirmed = await _confirmDisbursement(
        selectedCount: selectedCount,
        total: total,
        amountPerScholar: state.allowance.allowanceAmount,
        batchTitle: _batchTitle.text.trim(),
        confirmationMessage: confirmationMessage,
      );
      if (!confirmed || !mounted) return;
      final verified = await state.verifyFingerprint(confirmationMessage);
      if (!mounted) return;
      if (!verified) {
        showMsg(context, 'Biometrics not verified. No payout was issued.',
            error: true);
        return;
      }
      setState(() => _busy = true);
      final claims = await state.wallet.generatePayoutBatch(
        batchTitle: _batchTitle.text.trim(),
        recipients: selected,
        distributionDate: distributionDate,
      );
      DemoAllowanceRepository.instance.setAcademicPeriod(
        _batchTitle.text.trim(),
        _academicPeriod.text,
      );
      if (!mounted) return;
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) => _QrSheetScreen(
                  claims: claims,
                  amount: state.allowance.allowanceAmount,
                  distributionDate: distributionDate,
                )),
      );
    } catch (_) {
      if (mounted) {
        showMsg(context, 'Could not issue the Payout. Please try again.',
            error: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _generating = false;
        });
      }
    }
  }

  Future<bool> _confirmDisbursement({
    required int selectedCount,
    required double total,
    required double amountPerScholar,
    required String batchTitle,
    required String confirmationMessage,
  }) async {
    final colors = context.colors;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: colors.surface.withValues(alpha: 0),
      barrierColor: colors.modalScrim.withValues(alpha: .55),
      sheetAnimationStyle: AnimationStyle(
        duration:
            reduceMotion ? Duration.zero : const Duration(milliseconds: 250),
        reverseDuration:
            reduceMotion ? Duration.zero : const Duration(milliseconds: 200),
      ),
      builder: (sheetContext) => AppBottomSheet(
        title: 'Confirm disbursement',
        radius: 28,
        contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
        showDragHandle: true,
        dragHandleSize: const Size(44, 5),
        dragHandleColor: colors.sheetHandle,
        dragHandleRadius: 3,
        header: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: colors.brandTint,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                AppIcons.fingerprint,
                size: 46,
                color: colors.brand,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Confirm disbursement',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              confirmationMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textBody,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      batchTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textBody,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        '$selectedCount x PHP ${fmtPhp(amountPerScholar)}',
                        maxLines: 1,
                        style: TextStyle(
                          color: colors.brand,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Confirm with your device biometrics',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textBody,
                fontSize: 13,
              ),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: SecondaryButton(
                label: 'Cancel',
                onPressed: () => Navigator.pop(sheetContext, false),
                minHeight: 52,
                borderRadius: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PrimaryButton(
                label: 'Continue',
                onPressed: () => Navigator.pop(sheetContext, true),
                icon: AppIcons.fingerprint,
                minHeight: 52,
                borderRadius: 18,
                iconSize: 20,
                iconSpacing: 8,
              ),
            ),
          ],
        ),
      ),
    );
    return confirmed == true;
  }

  Widget _amountCard(AppState state) {
    final colors = context.colors;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      radius: 28,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [colors.balanceHeroStart, colors.balanceHeroEnd],
      ),
      borderColor: colors.balanceHeroStart,
      borderWidth: 0,
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          Positioned(
            top: -98,
            right: -54,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: colors.onHeader.withValues(alpha: .13),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: -72,
            right: 30,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: colors.onHeader.withValues(alpha: .1),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AMOUNT PER SCHOLAR (FIXED)',
                style: TextStyle(
                  color: colors.balanceHeroText,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.3,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    'PHP',
                    style: TextStyle(
                      color: colors.balanceHeroText,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        fmtPhp(state.allowance.allowanceAmount),
                        maxLines: 1,
                        style: TextStyle(
                          color: colors.balanceHeroText,
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.8,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Set once for everybody. Every selected scholar gets exactly this amount.',
                style: TextStyle(
                  color: colors.balanceHeroText,
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 14),
              Material(
                color: colors.onHeader.withValues(alpha: .5),
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AllowanceSettingsScreen(),
                      ),
                    );
                    _load();
                  },
                  borderRadius: BorderRadius.circular(18),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          AppIcons.sliders,
                          size: 16,
                          color: colors.balanceHeroText,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Change standard amount',
                          style: TextStyle(
                            color: colors.balanceHeroText,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration(
    BuildContext context, {
    String? hintText,
    Widget? suffixIcon,
    bool focused = false,
  }) {
    final colors = context.colors;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(
        color: focused ? colors.brand : colors.border,
        width: focused ? 2 : 1,
      ),
    );
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: colors.hint, fontSize: 15),
      filled: true,
      fillColor: colors.surface,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: border,
      enabledBorder: border,
      focusedBorder: border,
      suffixIcon: suffixIcon,
    );
  }

  Widget _periodChips() {
    final colors = context.colors;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final period in ['1st Semester', '2nd Semester', 'Summer'])
          ActionChip(
            label: Text(
              period,
              style: TextStyle(
                color: colors.textBody,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: () => setState(() => _academicPeriod.text = period),
            backgroundColor: colors.surface,
            side: BorderSide(color: colors.border),
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            labelPadding: const EdgeInsets.symmetric(horizontal: 6),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }

  Widget _totalBar(int selectedCount, double total) {
    final colors = context.colors;
    final scholarLabel =
        '$selectedCount ${selectedCount == 1 ? 'scholar' : 'scholars'} selected';
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      radius: 22,
      backgroundColor: colors.brandTint,
      borderColor: colors.brandTint,
      borderWidth: 0,
      child: Row(
        children: [
          Expanded(
            child: Text(
              scholarLabel,
              style: TextStyle(
                color: colors.brand,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'PHP ${fmtPhp(total)}',
            style: TextStyle(
              color: colors.brand,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _fundingAccountCard(FundingAccount account) {
    final colors = context.colors;
    return AppCard(
      radius: 22,
      shadow: true,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: colors.warningBg,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(
              AppIcons.bankAccount,
              color: colors.warningText,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.bankName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${account.accountName} · •••• ${account.last4}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textBody,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          TextButton(
            onPressed: _openFundingAccount,
            style: TextButton.styleFrom(
              foregroundColor: colors.brand,
              minimumSize: const Size(48, 44),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text(
              'Manage',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fundCheckCard({
    required int selectedCount,
    required double amountPerScholar,
    required double total,
    required FundSummary summary,
  }) {
    final colors = context.colors;
    final enoughFunds = summary.available >= total;
    final finalLabel = enoughFunds ? 'Remaining after payout' : 'Shortfall';
    final finalAmount = enoughFunds
        ? 'PHP ${fmtPhp(summary.available - total)}'
        : 'PHP ${fmtPhp(total - summary.available)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(
          'FUND CHECK',
          labelColor: colors.textBody,
          fontSize: 11.5,
          letterSpacing: 1.2,
        ),
        const SizedBox(height: 10),
        AppCard(
          radius: 22,
          shadow: true,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              _fundCheckRow(
                'Available fund',
                'PHP ${fmtPhp(summary.available)}',
              ),
              Divider(height: 1, thickness: 1, color: colors.borderSoft),
              _fundCheckRow(
                'This payout',
                '$selectedCount x PHP ${fmtPhp(amountPerScholar)} = '
                    'PHP ${fmtPhp(total)}',
              ),
              Divider(height: 1, thickness: 1, color: colors.borderSoft),
              _fundCheckRow(
                finalLabel,
                finalAmount,
                valueColor:
                    enoughFunds ? colors.textPrimary : colors.dangerText,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _fundStatusBanner(
          enoughFunds: enoughFunds,
          shortfall: enoughFunds ? 0 : total - summary.available,
        ),
      ],
    );
  }

  Widget _fundCheckRow(String label, String value, {Color? valueColor}) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: colors.textBody,
                fontSize: 13.5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                value,
                maxLines: 1,
                softWrap: false,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: valueColor ?? colors.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fundStatusBanner({
    required bool enoughFunds,
    required double shortfall,
  }) {
    final colors = context.colors;
    final message = enoughFunds
        ? 'Enough funds for this payout.'
        : 'Not enough funds. Top up at least PHP ${fmtPhp(shortfall)} '
            'to continue.';
    final leading = Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: enoughFunds ? colors.success : colors.dangerText,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(
        enoughFunds ? AppIcons.check : AppIcons.warning,
        color: colors.onHeader,
        size: 22,
      ),
    );
    final banner = InfoBanner(
      icon: enoughFunds ? AppIcons.check : AppIcons.warning,
      message: message,
      leading: leading,
      maxLines: 3,
      backgroundColor: enoughFunds ? colors.successBg : Colors.transparent,
      iconColor: enoughFunds ? colors.successText : colors.dangerText,
      textColor: enoughFunds ? colors.successText : colors.dangerText,
      borderRadius: 18,
      padding: const EdgeInsets.all(16),
      fontSize: 13.5,
    );

    if (enoughFunds) return banner;
    return Semantics(
      liveRegion: true,
      child: AppCard(
        radius: 22,
        padding: EdgeInsets.zero,
        backgroundColor: colors.dangerBg,
        borderColor: colors.danger.withValues(alpha: .35),
        child: banner,
      ),
    );
  }

  Widget _loadingSkeleton() {
    Widget block(double height, {double radius = 16}) => Container(
          width: double.infinity,
          height: height,
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(radius),
          ),
        );

    return AppSkeletonizer(
      enabled: true,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          block(206, radius: 28),
          const SizedBox(height: 20),
          block(72),
          const SizedBox(height: 16),
          block(72),
          const SizedBox(height: 10),
          block(36, radius: 18),
          const SizedBox(height: 16),
          block(72),
          const SizedBox(height: 30),
          block(18),
          const SizedBox(height: 12),
          for (var index = 0; index < 3; index++) ...[
            block(68, radius: 18),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 4),
          block(56, radius: 18),
          const SizedBox(height: 18),
          block(56, radius: 18),
          const SizedBox(height: 12),
          block(52),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final selectedCount = _scholars.where((s) => s.selected).length;
    final total = selectedCount * state.allowance.allowanceAmount;
    final colors = context.colors;
    final fundingAccountMissing =
        _fundingAccountLoaded && _fundingAccount == null;
    final shortfall = _fundingAccount != null &&
            _fundSummary != null &&
            total > _fundSummary!.available
        ? total - _fundSummary!.available
        : 0.0;
    final insufficientFunds = shortfall > 0;

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
          'Issue payout event',
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
      body: _loading
          ? _loadingSkeleton()
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                _amountCard(state),
                if (_fundingAccount != null) ...[
                  const SizedBox(height: 20),
                  SectionLabel(
                    'FUNDING ACCOUNT',
                    labelColor: colors.textBody,
                    fontSize: 11.5,
                    letterSpacing: 1.2,
                  ),
                  const SizedBox(height: 10),
                  _fundingAccountCard(_fundingAccount!),
                  if (_fundSummary != null) ...[
                    const SizedBox(height: 18),
                    _fundCheckCard(
                      selectedCount: selectedCount,
                      amountPerScholar: state.allowance.allowanceAmount,
                      total: total,
                      summary: _fundSummary!,
                    ),
                  ],
                ] else if (fundingAccountMissing) ...[
                  const SizedBox(height: 20),
                  SectionLabel(
                    'FUNDING ACCOUNT',
                    labelColor: colors.textBody,
                    fontSize: 11.5,
                    letterSpacing: 1.2,
                  ),
                  const SizedBox(height: 10),
                  InfoBanner(
                    icon: AppIcons.warning,
                    message: 'Link a funding account before issuing a payout.',
                    backgroundColor: colors.warningBg,
                    iconColor: colors.warningText,
                    textColor: colors.warningText,
                    borderRadius: 18,
                    padding: const EdgeInsets.all(16),
                  ),
                  const SizedBox(height: 12),
                  PrimaryButton(
                    label: 'Link bank account',
                    icon: AppIcons.link,
                    minHeight: 56,
                    borderRadius: 18,
                    onPressed: _openFundingAccount,
                  ),
                ],
                const SizedBox(height: 16),
                _label('Batch title'),
                AppTextField(
                  controller: _batchTitle,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: _fieldDecoration(context),
                ),
                const SizedBox(height: 16),
                _label('Academic period (optional)'),
                AppTextField(
                  controller: _academicPeriod,
                  hintText: '1st Semester AY 2026-2027',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: _fieldDecoration(
                    context,
                    hintText: '1st Semester AY 2026-2027',
                  ),
                ),
                const SizedBox(height: 10),
                _periodChips(),
                const SizedBox(height: 16),
                _label('Distribution date (required)'),
                AppTextField(
                  controller: _distributionDate,
                  readOnly: true,
                  onTap: _pickDistributionDate,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: _fieldDecoration(
                    context,
                    hintText: 'Select a date',
                    focused: _distributionDate.text.isNotEmpty,
                    suffixIcon: Icon(
                      AppIcons.calendar,
                      size: 19,
                      color: colors.textBody,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This date is saved with the payout event. QR codes can be '
                  'generated and scanned immediately.',
                  style: TextStyle(
                    color: colors.textBody,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 24),
                SectionLabel(
                  'RECIPIENTS',
                  labelColor: colors.textBody,
                  fontSize: 11.5,
                  letterSpacing: 1.2,
                  trailing: TextButton(
                    onPressed: () => setState(() {
                      final all = selectedCount != _scholars.length;
                      for (final scholar in _scholars) {
                        scholar.selected = all;
                      }
                    }),
                    style: TextButton.styleFrom(
                      foregroundColor: colors.brand,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 40),
                    ),
                    child: Text(
                      selectedCount == _scholars.length
                          ? 'Clear all'
                          : 'Select all',
                      style: TextStyle(
                        color: colors.brand,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                if (_scholars.isEmpty)
                  const EmptyState(
                    icon: AppIcons.users,
                    title: 'No active scholars yet',
                    message: 'Activate scholars in Manage Scholars first.',
                  )
                else
                  ..._scholars.map(_scholarTile),
                const SizedBox(height: 16),
                _totalBar(selectedCount, total),
                if (insufficientFunds) ...[
                  const SizedBox(height: 12),
                  SecondaryButton(
                    label: 'Top up fund',
                    onPressed: _openFundingAccount,
                    minHeight: 52,
                    borderRadius: 18,
                  ),
                ],
                const SizedBox(height: 18),
                PrimaryButton(
                  label: 'Generate QR Codes',
                  onPressed:
                      _generating || fundingAccountMissing || insufficientFunds
                          ? null
                          : _generate,
                  icon: AppIcons.qrCode,
                  loading: _busy,
                  loadingLabel: 'Generate QR Codes',
                  minHeight: 56,
                  borderRadius: 18,
                  shadow: true,
                  iconSize: 20,
                  iconSpacing: 10,
                ),
                const SizedBox(height: 12),
                Text(
                  'Generating reserves the amount for each selected scholar. '
                  'The money is only released once the scholar scans their QR '
                  'code and verifies with device biometrics.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.textBody,
                    fontSize: 11.5,
                    height: 1.5,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _scholarTile(Scholar s) {
    final colors = context.colors;
    final parts = s.name.trim().split(RegExp(r'\s+'));
    final initials = parts
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    final avatarTextColor = Theme.of(context).brightness == Brightness.dark
        ? colors.textPrimary
        : colors.onGold;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ListRowCard(
        onTap: () => setState(() => s.selected = !s.selected),
        minHeight: 68,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        radius: 22,
        backgroundColor: colors.surface,
        borderColor: s.selected ? colors.brand : colors.border,
        borderWidth: s.selected ? 2 : 1,
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: s.selected ? colors.brand : colors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: s.selected ? colors.brand : colors.border,
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: s.selected
                  ? Icon(AppIcons.check, size: 16, color: colors.onHeader)
                  : null,
            ),
            const SizedBox(width: 12),
            CircleAvatar(
              radius: 20,
              backgroundColor: colors.avatarBackground,
              child: Text(
                initials.isEmpty ? '?' : initials,
                style: TextStyle(
                  color: avatarTextColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'ID: ${s.studentId}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textBody,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: s.fingerprintRegistered
                  ? 'Device biometrics registered'
                  : 'Device biometrics not registered',
              child: Icon(
                AppIcons.fingerprint,
                size: 18,
                color:
                    s.fingerprintRegistered ? colors.successText : colors.hint,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: context.colors.textLabel)),
      );
}

/// Shows the freshly generated single-use QR codes, one card per scholar.
class _QrSheetScreen extends StatelessWidget {
  final List<AllowanceClaim> claims;
  final double amount;
  final DateTime distributionDate;
  const _QrSheetScreen({
    required this.claims,
    required this.amount,
    required this.distributionDate,
  });

  Widget _claimCard(BuildContext context, AllowanceClaim claim) {
    final colors = context.colors;
    return AppCard(
      padding: const EdgeInsets.all(16),
      radius: 22,
      shadow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      claim.scholarName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      claim.batchTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textBody,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    'PHP ${fmtPhp(claim.amount)}',
                    maxLines: 1,
                    style: TextStyle(
                      color: colors.brand,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 214),
              child: AspectRatio(
                aspectRatio: 1,
                child: AppCard(
                  padding: EdgeInsets.zero,
                  radius: 22,
                  backgroundColor: colors.qrFrame,
                  borderColor: colors.border,
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: ClaimQrPanel(claim: claim, size: 190),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Single use • the scholar scans this in their app to confirm receipt',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.textBody,
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final qrCodeLabel = claims.length == 1 ? 'QR code' : 'QR codes';
    final successMessage = '${claims.length} $qrCodeLabel generated for PHP '
        '${fmtPhp(amount)} each. Distribution date: '
        '${DateFormat('MMM d, yyyy').format(distributionDate)}. '
        'Show a scholar their code. It can only be scanned once.';

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
          'Payout QR codes',
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
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          InfoBanner(
            icon: AppIcons.check,
            message: successMessage,
            maxLines: 6,
            backgroundColor: colors.successBg,
            iconColor: colors.onHeader,
            textColor: colors.successText,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            borderRadius: 20,
            fontSize: 12.5,
            textHeight: 1.5,
            leading: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: colors.success,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                AppIcons.check,
                color: colors.onHeader,
                size: 19,
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...claims.map(
            (claim) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _claimCard(context, claim),
            ),
          ),
        ],
      ),
    );
  }
}
