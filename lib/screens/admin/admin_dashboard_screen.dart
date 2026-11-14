import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_state.dart';
import '../../widgets/widgets.dart';
import '../../widgets/app_icons.dart';
import 'allowance_settings_screen.dart';
import 'issue_payout_screen.dart';
import 'claims_monitor_screen.dart';
import 'manage_scholars_screen.dart';
import 'reports_screen.dart';
import 'registration_review_screen.dart';
import '../../services/verification_service.dart';
import '../../models/models.dart';
import '../payout_events_screen.dart';
import '../settings_screen.dart';

/// Admin home. Everything the admin can do to the scholar wallet:
/// set the ONE standard allowance, issue QR payouts, monitor claims.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});
  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
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

  @override
  void initState() {
    super.initState();
    _load();
    _poll =
        Timer.periodic(const Duration(seconds: 15), (_) => _checkReceived());
  }

  @override
  void dispose() {
    _poll?.cancel();
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
      if (mounted) setState(() {});
    }
  }

  void _notifyRegs(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      action: SnackBarAction(label: 'REVIEW', onPressed: _openRegistrations),
      duration: const Duration(seconds: 8),
    ));
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
          radius: 32,
          contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          showDragHandle: true,
          child: _pendingRegs.isEmpty
              ? AppCard(
                  radius: 28,
                  padding: const EdgeInsets.all(32),
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
                      radius: 24,
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
                                            const SizedBox(height: 4),
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
      await state.loadAllowanceSettings();
    } catch (e) {
      error = e.toString();
    }
    await _loadRegistrations(announce: true);
    if (mounted) {
      setState(() {
        _loadError = error ?? _loadError;
        _hasLoaded = true;
      });
    }
  }

  Future<void> _setAllowance() async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => const AllowanceSettingsScreen()));
    _load();
  }

  Future<void> _openManageScholars() async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => const ManageScholarsScreen()));
    _load();
  }

  Future<void> _openPayoutMonitor() async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => const ClaimsMonitorScreen()));
    _load();
  }

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

  Future<void> _openProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    _load();
  }

  Widget _disbursementHero(BuildContext context) {
    final colors = context.colors;
    return AppCard(
      padding: const EdgeInsets.all(24),
      radius: 28,
      shadow: true,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [colors.header, colors.heroGradientEnd],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            top: -72,
            right: -42,
            child: _heroCircle(colors.onHeader.withValues(alpha: .1), 200),
          ),
          Positioned(
            bottom: -124,
            right: -86,
            child: _heroCircle(colors.onHeader.withValues(alpha: .08), 260),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DISBURSE ALLOWANCE',
                style: TextStyle(
                  color: colors.onHeader.withValues(alpha: .9),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Release the allowance by QR',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.onHeader,
                  fontSize: 28,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Generate a payout batch and scholars scan their QR to receive it.',
                style: TextStyle(
                  color: colors.onHeader.withValues(alpha: .88),
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 300),
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
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroCircle(Color color, double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );

  Widget _overviewCard(BuildContext context, double allowanceAmount) {
    final colors = context.colors;
    return AppCard(
      radius: 24,
      shadow: true,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Standard allowance',
                      style: TextStyle(
                        color: colors.textBody,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'PHP ${fmtPhp(allowanceAmount)}',
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Tooltip(
                message: 'Edit allowance',
                child: Material(
                  color: colors.brandTint,
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: _setAllowance,
                    customBorder: const CircleBorder(),
                    child: SizedBox(
                      width: 42,
                      height: 42,
                      child: Icon(
                        AppIcons.edit,
                        color: colors.brand,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: colors.borderSoft),
          const SizedBox(height: 12),
          IntrinsicHeight(
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
        ],
      ),
    );
  }

  Widget _statDivider(BuildContext context) =>
      Container(width: 1, color: context.colors.borderSoft);

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
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  maxLines: 1,
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.colors.textBody, fontSize: 12),
              ),
              if (detail != null) ...[
                const SizedBox(height: 2),
                Text(
                  detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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
      padding: const EdgeInsets.all(14),
      radius: 20,
      shadow: true,
      backgroundColor: context.colors.warningBg,
      borderColor: context.colors.warning.withValues(alpha: .38),
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
          const SizedBox(width: 16),
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
    return ListRowCard(
      minHeight: 160,
      padding: const EdgeInsets.all(16),
      radius: 24,
      shadow: true,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: tileColor,
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const Spacer(),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.colors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.colors.textBody,
              fontSize: 13,
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
        radius: 21,
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
      radius: 21,
      shadow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 6,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: Text(
                  first.batchTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (status != null)
                StatusChip(
                  status.toUpperCase(),
                  color: statusColor!,
                  bg: statusBackground,
                ),
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
        radius: 21,
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
      radius: 21,
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
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                'PHP ${fmtPhp(claim.amount)}',
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  color: context.colors.success,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      backgroundColor: context.colors.background,
      body: Column(
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
                        AppSkeletonizer(
                          enabled: !_hasLoaded,
                          child: _disbursementHero(context),
                        ),
                        if (_loadError != null) ...[
                          const SizedBox(height: 16),
                          ErrorCard(message: _loadError!, onRetry: _load),
                        ],
                        const SizedBox(height: 16),
                        AppSkeletonizer(
                          enabled: !_hasLoaded,
                          child: _quickActionTiles(context),
                        ),
                        const SizedBox(height: 16),
                        AppSkeletonizer(
                          enabled: !_hasLoaded,
                          child: _overviewCard(
                            context,
                            state.allowance.allowanceAmount,
                          ),
                        ),
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
                        AppSkeletonizer(
                          enabled: !_hasLoaded,
                          child: _latestPayoutEventCard(context),
                        ),
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
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
                        AppSkeletonizer(
                          enabled: !_hasLoaded,
                          child: _recentPayoutsCard(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: ScholarBottomNavigation(
        currentIndex: 0,
        height: 76,
        selectedIconPill: true,
        items: const [
          HomeNavigationItem(
              label: 'Home',
              icon: AppIcons.homeOutline,
              activeIcon: AppIcons.home),
          HomeNavigationItem(label: 'Payouts', icon: AppIcons.payouts),
          HomeNavigationItem(label: 'Scholars', icon: AppIcons.users),
          HomeNavigationItem(label: 'Profile', icon: AppIcons.user),
        ],
        onTap: (index) {
          switch (index) {
            case 1:
              _openPayoutMonitor();
            case 2:
              _openManageScholars();
            case 3:
              _openProfile();
          }
        },
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
