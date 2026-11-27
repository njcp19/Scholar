import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/demo_allowance_repository.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icons.dart';
import '../widgets/shell_tab_controller.dart';
import '../widgets/widgets.dart';
import 'payout_receipt_screen.dart';
import 'scan_claim_screen.dart';

/// Scholar: every allowance payout issued to them — waiting to be received,
/// received, or cancelled. Tapping a waiting payout opens the scanner.
class ClaimsScreen extends StatefulWidget {
  final bool embedded;

  const ClaimsScreen({super.key, this.embedded = false});

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
  bool _hasLoaded = false;
  String? _loadError;
  bool _offline = false;
  ShellTabController? _tabController;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tabController?.removeListener(_onTabChanged);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.embedded) return;
    final controller = context.read<ShellTabController>();
    if (_tabController != controller) {
      _tabController?.removeListener(_onTabChanged);
      _tabController = controller..addListener(_onTabChanged);
    }
  }

  void _onTabChanged() {
    if (_tabController?.selectedIndex == 2) _load();
  }

  Future<void> _load() async {
    try {
      final state = context.read<AppState>();
      final claims = await state.wallet.getMyClaims(state.user!.id);
      if (!mounted) return;
      setState(() {
        _claims = claims;
        _loadError = null;
        _offline = false;
        _hasLoaded = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError =
            'Could not load payouts. Check your connection and try again.';
        _offline = isOfflineLoadError(error);
        _hasLoaded = true;
      });
    }
  }

  Future<void> _retry() async {
    setState(() {
      _loadError = null;
      _offline = false;
    });
    await _load();
  }

  Future<void> _openScanner() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ScanClaimScreen(
          shellController:
              widget.embedded ? context.read<ShellTabController>() : null,
        ),
      ),
    );
    if (ok == true) _load();
  }

  Widget _roundAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 26),
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
    return Container(
      width: double.infinity,
      padding: EdgeInsets.zero,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: ProfileHeroMetrics.gradientBegin,
          end: ProfileHeroMetrics.gradientEnd,
          colors: [context.colors.header, context.colors.heroGradientEnd],
        ),
        borderRadius: BorderRadius.circular(ProfileHeroMetrics.radius),
        border: Border.all(
          color: context.colors.borderSoft,
          width: HomeActivityRow.recentActivityBorderWidth,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TOTAL RECEIVED',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.start,
              style: TextStyle(
                color: context.colors.onHeader.withValues(alpha: .92),
                fontSize: HomeActivityRow.recentActivityTitleFontSize,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            HeroAmountText(
              prefix: 'PHP ',
              amount: fmtPhp(total),
              color: context.colors.onHeader,
            ),
            if (receivedCount > 0) ...[
              const SizedBox(height: 8),
              Container(
                key: const ValueKey('payout-summary-status'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: context.colors.onHeader.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
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
                        fontSize: HomeActivityRow.recentActivityDetailFontSize,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statCard({
    required String label,
    required int count,
    required IconData icon,
    required Color tileColor,
    required Color iconColor,
  }) {
    return AppCard(
      key: ValueKey('payout-stat-$label'),
      radius: HomeActivityRow.recentActivityRadius,
      shadow: true,
      padding: const EdgeInsets.symmetric(
        horizontal: HomeActivityRow.recentActivityHorizontalPadding,
        vertical: 12,
      ),
      borderWidth: HomeActivityRow.recentActivityBorderWidth,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: tileColor,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: iconColor, size: 22),
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
                    fontSize: HomeActivityRow.recentActivityTitleFontSize,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                StatNumberText(
                  value: '$count',
                  color: context.colors.textPrimary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _skeleton() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        const SkeletonCard(
          radius: HomeActivityRow.recentActivityRadius,
          padding: EdgeInsets.symmetric(
            horizontal: HomeActivityRow.recentActivityHorizontalPadding,
            vertical: 14,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonLine(
                width: 130,
                height: HomeActivityRow.recentActivityTitleFontSize,
              ),
              SizedBox(height: 2),
              SkeletonLine(
                width: 150,
                height: HomeActivityRow.recentActivityValueFontSize,
              ),
              SizedBox(height: 6),
              SkeletonBox(width: 170, height: 24, radius: 12),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Row(
          children: [
            Expanded(child: SkeletonBox(height: 78, radius: 22)),
            SizedBox(width: 12),
            Expanded(child: SkeletonBox(height: 78, radius: 22)),
          ],
        ),
        const SizedBox(height: 20),
        SkeletonCard(
          child: Column(
            children: [
              for (var index = 0; index < 3; index++) ...[
                if (index > 0) const SizedBox(height: 16),
                const Row(
                  children: [
                    SkeletonCircle(diameter: 48),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonLine(width: 138, height: 13),
                          SizedBox(height: 8),
                          SkeletonLine(width: 94, height: 11),
                        ],
                      ),
                    ),
                    SizedBox(width: 12),
                    SkeletonLine(width: 76, height: 14),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
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
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        key: ValueKey('payout-card-${claim.id}'),
        radius: HomeActivityRow.recentActivityRadius,
        shadow: true,
        onTap: received
            ? () => Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => PayoutReceiptScreen(claim: claim),
                  ),
                )
            : null,
        borderColor:
            pending ? context.colors.accentGold : context.colors.borderSoft,
        borderWidth: HomeActivityRow.recentActivityBorderWidth,
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: received
                        ? context.colors.successBg
                        : cancelled
                            ? context.colors.dangerBg
                            : context.colors.warningBg,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: statusColor, size: 22),
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
                          fontSize: HomeActivityRow.recentActivityTitleFontSize,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (when != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('MMM d, yyyy · h:mm a')
                              .format(when.toLocal()),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.colors.textBody,
                            fontSize:
                                HomeActivityRow.recentActivityDetailFontSize,
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
                              fontSize:
                                  HomeActivityRow.recentActivityValueFontSize,
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
                ],
              ),
            ],
            if (pending) ...[
              const SizedBox(height: 8),
              Text(
                "Go to the office and scan the admin's QR.",
                style: TextStyle(
                  color: context.colors.textBody,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 10),
              PrimaryButton(
                label: 'Scan QR',
                icon: AppIcons.qrScan,
                minHeight: 46,
                borderRadius: 16,
                onPressed: _openScanner,
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
        automaticallyImplyLeading: !widget.embedded,
        backgroundColor: context.colors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: !widget.embedded,
        titleSpacing: widget.embedded ? 20 : 0,
        leadingWidth: 70,
        title: Text(
          'My Payouts',
          style: TextStyle(
            color: context.colors.textPrimary,
            fontSize: widget.embedded ? 26 : 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        leading: widget.embedded
            ? null
            : _roundAction(
                icon: AppIcons.back,
                tooltip: 'Back',
                onPressed: () => Navigator.maybePop(context),
              ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ScrollConfiguration(
          behavior: const _ClaimsNoStretchScrollBehavior(),
          child: AppInitialLoadView(
            firstLoadPending: !_hasLoaded,
            skeleton: _skeleton(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: ClampingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                if (_loadError != null && _claims.isEmpty)
                  ErrorCard(
                    message: _offline
                        ? 'Check your connection and try again. Your balance and payouts are not changed.'
                        : _loadError!,
                    onRetry: _retry,
                    prominent: true,
                    offline: _offline,
                  )
                else ...[
                  if (_loadError != null) ...[
                    ErrorCard(
                      message: _offline
                          ? 'Check your connection and try again. Your balance and payouts are not changed.'
                          : _loadError!,
                      onRetry: _retry,
                      offline: _offline,
                    ),
                    const SizedBox(height: 12),
                  ],
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
                  const SizedBox(height: 16),
                  SectionLabel('PAYOUTS (${_claims.length})'),
                  const SizedBox(height: 8),
                  if (_claims.isEmpty)
                    _emptyState()
                  else
                    ..._claims.map(_claimCard),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
