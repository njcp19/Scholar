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
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Notifications',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              if (_pendingRegs.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'No registrations waiting.',
                      style: TextStyle(color: context.colors.textBody),
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: _pendingRegs
                        .map((u) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundColor: context.colors.brandTint,
                                child: Icon(
                                  AppIcons.userPlus,
                                  color: context.colors.brand,
                                  size: 20,
                                ),
                              ),
                              title: Text('${u.fullName} registered'),
                              subtitle: Text(
                                  '${u.studentNumber ?? '—'} • ${u.university ?? '—'}\nWaiting for verification'),
                              isThreeLine: true,
                              onTap: () {
                                Navigator.pop(ctx);
                                _openRegistrations();
                              },
                            ))
                        .toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
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
    final batchId = sorted.first.batchId;
    return _claims.where((claim) => claim.batchId == batchId).toList()
      ..sort((a, b) => a.id.compareTo(b.id));
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

  Widget _allowanceHero(BuildContext context, double amount) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [context.colors.header, context.colors.heroGradientEnd],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -66,
              right: 12,
              child: _heroCircle(
                context.colors.avatarBackground.withValues(alpha: .18),
                164,
              ),
            ),
            Positioned(
              bottom: -96,
              right: -68,
              child: _heroCircle(
                context.colors.onHeader.withValues(alpha: .12),
                224,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'STANDARD ALLOWANCE',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.colors.onHeader.withValues(alpha: .9),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Material(
                      color: context.colors.onHeader.withValues(alpha: .18),
                      borderRadius: BorderRadius.circular(22),
                      child: InkWell(
                        onTap: _setAllowance,
                        borderRadius: BorderRadius.circular(22),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(AppIcons.edit,
                                  color: context.colors.onHeader, size: 17),
                              const SizedBox(width: 6),
                              Text(
                                'Edit',
                                style: TextStyle(
                                  color: context.colors.onHeader,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'PHP ${fmtPhp(amount)}',
                      maxLines: 1,
                      style: TextStyle(
                        color: context.colors.onHeader,
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Same amount for every scholar',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.colors.onHeader.withValues(alpha: .84),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroCircle(Color color, double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );

  Widget _statisticsCard(BuildContext context) {
    return AppCard(
      radius: 22,
      shadow: true,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _statColumn(
                context,
                icon: AppIcons.users,
                tileColor: context.colors.goldTint,
                iconColor: context.colors.accentGold,
                value: '$_scholars',
                label: 'Active scholars',
                onTap: _openManageScholars,
              ),
            ),
            _statDivider(context),
            Expanded(
              child: _statColumn(
                context,
                icon: AppIcons.clock,
                tileColor: context.colors.warningBg,
                iconColor: context.colors.warning,
                value: '$_waiting',
                label: 'Waiting for scan',
                detail: 'Reserved PHP ${fmtPhp(_reserved)}',
                onTap: _openPayoutMonitor,
              ),
            ),
            _statDivider(context),
            Expanded(
              child: _statColumn(
                context,
                icon: AppIcons.checkCircle,
                tileColor: context.colors.successBg,
                iconColor: context.colors.success,
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

  Widget _statDivider(BuildContext context) =>
      Container(width: 1, color: context.colors.borderSoft);

  Widget _statColumn(
    BuildContext context, {
    required IconData icon,
    required Color tileColor,
    required Color iconColor,
    required String value,
    required String label,
    required VoidCallback onTap,
    String? detail,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: tileColor,
                  borderRadius: BorderRadius.circular(13),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: iconColor, size: 23),
              ),
              const SizedBox(height: 8),
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
    final pending = _pendingRegs.isNotEmpty;
    return ListRowCard(
      minHeight: 88,
      padding: const EdgeInsets.all(14),
      radius: 20,
      shadow: true,
      backgroundColor:
          pending ? context.colors.warningBg : context.colors.surface,
      borderColor: pending
          ? context.colors.warning.withValues(alpha: .38)
          : context.colors.borderSoft,
      onTap: pending ? _openRegistrations : null,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: pending
                  ? context.colors.warning.withValues(alpha: .22)
                  : context.colors.successBg,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(
              pending ? AppIcons.userCheck : AppIcons.checkCircle,
              color:
                  pending ? context.colors.textPrimary : context.colors.success,
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
                  pending
                      ? 'Registrations to verify'
                      : 'No registrations waiting',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                if (pending) ...[
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
              ],
            ),
          ),
          if (pending) ...[
            const SizedBox(width: 8),
            Icon(AppIcons.chevronRight, color: context.colors.textPrimary),
          ],
        ],
      ),
    );
  }

  Widget _disbursementAction(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final background = dark ? context.colors.header : context.colors.brand;
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: _openDisbursement,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          constraints: const BoxConstraints(minHeight: 66),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: context.colors.cardShadow,
                blurRadius: 16,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: context.colors.onHeader.withValues(alpha: .2),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(AppIcons.send,
                    color: context.colors.onHeader, size: 23),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Disburse Allowance',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.colors.onHeader,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Release the allowance by QR',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.colors.onHeader.withValues(alpha: .88),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(AppIcons.chevronRight, color: context.colors.onHeader),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickActionsCard(BuildContext context) {
    return AppCard(
      radius: 21,
      shadow: true,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: Column(
          children: [
            _quickActionRow(
              context,
              icon: AppIcons.calendar,
              tileColor: context.colors.brandTint,
              iconColor: context.colors.brand,
              title: 'Payout Events',
              subtitle: 'Allowance batches',
              onTap: _openPayoutEvents,
            ),
            Divider(height: 1, indent: 66, color: context.colors.borderSoft),
            _quickActionRow(
              context,
              icon: AppIcons.chart,
              tileColor: context.colors.successBg,
              iconColor: context.colors.success,
              title: 'Disbursement Reports',
              subtitle: 'Totals, history and exports',
              onTap: _openReports,
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickActionRow(
    BuildContext context, {
    required IconData icon,
    required Color tileColor,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: tileColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: iconColor, size: 23),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
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
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: context.colors.textBody, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(AppIcons.chevronRight,
                  color: context.colors.textBody, size: 22),
            ],
          ),
        ),
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
              'Disburse Allowance to create one.',
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
      statusColor = context.colors.textBody;
      statusBackground = context.colors.borderSoft;
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
                  status,
                  color: statusColor!,
                  bg: statusBackground,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'PHP ${fmtPhp(first.amount)} per scholar - ${batchClaims.length} recipient(s)',
            maxLines: 2,
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
          Text(
            '$received of ${batchClaims.length} received',
            style: TextStyle(color: context.colors.textBody, fontSize: 12),
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
            width: 40,
            height: 40,
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
                          child: _allowanceHero(
                            context,
                            state.allowance.allowanceAmount,
                          ),
                        ),
                        if (_loadError != null) ...[
                          const SizedBox(height: 16),
                          ErrorCard(message: _loadError!, onRetry: _load),
                        ],
                        const SizedBox(height: 16),
                        AppSkeletonizer(
                          enabled: !_hasLoaded,
                          child: _statisticsCard(context),
                        ),
                        const SizedBox(height: 16),
                        AppSkeletonizer(
                          enabled: !_hasLoaded,
                          child: _registrationsCard(context),
                        ),
                        const SizedBox(height: 26),
                        SectionLabel(
                          'QUICK ACTIONS',
                          labelColor: context.colors.textBody,
                        ),
                        const SizedBox(height: 10),
                        AppSkeletonizer(
                          enabled: !_hasLoaded,
                          child: _disbursementAction(context),
                        ),
                        const SizedBox(height: 12),
                        AppSkeletonizer(
                          enabled: !_hasLoaded,
                          child: _quickActionsCard(context),
                        ),
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
                        SectionLabel(
                          'RECENT PAYOUTS',
                          labelColor: context.colors.textBody,
                          trailing: TextButton(
                            onPressed: _openPayoutMonitor,
                            style: TextButton.styleFrom(
                              minimumSize: const Size(48, 32),
                              padding: EdgeInsets.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('View all'),
                          ),
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
