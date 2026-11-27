import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_state.dart';
import '../../services/scholarship_catalog_service.dart';
import '../../widgets/widgets.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/shell_tab_controller.dart';
import 'issue_payout_screen.dart';
import 'claims_monitor_screen.dart';
import 'manage_scholars_screen.dart';
import 'reports_screen.dart';
import 'activity_log_screen.dart';
import 'funding_account_screen.dart';
import 'registration_review_screen.dart';
import 'scholarship_programs_screen.dart';
import '../../services/verification_service.dart';
import '../../models/models.dart';
import '../payout_events_screen.dart';
import '../settings_screen.dart';

/// Admin home for program-based payouts and scholarship management.
class AdminDashboardScreen extends StatefulWidget {
  final ScholarshipCatalogService? catalogService;

  const AdminDashboardScreen({super.key, this.catalogService});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late final ScholarshipCatalogService _catalogService =
      widget.catalogService ?? ScholarshipCatalogService();
  final ShellTabController _tabs = ShellTabController();
  int _scholars = 0;
  int _waiting = 0;
  int _received = 0;
  double _reserved = 0;
  List<AllowanceClaim> _claims = [];
  Timer? _poll;
  Set<String>? _seenReceived;
  final _verification = VerificationService();
  List<AppUser> _pendingRegs = [];
  Set<String>? _seenRegs;
  bool _announced = false;
  bool _hasLoaded = false;
  String? _loadError;
  bool _offline = false;
  List<ScholarshipCatalogItem> _activePrograms = [];
  Map<String, ScholarshipProgramBudget> _programBudgets = {};
  bool _programSummaryLoading = true;
  String? _programSummaryError;

  @override
  void initState() {
    super.initState();
    _tabs.addListener(_onTabChanged);
    _load();
    _poll =
        Timer.periodic(const Duration(seconds: 15), (_) => _checkReceived());
  }

  void _onTabChanged() {
    if (_tabs.selectedIndex == 0) _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _tabs
      ..removeListener(_onTabChanged)
      ..dispose();
    super.dispose();
  }

  Future<void> _loadRegistrations({bool announce = false}) async {
    try {
      final all = await _verification.registrations();
      final pending = all
          .where((u) => u.verificationStatus == VerificationStatus.pending)
          .toList();
      final ids = pending.map((u) => u.id).toSet();
      final seen = _seenRegs;
      _seenRegs = ids;
      if (mounted) setState(() => _pendingRegs = pending);
      if (!mounted) return;
      if (seen == null) {
        // First load: remind the admin once if registrations are waiting.
        if (announce && !_announced && pending.isNotEmpty) {
          _announced = true;
          _notifyRegs(
              '${pending.length} registration(s) waiting for verification.');
        }
      } else {
        for (final u in pending.where((u) => !seen.contains(u.id))) {
          _notifyRegs('New registration: ${u.fullName}'
              '${(u.studentNumber ?? '').isNotEmpty ? ' (${u.studentNumber})' : ''}.');
        }
      }
    } catch (error) {
      _loadError = error.toString();
      _offline = isOfflineLoadError(error);
      if (mounted) setState(() {});
    }
  }

  void _notifyRegs(String msg) {
    showAppSnackBar(
      context,
      msg,
      type: AppSnackBarType.info,
      action: SnackBarAction(label: 'REVIEW', onPressed: _openRegistrations),
    );
  }

