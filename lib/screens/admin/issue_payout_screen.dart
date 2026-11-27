import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../data/demo_allowance_repository.dart';
import '../../models/models.dart';
import '../../providers/app_state.dart';
import '../../services/scholarship_catalog_service.dart';
import '../../services/wallet_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';
import '../../widgets/app_icons.dart';
import '../fingerprint_screen.dart';
import 'funding_account_screen.dart';
import 'program_payout_qr_screen.dart';

/// Admin: issue a payout batch for a selected scholarship program.
class IssuePayoutScreen extends StatefulWidget {
  const IssuePayoutScreen({super.key});
  @override
  State<IssuePayoutScreen> createState() => _IssuePayoutScreenState();
}

class _IssuePayoutScreenState extends State<IssuePayoutScreen> {
  final _catalogService = ScholarshipCatalogService();
  final _batchTitle = TextEditingController();
  final _academicPeriod = TextEditingController();
  final _distributionDate = TextEditingController();
  DateTime? _selectedDistributionDate;
  List<ScholarshipCatalogItem> _programs = [];
  List<ProgramRosterScholar> _roster = [];
  List<ProgramRosterScholar> _unassignedScholars = [];
  Map<String, ScholarshipProgramBudget> _programBudgets = {};
  ScholarshipCatalogItem? _selectedProgram;
  final Set<String> _selectedScholarIds = {};
  FundingAccount? _fundingAccount;
  FundSummary? _fundSummary;
  bool _fundingAccountLoaded = false;
  bool _loading = true;
  bool _rosterLoading = false;
  bool _fundingAccountLoadFailed = false;
  bool _showUnassigned = false;
  bool _busy = false;
  bool _generating = false;
  String? _loadError;
  String? _rosterError;

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
    _fundingAccountLoadFailed = false;
    _loadError = null;
    try {
      final state = context.read<AppState>();
      final results = await Future.wait<dynamic>([
        _catalogService.list(includeInactive: false),
        _catalogService.getProgramBudgets(),
        state.wallet.listUnassignedScholars(),
      ]);
      _programs = results[0] as List<ScholarshipCatalogItem>;
      final budgets = results[1] as List<ScholarshipProgramBudget>;
      _programBudgets = {
        for (final budget in budgets) budget.programName: budget,
      };
      _unassignedScholars = results[2] as List<ProgramRosterScholar>;
      _batchTitle.text = 'Scholarship payout • ${DateTime.now().year}';

      try {
        _fundingAccount = await state.wallet.getFundingAccount();
        _fundingAccountLoaded = true;
      } catch (error) {
        _fundingAccount = null;
        _fundingAccountLoaded = true;
        _fundingAccountLoadFailed = true;
        _loadError = error is WalletException
            ? error.message
            : 'Could not load the funding account. Please try again.';
      }

      try {
        _fundSummary = await state.wallet.getFundSummary();
      } catch (error) {
        _fundSummary = null;
        _loadError ??= error is WalletException
            ? error.message
            : 'Could not load available funds. Please try again.';
      }
    } catch (error) {
      _loadError = error is WalletException
          ? error.message
          : error is ScholarshipCatalogException
              ? error.message
              : 'Could not load scholarship programs. Please try again.';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _selectProgram(ScholarshipCatalogItem? program) async {
    if (program == null) return;
    setState(() {
      _selectedProgram = program;
      _roster = [];
      _selectedScholarIds.clear();
      _rosterLoading = true;
      _rosterError = null;
    });
    if (_batchTitle.text.trim().isEmpty ||
        _batchTitle.text.startsWith('Scholarship payout')) {
      _batchTitle.text = '${program.name} • ${DateTime.now().year}';
    }
    try {
      final roster =
          await context.read<AppState>().wallet.listProgramRoster(program.name);
      if (!mounted || _selectedProgram?.name != program.name) return;
      setState(() {
        _roster = roster;
        _selectedScholarIds.addAll(roster.map((scholar) => scholar.id));
      });
    } catch (error) {
      if (mounted) {
        final message = error is WalletException
            ? error.message
            : 'Could not load this program roster.';
        setState(() => _rosterError = message);
        showAppSnackBar(
          context,
          message,
          type: AppSnackBarType.error,
        );
      }
    } finally {
      if (mounted && _selectedProgram?.name == program.name) {
        setState(() => _rosterLoading = false);
      }
    }
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
    final program = _selectedProgram;
    final allowance = program?.allowanceAmount;
    final selected = _roster
        .where((scholar) => _selectedScholarIds.contains(scholar.id))
        .toList(growable: false);
    if (selected.isEmpty) {
      showMsg(context, 'Select at least one scholar.', error: true);
      return;
    }
    if (program == null || allowance == null || allowance <= 0) {
      showMsg(context, 'Set an allowance for this program first.', error: true);
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
      final total = selectedCount * allowance;
      final scholarWord = selectedCount == 1 ? 'scholar' : 'scholars';
      final confirmationMessage =
          'Disburse PHP ${fmtPhp(total)} to $selectedCount $scholarWord?';
      final confirmed = await _confirmDisbursement(
        selectedCount: selectedCount,
        total: total,
        amountPerScholar: allowance,
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
      final result = await state.wallet.issueProgramPayout(
        program: program.name,
        title: _batchTitle.text.trim(),
        recipients: selected.map((scholar) => scholar.id).toList(),
        distributionDate: distributionDate,
      );
      DemoAllowanceRepository.instance.setAcademicPeriod(
        _batchTitle.text.trim(),
        _academicPeriod.text,
      );
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProgramPayoutQrScreen(
            batchId: result.batchId,
            programName: result.program,
            title: result.title,
            amountPerScholar: result.amountPerScholar,
            recipientNames: result.recipients
                .map((recipient) => recipient.scholarName)
                .toList(),
            eventToken: result.eventToken,
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        showMsg(
          context,
          error is WalletException
              ? error.message
              : 'Could not issue this payout. Please try again.',
          error: true,
        );
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

  Widget _fundingAccountCard(FundingAccount account) {
    final colors = context.colors;
    return AppCard(
      radius: 22,
      shadow: true,
      padding: const EdgeInsets.all(16),
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
    required ScholarshipProgramBudget? budget,
    required bool overBudget,
  }) {
    final colors = context.colors;
    final enoughFunds = summary.available >= total;
    final finalLabel =
        enoughFunds ? 'Remaining fund after payout' : 'Shortfall';
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
                'Bank available fund',
                'PHP ${fmtPhp(summary.available)}',
              ),
              Divider(height: 1, thickness: 1, color: colors.borderSoft),
              _fundCheckRow(
                'This payout',
                '$selectedCount x PHP ${fmtPhp(amountPerScholar)} = '
                    'PHP ${fmtPhp(total)}',
              ),
              if (budget?.programBudget != null) ...[
                Divider(height: 1, thickness: 1, color: colors.borderSoft),
                _fundCheckRow(
                  'Remaining in program budget',
                  'PHP ${fmtPhp(budget!.budgetRemaining ?? 0)}',
                  valueColor: overBudget ? colors.dangerText : null,
                ),
              ],
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
        if (overBudget || !enoughFunds)
          InfoBanner(
            icon: AppIcons.warning,
            message: overBudget
                ? "This payout is over the program's remaining budget."
                : 'Not enough bank funds are available for this payout.',
            backgroundColor: colors.dangerBg,
            iconColor: colors.dangerText,
            textColor: colors.dangerText,
            borderRadius: 18,
            padding: const EdgeInsets.all(14),
          )
        else
          _fundStatusBanner(enoughFunds: true, shortfall: 0),
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
  }) =>
      IssuePayoutFundStatusBanner(
        enoughFunds: enoughFunds,
        shortfall: shortfall,
      );

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
    final selectedCount = _selectedScholarIds.length;
    final amountPerScholar = _selectedProgram?.allowanceAmount ?? 0;
    final total = selectedCount * amountPerScholar;
    final colors = context.colors;
    final fundingAccountMissing =
        _fundingAccountLoaded && _fundingAccount == null;
    final budget = _selectedProgram == null
        ? null
        : _programBudgets[_selectedProgram!.name];
    final budgetRemaining = budget?.budgetRemaining;
    final overBudget = budget?.programBudget != null &&
        budgetRemaining != null &&
        total > budgetRemaining;
    final insufficientFunds =
        _fundSummary != null && total > _fundSummary!.available;
    final canIssue = !_generating &&
        _selectedProgram != null &&
        amountPerScholar > 0 &&
        _roster.isNotEmpty &&
        selectedCount > 0 &&
        !_rosterLoading &&
        _fundingAccount != null &&
        !_fundingAccountLoadFailed &&
        _fundSummary != null &&
        !overBudget &&
        !insufficientFunds;

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
                if (_loadError != null) ...[
                  ErrorCard(
                    message: _loadError!,
                    onRetry: _load,
                    prominent: true,
                  ),
                  const SizedBox(height: 14),
                ],
                _programPicker(),
                if (_selectedProgram != null) ...[
                  const SizedBox(height: 14),
                  _programAllowanceCard(_selectedProgram!, budget),
                ],
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
                      amountPerScholar: amountPerScholar,
                      total: total,
                      summary: _fundSummary!,
                      budget: budget,
                      overBudget: overBudget,
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
                  'This date is saved with the payout event. Its event QR '
                  'can be scanned immediately.',
                  style: TextStyle(
                    color: colors.textBody,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 24),
                SectionLabel(
                  'PROGRAM ROSTER',
                  labelColor: colors.textBody,
                  fontSize: 11.5,
                  letterSpacing: 1.2,
                  trailing: TextButton(
                    onPressed: _roster.isEmpty
                        ? null
                        : () => setState(() {
                              if (selectedCount == _roster.length) {
                                _selectedScholarIds.clear();
                              } else {
                                _selectedScholarIds
                                  ..clear()
                                  ..addAll(
                                      _roster.map((scholar) => scholar.id));
                              }
                            }),
                    style: TextButton.styleFrom(
                      foregroundColor: colors.brand,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 40),
                    ),
                    child: Text(
                      selectedCount == _roster.length && _roster.isNotEmpty
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
                if (_rosterError != null)
                  ErrorCard(
                    message: _rosterError!,
                    onRetry: () => _selectProgram(_selectedProgram),
                  )
                else
                  ProgramRosterChecklist(
                    roster: _selectedProgram == null ? const [] : _roster,
                    selectedIds: _selectedScholarIds,
                    loading: _rosterLoading,
                    hasProgram: _selectedProgram != null,
                    onToggle: (id) => setState(() {
                      if (!_selectedScholarIds.add(id)) {
                        _selectedScholarIds.remove(id);
                      }
                    }),
                  ),
                if (_unassignedScholars.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _unassignedSection(),
                ],
                const SizedBox(height: 16),
                if (insufficientFunds && _fundingAccount != null) ...[
                  const SizedBox(height: 10),
                  SecondaryButton(
                    label: 'Allocate Funds',
                    onPressed: _openFundingAccount,
                    minHeight: 52,
                    borderRadius: 18,
                  ),
                ],
                const SizedBox(height: 18),
                ProgramPayoutIssueAction(
                  canIssue: canIssue,
                  overBudget: overBudget,
                  insufficientFunds: insufficientFunds,
                  loading: _busy,
                  onPressed: _generate,
                ),
                const SizedBox(height: 12),
                Text(
                  'Issuing reserves the program allowance for each selected '
                  'scholar. Receipt is confirmed when a scholar scans the event QR.',
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

  Widget _programPicker() {
    return ProgramPayoutPicker(
      programs: _programs,
      selectedProgram: _selectedProgram,
      onChanged: _generating ? null : _selectProgram,
    );
  }

  Widget _programAllowanceCard(
    ScholarshipCatalogItem program,
    ScholarshipProgramBudget? budget,
  ) {
    final colors = context.colors;
    final allowance = program.allowanceAmount;
    return AppCard(
      radius: 22,
      shadow: true,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _fundCheckRow(
            'Allowance per scholar',
            allowance == null || allowance <= 0
                ? 'Not set'
                : 'PHP ${fmtPhp(allowance)}',
          ),
          Divider(height: 1, thickness: 1, color: colors.borderSoft),
          _fundCheckRow(
            'Program budget',
            budget?.programBudget == null
                ? 'No budget set'
                : 'PHP ${fmtPhp(budget!.programBudget!)}',
          ),
          Divider(height: 1, thickness: 1, color: colors.borderSoft),
          _fundCheckRow(
            'Used',
            'PHP ${fmtPhp(budget?.budgetUsed ?? 0)}',
          ),
          Divider(height: 1, thickness: 1, color: colors.borderSoft),
          _fundCheckRow(
            'Remaining',
            budget?.budgetRemaining == null
                ? 'No budget set'
                : 'PHP ${fmtPhp(budget!.budgetRemaining!)}',
          ),
        ],
      ),
    );
  }

  Widget _unassignedSection() {
    final colors = context.colors;
    return AppCard(
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextButton(
            onPressed: () => setState(() => _showUnassigned = !_showUnassigned),
            style: TextButton.styleFrom(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
            child: Text(
              'Scholars without a matching program · '
              '${_unassignedScholars.length}',
              style: TextStyle(
                color: colors.brand,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (_showUnassigned)
            ..._unassignedScholars.map(
              (scholar) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  scholar.fullName,
                  style: TextStyle(
                    color: colors.textBody,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
        ],
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

class ProgramPayoutPicker extends StatelessWidget {
  final List<ScholarshipCatalogItem> programs;
  final ScholarshipCatalogItem? selectedProgram;
  final ValueChanged<ScholarshipCatalogItem?>? onChanged;

  const ProgramPayoutPicker({
    super.key,
    required this.programs,
    required this.selectedProgram,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: colors.border),
    );
    return AppCard(
      radius: 22,
      shadow: true,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Scholarship program',
            style: TextStyle(
              color: colors.textLabel,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<ScholarshipCatalogItem>(
            key: const ValueKey('program-payout-picker'),
            initialValue: selectedProgram,
            isExpanded: true,
            decoration: InputDecoration(
              hintText: 'Choose a program',
              filled: true,
              fillColor: colors.surface,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              border: border,
              enabledBorder: border,
              focusedBorder: border,
            ),
            items: programs
                .map(
                  (program) => DropdownMenuItem(
                    value: program,
                    child: Text(
                      program.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class ProgramRosterChecklist extends StatelessWidget {
  final List<ProgramRosterScholar> roster;
  final Set<String> selectedIds;
  final bool loading;
  final bool hasProgram;
  final ValueChanged<String> onToggle;

  const ProgramRosterChecklist({
    super.key,
    required this.roster,
    required this.selectedIds,
    required this.loading,
    required this.hasProgram,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final selectedCount =
        roster.where((scholar) => selectedIds.contains(scholar.id)).length;
    if (loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (roster.isEmpty) {
      return EmptyState(
        icon: AppIcons.users,
        title: hasProgram
            ? 'No verified scholars in this program'
            : 'Choose a program',
        message: hasProgram
            ? 'There are no recipients available for this program.'
            : 'Select a program to load its verified roster.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '$selectedCount of ${roster.length} selected',
            key: const ValueKey('program-roster-selection-count'),
            style: TextStyle(
              color: colors.textBody,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 8),
        for (final scholar in roster)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ListRowCard(
              onTap: () => onToggle(scholar.id),
              minHeight: 68,
              padding: const EdgeInsets.all(16),
              radius: 22,
              backgroundColor: colors.surface,
              borderColor: selectedIds.contains(scholar.id)
                  ? colors.brand
                  : colors.border,
              borderWidth: selectedIds.contains(scholar.id) ? 2 : 1,
              child: Row(
                children: [
                  Icon(
                    selectedIds.contains(scholar.id)
                        ? AppIcons.check
                        : Icons.radio_button_unchecked,
                    size: 22,
                    color: selectedIds.contains(scholar.id)
                        ? colors.brand
                        : colors.border,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      scholar.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class ProgramPayoutIssueAction extends StatelessWidget {
  final bool canIssue;
  final bool overBudget;
  final bool insufficientFunds;
  final bool loading;
  final VoidCallback onPressed;

  const ProgramPayoutIssueAction({
    super.key,
    required this.canIssue,
    required this.overBudget,
    required this.insufficientFunds,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final warning = overBudget
        ? "This payout is over the program's remaining budget."
        : insufficientFunds
            ? 'Not enough bank funds are available for this payout.'
            : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (warning != null) ...[
          InfoBanner(
            icon: AppIcons.warning,
            message: warning,
            backgroundColor: colors.dangerBg,
            iconColor: colors.dangerText,
            textColor: colors.dangerText,
            borderRadius: 18,
            padding: const EdgeInsets.all(14),
          ),
          const SizedBox(height: 18),
        ],
        PrimaryButton(
          key: const ValueKey('issue-program-payout'),
          label: 'Issue payout',
          onPressed: canIssue ? onPressed : null,
          icon: AppIcons.qrCode,
          loading: loading,
          loadingLabel: 'Issuing payout',
          minHeight: 56,
          borderRadius: 18,
          shadow: true,
          iconSize: 20,
          iconSpacing: 10,
        ),
      ],
    );
  }
}

class IssuePayoutFundStatusBanner extends StatelessWidget {
  final bool enoughFunds;
  final double shortfall;

  const IssuePayoutFundStatusBanner({
    super.key,
    required this.enoughFunds,
    required this.shortfall,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final message = enoughFunds
        ? 'Enough funds for this payout.'
        : 'Not enough funds. Allocate at least PHP ${fmtPhp(shortfall)} '
            'to continue.';
    final leading = Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: enoughFunds ? colors.success : colors.dangerText,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(
        enoughFunds ? AppIcons.check : AppIcons.warning,
        color: colors.onHeader,
        size: 15,
      ),
    );
    final banner = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: enoughFunds ? colors.successBg : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        heightFactor: 1,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            leading,
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                message,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.clip,
                style: TextStyle(
                  color: enoughFunds ? colors.successText : colors.dangerText,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (enoughFunds) return banner;
    return Semantics(
      liveRegion: true,
      child: AppCard(
        radius: 14,
        padding: EdgeInsets.zero,
        backgroundColor: colors.dangerBg,
        borderColor: colors.danger.withValues(alpha: .35),
        child: banner,
      ),
    );
  }
}

/// Legacy QR display retained for existing external references.
class LegacyPayoutQrSheetScreen extends StatelessWidget {
  final List<AllowanceClaim> claims;
  final double amount;
  final DateTime distributionDate;
  const LegacyPayoutQrSheetScreen({
    super.key,
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
