import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/demo_allowance_repository.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icons.dart';
import '../widgets/widgets.dart';
import 'scan_claim_screen.dart';

/// Scholar: every allowance payout issued to them — waiting to be received,
/// received, or cancelled. Tapping a waiting payout opens the scanner.
class ClaimsScreen extends StatefulWidget {
  const ClaimsScreen({super.key});

  @override
  State<ClaimsScreen> createState() => _ClaimsScreenState();
}

class _ClaimsNoStretchScrollBehavior extends MaterialScrollBehavior {
  const _ClaimsNoStretchScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) =>
      child;
}

class _ClaimsScreenState extends State<ClaimsScreen> {
  List<AllowanceClaim> _claims = [];
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final state = context.read<AppState>();
      final claims = await state.wallet.getMyClaims(state.user!.id);
      if (!mounted) return;
      setState(() {
        _claims = claims;
        _loadError = null;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _claims = [];
        _loadError =
            'Could not load payouts. Check your connection and try again.';
        _loading = false;
      });
    }
  }

  Future<void> _retry() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    await _load();
  }

  Future<void> _openScanner() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ScanClaimScreen()),
    );
    if (ok == true) _load();
  }

  Widget _roundAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Material(
        color: context.colors.surface,
        shape: CircleBorder(
          side: BorderSide(color: context.colors.borderSoft),
        ),
        child: IconButton(
          onPressed: onPressed,
          tooltip: tooltip,
          constraints: const BoxConstraints.tightFor(width: 44, height: 44),
          padding: EdgeInsets.zero,
          icon: Icon(icon, color: context.colors.brand, size: 21),
        ),
      ),
    );
  }

  Widget _hero(double total, int receivedCount) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
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
              top: -118,
              right: -40,
              child: _circle(
                context.colors.onHeader.withValues(alpha: .12),
                230,
              ),
            ),
            Positioned(
              bottom: -132,
              right: -118,
              child: _circle(
                context.colors.onHeader.withValues(alpha: .1),
                250,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TOTAL RECEIVED',
                  style: TextStyle(
                    color: context.colors.onHeader.withValues(alpha: .92),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text.rich(
                      TextSpan(
                        style: TextStyle(
                          color: context.colors.onHeader,
                          fontWeight: FontWeight.w800,
                        ),
                        children: [
                          const TextSpan(
                            text: 'PHP ',
                            style: TextStyle(fontSize: 24),
                          ),
                          TextSpan(
                            text: fmtPhp(total),
                            style: const TextStyle(fontSize: 46),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ),
                ),
                if (receivedCount > 0) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: context.colors.onHeader.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      children: [
                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: context.colors.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Text(
                          '$receivedCount ${receivedCount == 1 ? 'payout' : 'payouts'} verified by QR',
                          style: TextStyle(
                            color: context.colors.onHeader,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _circle(Color color, double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );

  Widget _statCard({
    required String label,
    required int count,
    required IconData icon,
    required Color tileColor,
    required Color iconColor,
  }) {
    return AppCard(
      radius: 22,
      shadow: true,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: tileColor,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: iconColor, size: 23),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.colors.textBody,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$count',
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _skeleton() {
    return AppSkeletonizer(
      enabled: true,
      child: Column(
        children: [
          AppCard(
            radius: 26,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 130, height: 14, color: Colors.white),
                const SizedBox(height: 12),
                Container(width: 220, height: 42, color: Colors.white),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: AppCard(
                  radius: 22,
                  child: Container(height: 56, color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppCard(
                  radius: 22,
                  child: Container(height: 56, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          AppCard(
            radius: 22,
            child: Container(height: 74, color: Colors.white),
          ),
          const SizedBox(height: 12),
          AppCard(
            radius: 22,
            child: Container(height: 74, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    final expectedDate = DemoAllowanceRepository.instance.expectedReleaseDate;
    return AppCard(
      radius: 22,
      shadow: true,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: context.colors.brandTint,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              AppIcons.qrScan,
              color: context.colors.brand,
              size: 34,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No payout issued yet',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'The admin will generate a QR code when the allowance is released.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.colors.textBody,
              fontSize: 13,
            ),
          ),
          if (expectedDate != null) ...[
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                StatusChip(
                  'Expected release ${DateFormat('MMM d, yyyy').format(expectedDate)}',
                  color: context.colors.warningText,
                  bg: context.colors.warningBg,
                ),
                StatusChip(
                  'Demo data',
                  color: context.colors.textBody,
                  bg: context.colors.borderSoft,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _claimCard(AllowanceClaim claim) {
    final received = claim.isReceived;
    final cancelled = claim.isVoided;
    final pending = claim.isPending;
    final statusLabel = received
        ? 'Received'
        : cancelled
            ? 'Cancelled'
            : 'Waiting for scan';
    final statusColor = received
        ? context.colors.successText
        : cancelled
            ? context.colors.dangerText
            : context.colors.warningText;
    final statusBackground = received
        ? context.colors.successBg
        : cancelled
            ? context.colors.dangerBg
            : context.colors.warningBg;
    final icon = received
        ? AppIcons.checkCircle
        : cancelled
            ? AppIcons.cancel
            : AppIcons.clock;
    final when = received ? claim.claimedAt : claim.issuedAt;
    final academicPeriod =
        DemoAllowanceRepository.instance.academicPeriodFor(claim.batchTitle);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        radius: 22,
        shadow: true,
        borderColor:
            pending ? context.colors.accentGold : context.colors.borderSoft,
        borderWidth: pending ? 1.5 : 1,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: received
                        ? context.colors.successBg
                        : cancelled
                            ? context.colors.dangerBg
                            : context.colors.warningBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: statusColor, size: 23),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        claim.batchTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.colors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (when != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          DateFormat('MMM d, yyyy · h:mm a')
                              .format(when.toLocal()),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.colors.textBody,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 118,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            'PHP ${fmtPhp(claim.amount)}',
                            maxLines: 1,
                            style: TextStyle(
                              color: received
                                  ? context.colors.successText
                                  : cancelled
                                      ? context.colors.textBody
                                      : context.colors.textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              decoration: cancelled
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      StatusChip(
                        statusLabel,
                        color: statusColor,
                        bg: statusBackground,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (claim.distributionDate != null) ...[
              const SizedBox(height: 8),
              Text(
                'Distribution date: '
                '${DateFormat('MMM d, yyyy').format(claim.distributionDate!.toLocal())}',
                style: TextStyle(
                  color: context.colors.textBody,
                  fontSize: 12,
                ),
              ),
            ],
            if (academicPeriod != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  StatusChip(
                    academicPeriod,
                    color: context.colors.textPrimary,
                    bg: context.colors.brandTint,
                  ),
                  StatusChip(
                    'Demo data',
                    color: context.colors.textBody,
                    bg: context.colors.borderSoft,
                  ),
                ],
              ),
            ],
            if (pending) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: SecondaryButton(
                      label: 'Show my QR',
                      icon: AppIcons.qrCode,
                      minHeight: 46,
                      borderRadius: 14,
                      onPressed: () => showPayoutQrSheet(
                        context,
                        claim,
                        onScan: _openScanner,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: PrimaryButton(
                      label: 'Scan QR',
                      icon: AppIcons.qrScan,
                      minHeight: 46,
                      borderRadius: 14,
                      onPressed: _openScanner,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _claims.where((claim) => claim.isPending).length;
    final receivedClaims = _claims.where((claim) => claim.isReceived).toList();
    final totalReceived = receivedClaims.fold<double>(
      0,
      (sum, claim) => sum + claim.amount,
    );

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: context.colors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leadingWidth: 60,
        title: Text(
          'My Payouts',
          style: TextStyle(
            color: context.colors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        leading: _roundAction(
          icon: AppIcons.back,
          tooltip: 'Back',
          onPressed: () => Navigator.maybePop(context),
        ),
        actions: [
          _roundAction(
            icon: AppIcons.qrScan,
            tooltip: 'Scan QR',
            onPressed: _openScanner,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ScrollConfiguration(
          behavior: const _ClaimsNoStretchScrollBehavior(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: ClampingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              if (_loading)
                _skeleton()
              else if (_loadError != null)
                ErrorCard(
                  message: _loadError!,
                  onRetry: _retry,
                )
              else ...[
                _hero(totalReceived, receivedClaims.length),
                const SizedBox(height: 16),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _statCard(
                          label: 'Waiting for scan',
                          count: pendingCount,
                          icon: AppIcons.clock,
                          tileColor: context.colors.warningBg,
                          iconColor: context.colors.warningText,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _statCard(
                          label: 'Received',
                          count: receivedClaims.length,
                          icon: AppIcons.checkCircle,
                          tileColor: context.colors.successBg,
                          iconColor: context.colors.successText,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SectionLabel('PAYOUTS (${_claims.length})'),
                const SizedBox(height: 10),
                if (_claims.isEmpty)
                  _emptyState()
                else
                  ..._claims.map(_claimCard),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