  Future<void> _openRegistrations() async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => const RegistrationReviewScreen()));
    _load();
  }

  void _showNotifications() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      barrierColor: Theme.of(context).colorScheme.scrim.withValues(alpha: .64),
      builder: (sheetContext) {
        final colors = context.colors;
        final cardBackground = Theme.of(context).brightness == Brightness.dark
            ? colors.surface
            : colors.background;

        void openRegistrations() {
          Navigator.pop(sheetContext);
          _openRegistrations();
        }

        return AppBottomSheet(
          title: 'Notifications',
          header: Row(
            children: [
              Expanded(
                child: Text(
                  'Notifications',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Material(
                color: cardBackground,
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: 'Close notifications',
                  onPressed: () => Navigator.pop(sheetContext),
                  constraints:
                      const BoxConstraints.tightFor(width: 44, height: 44),
                  padding: EdgeInsets.zero,
                  icon: Icon(AppIcons.close, color: colors.textBody, size: 22),
                ),
              ),
            ],
          ),
          maxHeightFactor: .8,
          radius: 28,
          contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          showDragHandle: true,
          child: _pendingRegs.isEmpty
              ? AppCard(
                  radius: 22,
                  padding: const EdgeInsets.all(16),
                  backgroundColor: cardBackground,
                  borderColor: colors.borderSoft,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              color: colors.brandTint,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              AppIcons.bell,
                              color: colors.brand,
                              size: 36,
                            ),
                          ),
                          Positioned(
                            right: -2,
                            bottom: -2,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: colors.success,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: cardBackground,
                                  width: 3,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                AppIcons.check,
                                color: colors.onHeader,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Text(
                        "You're all caught up",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No registrations waiting.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.textBody,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_pendingRegs.length} '
                      '${_pendingRegs.length == 1 ? 'registration' : 'registrations'} '
                      'waiting for verification',
                      style: TextStyle(
                        color: colors.textBody,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    AppCard(
                      radius: 22,
                      padding: EdgeInsets.zero,
                      backgroundColor: cardBackground,
                      borderColor: colors.borderSoft,
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var index = 0;
                              index < _pendingRegs.length;
                              index++) ...[
                            if (index > 0)
                              Divider(
                                height: 1,
                                indent: 68,
                                endIndent: 12,
                                color: colors.borderSoft,
                              ),
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: openRegistrations,
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        radius: 22,
                                        backgroundColor: colors.brandTint,
                                        child: Text(
                                          _pendingRegs[index].initials,
                                          style: TextStyle(
                                            color: colors.brand,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${_pendingRegs[index].fullName} registered',
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: colors.textPrimary,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${_pendingRegs[index].studentNumber ?? '—'} · '
                                              '${_pendingRegs[index].university ?? '—'}',
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: colors.textBody,
                                                fontSize: 12,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            StatusChip(
                                              'Waiting for verification',
                                              color: colors.warningText,
                                              bg: colors.warningBg,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Padding(
                                        padding: const EdgeInsets.only(top: 10),
                                        child: Icon(
                                          AppIcons.chevronRight,
                                          color: colors.textBody,
                                          size: 20,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SecondaryButton(
                      label: 'Open Registration Verification',
                      onPressed: openRegistrations,
                      minHeight: 52,
                      borderRadius: 18,
                    ),
                  ],
                ),
        );
      },
    );
  }

  /// In-app notification: tell the admin when a scholar scans + confirms.
  Future<void> _checkReceived() async {
    await _loadRegistrations();
    if (!mounted) return;
    final wallet = context.read<AppState>().wallet;
    try {
      final claims = await wallet.getAllClaims(limit: 300);
      final received = claims.where((c) => c.isReceived).toList();
      final ids = received.map((c) => c.id).toSet();
      final seen = _seenReceived;
      _seenReceived = ids;
      if (seen != null && mounted) {
        for (final c in received.where((c) => !seen.contains(c.id))) {
          showMsg(context,
              '${c.scholarName} received PHP ${fmtPhp(c.amount)} (QR scanned + biometrics verified).');
        }
        _load();
      }
    } catch (error) {
      _loadError = error.toString();
      if (mounted) setState(() {});
    }
  }

  Future<void> _load() async {
    final state = context.read<AppState>();
    String? error;
    bool? offline;
    _loadError = null;
    try {
      _scholars = await state.wallet.getActiveScholarCount();
      final claims = await state.wallet.getAllClaims(limit: 300);
      _claims = claims;
      _waiting = claims.where((c) => c.isPending).length;
      _received = claims.where((c) => c.isReceived).length;
      _seenReceived ??=
          claims.where((c) => c.isReceived).map((c) => c.id).toSet();
      _reserved = claims
          .where((c) => c.isPending)
          .fold<double>(0, (s, c) => s + c.amount);
    } catch (e) {
      error = e.toString();
      offline = isOfflineLoadError(e);
    }
    await _loadProgramSummary();
    await _loadRegistrations(announce: true);
    if (mounted) {
      setState(() {
        _loadError = error ?? _loadError;
        if (error != null) {
          _offline = offline ?? false;
        } else if (_loadError == null) {
          _offline = false;
        }
        _hasLoaded = true;
      });
    }
  }

  Future<void> _loadProgramSummary() async {
    _programSummaryLoading = true;
    try {
      final results = await Future.wait<dynamic>([
        _catalogService.list(includeInactive: false),
        _catalogService.getProgramBudgets(),
      ]);
      if (!mounted) return;
      _activePrograms = (results[0] as List<ScholarshipCatalogItem>)
          .where((program) => program.isActive)
          .toList(growable: false);
      _programBudgets = {
        for (final budget in results[1] as List<ScholarshipProgramBudget>)
          budget.programName: budget,
      };
      _programSummaryError = null;
    } catch (error) {
      _programSummaryError = error is ScholarshipCatalogException
          ? error.message
          : 'Could not load scholarship program budgets. Please try again.';
    } finally {
      _programSummaryLoading = false;
    }
  }

  Future<void> _openScholarshipPrograms() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ScholarshipProgramsScreen(catalogService: _catalogService),
      ),
    );
    _load();
  }

  void _openManageScholars() => _tabs.select(2);

  void _openPayoutMonitor() => _tabs.select(1);

  Future<void> _openPayoutEvents() async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => const PayoutEventsScreen()));
    _load();
  }

  Future<void> _openReports() async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => const ReportsScreen()));
    _load();
  }

  Future<void> _openActivityLog() async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => const ActivityLogScreen()));
    _load();
  }

  Future<void> _openFundingAccount() async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => const FundingAccountScreen()));
    _load();
  }

  Future<void> _openDisbursement() async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => const IssuePayoutScreen()));
    _load();
  }

  List<AllowanceClaim> get _latestBatchClaims {
    if (_claims.isEmpty) return const [];
    final sorted = [..._claims]..sort((a, b) =>
        (b.issuedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.issuedAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
    final latest = sorted.first;
    final batchClaims = latest.batchId.isNotEmpty
        ? _claims.where((claim) => claim.batchId == latest.batchId)
        : _claims.where((claim) => claim.batchTitle == latest.batchTitle);
    return batchClaims.toList()..sort((a, b) => a.id.compareTo(b.id));
  }

  List<AllowanceClaim> get _recentReceived {
    final received = _claims.where((claim) => claim.isReceived).toList()
      ..sort((a, b) => (b.claimedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(a.claimedAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
    return received.take(3).toList();
  }

  String _friendlyDate(DateTime? date) => date == null
      ? 'Date unavailable'
      : DateFormat('MMM d, yyyy • h:mm a').format(date.toLocal());

  Widget _disbursementHero(BuildContext context) {
    final colors = context.colors;
    return AppCard(
      padding: EdgeInsets.zero,
      radius: 28,
      shadow: true,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [colors.header, colors.heroGradientEnd],
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DISBURSE ALLOWANCE',
              style: TextStyle(
                color: colors.onHeader.withValues(alpha: .9),
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Generate a payout batch and scholars scan their QR to receive it.',
              style: TextStyle(
                color: colors.onHeader.withValues(alpha: .88),
                fontSize: 12,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: PrimaryButton(
                label: 'Start disbursement',
                onPressed: _openDisbursement,
                icon: AppIcons.send,
                backgroundColor: colors.onHeader,
                foregroundColor: colors.brand,
                minHeight: 52,
                borderRadius: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _programsCard(BuildContext context) {
    final colors = context.colors;
    final programs = [..._activePrograms]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final budgetedPrograms = programs
        .map((program) => _programBudgets[program.name])
        .whereType<ScholarshipProgramBudget>()
        .where((budget) => budget.programBudget != null)
        .toList(growable: false);
    final totalBudget = budgetedPrograms.fold<double>(
      0,
      (total, budget) => total + budget.programBudget!,
    );
    final totalUsed = budgetedPrograms.fold<double>(
      0,
      (total, budget) => total + budget.budgetUsed,
    );
    final totalRemaining = budgetedPrograms.fold<double>(
      0,
      (total, budget) => total + (budget.budgetRemaining ?? 0),
    );

    return AppCard(
      key: const ValueKey('admin-program-summary-card'),
      radius: 22,
      shadow: true,
      padding: const EdgeInsets.all(16),
      onTap: _openScholarshipPrograms,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.brandTint,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(
                  AppIcons.wallet,
                  color: colors.brand,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Scholarship programs',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${_activePrograms.length} active '
                      '${_activePrograms.length == 1 ? 'program' : 'programs'}',
                      style: TextStyle(
                        color: colors.textBody,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                AppIcons.chevronRight,
                color: colors.textBody,
              ),
            ],
          ),
          if (_programSummaryError != null) ...[
            const SizedBox(height: 12),
            Text(
              _programSummaryError!,
              style: TextStyle(color: colors.dangerText, fontSize: 12),
            ),
          ] else if (_programSummaryLoading) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ] else ...[
            const SizedBox(height: 14),
            if (budgetedPrograms.isEmpty)
              Text(
                'No budgets set yet',
                style: TextStyle(color: colors.textBody, fontSize: 12),
              )
            else ...[
              Row(
                children: [
                  _programSummaryMetric(
                    context,
                    label: 'Total budget',
                    value: 'PHP ${fmtPhp(totalBudget)}',
                  ),
                  _programSummaryMetric(
                    context,
                    label: 'Used',
                    value: 'PHP ${fmtPhp(totalUsed)}',
                  ),
                  _programSummaryMetric(
                    context,
                    label: 'Remaining',
                    value: 'PHP ${fmtPhp(totalRemaining)}',
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Programs without a budget are not included',
                style: TextStyle(color: colors.textBody, fontSize: 10),
              ),
            ],
            if (programs.isNotEmpty) ...[
              const SizedBox(height: 12),
              Divider(height: 1, color: colors.borderSoft),
              for (final (index, program) in programs.take(3).indexed) ...[
                if (index > 0) Divider(height: 1, color: colors.borderSoft),
                _programRow(context, program),
              ],
            ],
            if (programs.length > 3) ...[
              const SizedBox(height: 6),
              Center(
                child: Text(
                  'View all ${programs.length} programs',
                  style: TextStyle(
                    color: colors.brand,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _programRow(
    BuildContext context,
    ScholarshipCatalogItem program,
  ) {
    final colors = context.colors;
    final budget = _programBudgets[program.name];
    final amount = budget?.programBudget;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  program.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  softWrap: true,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (program.slots != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    '${program.slotsTaken} of ${program.slots} slots',
                    style: TextStyle(
                      color: colors.textBody,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 112,
            child: amount == null
                ? Align(
                    alignment: Alignment.centerRight,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.borderSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        child: Text(
                          'No budget',
                          style: TextStyle(
                            color: colors.textBody,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  )
                : _programBudgetStatus(context, budget!),
          ),
        ],
      ),
    );
  }

  Widget _programBudgetStatus(
    BuildContext context,
    ScholarshipProgramBudget budget,
  ) {
    final colors = context.colors;
    final amount = budget.programBudget!;
    final usedRatio = amount > 0
        ? budget.budgetUsed / amount
        : budget.budgetUsed > 0
            ? 1.0
            : 0.0;
    final progress = usedRatio.clamp(0.0, 1.0).toDouble();
    final progressColor = usedRatio > 0.8 ? colors.warning : colors.brand;
    final remaining = budget.budgetRemaining;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Text(
            'PHP ${remaining == null ? '—' : fmtPhp(remaining)} left',
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            key: ValueKey('admin-program-progress-${budget.programName}'),
            value: progress,
            minHeight: 4,
            backgroundColor: colors.borderSoft,
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
          ),
        ),
      ],
    );
  }

  Widget _programSummaryMetric(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: context.colors.textBody,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statDivider(BuildContext context) =>
      Container(width: 1, color: context.colors.borderSoft);

  Widget _statsCard(BuildContext context) {
    return AppCard(
      key: const ValueKey('admin-home-stats-card'),
      radius: 22,
      shadow: true,
      padding: const EdgeInsets.all(16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _statColumn(
                context,
                value: '$_scholars',
                label: 'Active scholars',
                onTap: _openManageScholars,
              ),
            ),
            _statDivider(context),
            Expanded(
              child: _statColumn(
                context,
                value: '$_waiting',
                label: 'Waiting for scan',
                detail: 'PHP ${fmtPhp(_reserved)} reserved',
                onTap: _openPayoutMonitor,
              ),
            ),
            _statDivider(context),
            Expanded(
              child: _statColumn(
                context,
                value: '$_received',
                label: 'Received',
                onTap: _openPayoutMonitor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statColumn(
    BuildContext context, {
    required String value,
    required String label,
    required VoidCallback onTap,
    String? detail,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              StatNumberText(
                value: value,
                color: context.colors.textPrimary,
                alignment: Alignment.center,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.colors.textBody, fontSize: 12),
              ),
              if (detail != null) ...[
                const SizedBox(height: 2),
                Text(
                  detail,
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(color: context.colors.textBody, fontSize: 10),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _registrationsCard(BuildContext context) {
    return ListRowCard(
      minHeight: 88,
      padding: const EdgeInsets.all(16),
      radius: 22,
      shadow: true,
      backgroundColor: context.colors.warningBg,
      borderColor: context.colors.warningBorder,
      onTap: _openRegistrations,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: context.colors.warning.withValues(alpha: .2),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(
              AppIcons.userCheck,
              color: context.colors.warningText,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Registrations to verify',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_pendingRegs.length} scholars are waiting for review',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.colors.textBody,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(AppIcons.chevronRight, color: context.colors.textPrimary),
        ],
      ),
    );
  }

  Widget _quickActionTiles(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: _quickActionTile(
                    context,
                    icon: AppIcons.calendar,
                    tileColor: context.colors.brandTint,
                    iconColor: context.colors.brand,
                    title: 'Payout Events',
                    subtitle: 'Allowance batches',
                    onTap: _openPayoutEvents,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _quickActionTile(
                    context,
                    icon: AppIcons.clock,
                    tileColor: context.colors.brandTint,
                    iconColor: context.colors.brand,
                    title: 'Activity Log',
                    subtitle: 'Read-only payout records',
                    onTap: _openActivityLog,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: _quickActionTile(
                    context,
                    icon: AppIcons.chart,
                    tileColor: context.colors.successBg,
                    iconColor: context.colors.successText,
                    title: 'Reports',
                    subtitle: 'Totals, history, exports',
                    onTap: _openReports,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _quickActionTile(
                    context,
                    icon: AppIcons.bankAccount,
                    tileColor: context.colors.warningBg,
                    iconColor: context.colors.warningText,
                    title: 'Funding account',
                    subtitle: 'Available fund and activity',
                    onTap: _openFundingAccount,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickActionTile(
    BuildContext context, {
    required IconData icon,
    required Color tileColor,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      radius: 22,
      backgroundColor: context.colors.surface,
      borderColor: context.colors.borderSoft,
      borderWidth: 1,
      shadow: false,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: tileColor,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.colors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 14.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.colors.textBody,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _latestPayoutEventCard(BuildContext context) {
    final batchClaims = _latestBatchClaims;
    if (batchClaims.isEmpty) {
      return AppCard(
        radius: 22,
        shadow: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No Payout Event yet',
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Start a disbursement to create one.',
              style: TextStyle(color: context.colors.textBody, fontSize: 13),
            ),
          ],
        ),
      );
    }

    final received = batchClaims.where((claim) => claim.isReceived).length;
    final waiting = batchClaims.where((claim) => claim.isPending).length;
    final cancelled = batchClaims.where((claim) => claim.isVoided).length;
    String? status;
    Color? statusColor;
    Color? statusBackground;
    if (received == batchClaims.length) {
      status = 'Completed';
      statusColor = context.colors.success;
      statusBackground = context.colors.successBg;
    } else if (waiting > 0) {
      status = 'In progress';
      statusColor = context.colors.warning;
      statusBackground = context.colors.warningBg;
    } else if (cancelled == batchClaims.length) {
      status = 'Cancelled';
      statusColor = context.colors.danger;
      statusBackground = context.colors.dangerBg;
    }

    final first = batchClaims.first;
    return AppCard(
      radius: 22,
      shadow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  first.batchTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (status != null) ...[
                const SizedBox(width: 8),
                StatusChip(
                  status.toUpperCase(),
                  color: statusColor!,
                  bg: statusBackground,
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'PHP ${fmtPhp(first.amount)} per scholar · ${batchClaims.length} '
            '${batchClaims.length == 1 ? 'recipient' : 'recipients'}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: context.colors.textBody, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: received / batchClaims.length,
              minHeight: 8,
              backgroundColor: context.colors.borderSoft,
              valueColor: AlwaysStoppedAnimation<Color>(context.colors.success),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  '$received of ${batchClaims.length} received',
                  style: TextStyle(
                    color: context.colors.textBody,
                    fontSize: 12,
                  ),
                ),
              ),
              Text(
                '${(received / batchClaims.length * 100).round()}%',
                style: TextStyle(
                  color: context.colors.success,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _recentPayoutsCard(BuildContext context) {
    final payouts = _recentReceived;
    if (payouts.isEmpty) {
      return AppCard(
        radius: 22,
        shadow: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: context.colors.brandTint,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(AppIcons.receipt,
                    color: context.colors.hint, size: 24),
              ),
              const SizedBox(height: 10),
              Text(
                'No received payouts yet',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.colors.textBody),
              ),
            ],
          ),
        ),
      );
    }
    return AppCard(
      radius: 22,
      shadow: true,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          for (var index = 0; index < payouts.length; index++) ...[
            if (index > 0) Divider(height: 1, color: context.colors.borderSoft),
            _recentPayoutRow(context, payouts[index]),
          ],
        ],
      ),
    );
  }

  Widget _recentPayoutRow(BuildContext context, AllowanceClaim claim) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: context.colors.successBg,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child:
                Icon(AppIcons.check, color: context.colors.success, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  claim.scholarName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _friendlyDate(claim.claimedAt),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      TextStyle(color: context.colors.textBody, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  'PHP ${fmtPhp(claim.amount)}',
                  maxLines: 1,
                  softWrap: false,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: context.colors.success,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeTab(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      backgroundColor: context.colors.background,
      body: AppInitialLoadView(
        firstLoadPending: !_hasLoaded,
        skeleton: const HomeLoadingSkeleton(),
        child: Column(
          children: [
            AppHeader(
              name: state.user?.fullName ?? 'Admin',
              initials: state.user?.initials ?? 'A',
              subtitle: 'Administrator',
              notificationCount: _pendingRegs.length,
              onNotifications: _showNotifications,
              showLogout: false,
              softBackground: true,
              scaleHeightForText: true,
              avatarSize: 52,
              avatarRingColor: context.colors.accentGold,
              avatarRingWidth: 2,
              nameFontSize: 20,
              subtitleFontSize: 12,
              roundActionButtons: true,
              actionButtonSize: 44,
              dayNightIcons: true,
            ),
            Expanded(
              child: ClipRect(
                child: ScrollConfiguration(
                  behavior: const _AdminNoStretchScrollBehavior(),
                  child: RefreshIndicator(
                    onRefresh: _load,
                    child: ContentWidth(
                      child: ListView(
                        physics: const ClampingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                        children: [
                          _disbursementHero(context),
                          if (_loadError != null) ...[
                            const SizedBox(height: 16),
                            ErrorCard(
                              message: _offline
                                  ? 'Check your connection and try again. Your balance and payouts are not changed.'
                                  : _loadError!,
                              onRetry: _load,
                              prominent: true,
                              offline: _offline,
                            ),
                          ],
                          const SizedBox(height: 16),
                          _quickActionTiles(context),
                          const SizedBox(height: 16),
                          _programsCard(context),
                          const SizedBox(height: 12),
                          _statsCard(context),
                          if (_pendingRegs.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _registrationsCard(context),
                          ],
                          const SizedBox(height: 26),
                          SectionLabel(
                            'LATEST PAYOUT EVENT',
                            labelColor: context.colors.textBody,
                          ),
                          const SizedBox(height: 10),
                          _latestPayoutEventCard(context),
                          const SizedBox(height: 26),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Recent payouts',
                                  style: TextStyle(
                                    color: context.colors.textPrimary,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: _openPayoutMonitor,
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(48, 32),
                                  padding: EdgeInsets.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  'View all',
                                  style: TextStyle(
                                    color: context.colors.brand,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _recentPayoutsCard(context),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ShellTabController>.value(
      value: _tabs,
      child: Consumer<ShellTabController>(
        builder: (context, tabs, _) => PopScope<Object?>(
          canPop: tabs.selectedIndex == 0,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && tabs.selectedIndex != 0) tabs.select(0);
          },
          child: Scaffold(
            backgroundColor: context.colors.background,
            body: IndexedStack(
              index: tabs.selectedIndex,
              children: [
                _buildHomeTab(context),
                const ClaimsMonitorScreen(embedded: true),
                const ManageScholarsScreen(embedded: true),
                const SettingsScreen(embedded: true),
              ],
            ),
            bottomNavigationBar: ScholarBottomNavigation(
              currentIndex: tabs.selectedIndex,
              height: 76,
              selectedIconPill: true,
              items: const [
                HomeNavigationItem(
                  label: 'Home',
                  icon: AppIcons.homeOutline,
                  activeIcon: AppIcons.home,
                ),
                HomeNavigationItem(label: 'Payouts', icon: AppIcons.payouts),
                HomeNavigationItem(label: 'Scholars', icon: AppIcons.users),
                HomeNavigationItem(label: 'Profile', icon: AppIcons.user),
              ],
              onTap: tabs.select,
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminNoStretchScrollBehavior extends MaterialScrollBehavior {
  const _AdminNoStretchScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) =>
      child;
}
