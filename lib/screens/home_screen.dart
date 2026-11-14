import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../data/demo_allowance_repository.dart';
import '../theme/app_theme.dart';
import '../providers/app_state.dart';
import '../models/models.dart';
import '../widgets/widgets.dart';
import '../widgets/app_icons.dart';
import 'scan_claim_screen.dart';
import 'history_screen.dart';
import 'fingerprint_screen.dart';
import 'cashout_screen.dart';
import 'claims_screen.dart';
import 'payout_events_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeNoStretchScrollBehavior extends MaterialScrollBehavior {
  const _HomeNoStretchScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) =>
      child;
}

class _HomeScreenState extends State<HomeScreen> {
  List<WalletTransaction> _recent = [];
  List<AllowanceClaim> _pending = [];
  List<AllowanceClaim> _claims = [];
  bool _loading = true;
  String? _loadError;
  Timer? _poll;
  Set<String>? _seenPending;
  bool _announced = false;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 15), (_) => _checkNewQr());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  /// In-app notification: a new payout QR was issued to this scholar.
  Future<void> _checkNewQr() async {
    try {
      final state = context.read<AppState>();
      if (state.user?.canReceiveAllowance != true) return;
      final pending = await state.wallet.getPendingClaims(state.user!.id);
      final ids = pending.map((c) => c.id).toSet();
      final seen = _seenPending;
      _seenPending = ids;
      if (seen != null && mounted) {
        final fresh = pending.where((c) => !seen.contains(c.id)).toList();
        if (fresh.isNotEmpty) {
          final total = fresh.fold<double>(0, (s, c) => s + c.amount);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'New allowance from admin: PHP ${fmtPhp(total)}. Scan the QR to receive it.'),
            action: SnackBarAction(label: 'SCAN', onPressed: _openScanner),
            duration: const Duration(seconds: 10),
          ));
        }
        if (seen.length != ids.length || fresh.isNotEmpty) _load();
      }
    } catch (_) {}
  }

  Future<void> _load() async {
    final state = context.read<AppState>();
    try {
      await state.refreshProfile();
      if (state.user?.canReceiveAllowance != true) {
        _recent = [];
        _pending = [];
        _claims = [];
        _loadError = null;
        return;
      }
      await state.refreshBalance();
      await state.loadAllowanceSettings();
      final uid = state.user!.id;
      final txs = await state.wallet.getTransactions(uid, limit: 20);
      final items = <WalletTransaction>[
        ...txs,
      ];
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _recent = items.take(4).toList();
      _pending = await state.wallet.getPendingClaims(uid);
      _claims = await state.wallet.getMyClaims(uid);
      _loadError = null;
      _seenPending ??= _pending.map((c) => c.id).toSet();
      if (!_announced && _pending.isNotEmpty && mounted) {
        _announced = true;
        final total = _pending.fold<double>(0, (s, c) => s + c.amount);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'You have ${_pending.length} allowance(s) waiting: PHP ${fmtPhp(total)}. Scan the QR from the admin to receive it.'),
            action: SnackBarAction(label: 'SCAN', onPressed: _openScanner),
            duration: const Duration(seconds: 10),
          ));
        });
      }
    } catch (_) {
      _recent = [];
      _pending = [];
      _claims = [];
      _loadError = 'Could not load your Scholar Home. Please try again.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  AllowanceClaim? get _latestPayout {
    if (_claims.isEmpty) return null;
    final claims = [..._claims]..sort((a, b) {
        final aDate = a.issuedAt ?? a.claimedAt;
        final bDate = b.issuedAt ?? b.claimedAt;
        if (aDate == null) return bDate == null ? 0 : 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });
    return claims.first;
  }

  String _friendlyDate(DateTime? date) => date == null
      ? 'Date unavailable'
      : DateFormat('MMM d, yyyy').format(date.toLocal());

  void _showNotifications() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      barrierColor: Theme.of(context).colorScheme.scrim.withValues(alpha: .64),
      builder: (sheetContext) {
        final colors = sheetContext.colors;
        final cardBackground =
            Theme.of(sheetContext).brightness == Brightness.dark
                ? colors.surface
                : colors.background;

        void openPayout(AllowanceClaim claim) {
          Navigator.pop(sheetContext);
          showPayoutQrSheet(context, claim, onScan: _openScanner);
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
          child: _pending.isEmpty
              ? AppCard(
                  radius: 28,
                  padding: const EdgeInsets.all(32),
                  backgroundColor: cardBackground,
                  borderColor: colors.borderSoft,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: colors.goldTint,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          AppIcons.bell,
                          color: colors.onGold,
                          size: 36,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'Nothing new',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No new notifications.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.textBody,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "We'll tell you when an allowance is released.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.textBody,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : AppCard(
                  radius: 24,
                  padding: EdgeInsets.zero,
                  backgroundColor: cardBackground,
                  borderColor: colors.borderSoft,
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var index = 0; index < _pending.length; index++) ...[
                        if (index > 0)
                          Divider(
                            height: 1,
                            indent: 70,
                            endIndent: 12,
                            color: colors.borderSoft,
                          ),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => openPayout(_pending[index]),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: colors.goldTint,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    alignment: Alignment.center,
                                    child: Icon(
                                      AppIcons.qrCode,
                                      color: colors.onGold,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Allowance ready: PHP '
                                          '${fmtPhp(_pending[index].amount)}',
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
                                          _pending[index].issuedAt == null
                                              ? _pending[index].batchTitle
                                              : '${_pending[index].batchTitle} · '
                                                  'Released ${_friendlyDate(_pending[index].issuedAt)}',
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
                                  Icon(
                                    AppIcons.chevronRight,
                                    color: colors.textBody,
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
        );
      },
    );
  }

  Future<void> _openScanner() async {
    final state = context.read<AppState>();
    await state.refreshProfile();
    if (!mounted || state.user?.canReceiveAllowance != true) return;

    if (!mounted) return;
    final received = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ScanClaimScreen()),
    );
    if (received == true) _load();
  }

  Future<void> _openCashOut() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CashoutScreen()),
    );
    _load();
  }

  Future<void> _openTransactions() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HistoryScreen()),
    );
    _load();
  }

  Future<void> _openMyPayouts() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ClaimsScreen()),
    );
    _load();
  }

  Future<void> _openProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    _load();
  }

  Widget _balanceHero(BuildContext context, double balance) {
    final balanceText = 'PHP ${fmtPhp(balance)}';
    final heroTextColor = context.colors.balanceHeroText;
    return AppCard(
      padding: const EdgeInsets.all(24),
      radius: 28,
      shadow: true,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          context.colors.balanceHeroStart,
          context.colors.balanceHeroEnd,
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            top: -82,
            right: -44,
            child: _balanceHeroCircle(
              heroTextColor.withValues(alpha: .08),
              208,
            ),
          ),
          Positioned(
            bottom: -126,
            right: -84,
            child: _balanceHeroCircle(
              heroTextColor.withValues(alpha: .07),
              256,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'CURRENT BALANCE',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: heroTextColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: heroTextColor.withValues(alpha: .12),
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: () async {
                        await Clipboard.setData(
                          ClipboardData(text: balanceText),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Balance copied')),
                          );
                        }
                      },
                      customBorder: const CircleBorder(),
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: Icon(
                          AppIcons.copy,
                          color: heroTextColor,
                          size: 21,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text.rich(
                    TextSpan(
                      style: TextStyle(
                        color: heroTextColor,
                        fontWeight: FontWeight.w800,
                      ),
                      children: [
                        const TextSpan(
                          text: 'PHP ',
                          style: TextStyle(fontSize: 28),
                        ),
                        TextSpan(
                          text: fmtPhp(balance),
                          style: const TextStyle(fontSize: 48),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    softWrap: false,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 360),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: heroTextColor.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: context.colors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Money received and verified by QR',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: heroTextColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _balanceHeroCircle(Color color, double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );

  Widget _homeActionButtons(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    final buttonHeight =
        (textScaler.scale(18) + 22).clamp(56.0, 100.0).toDouble();
    final cashOutColor = Theme.of(context).brightness == Brightness.dark
        ? context.colors.header
        : context.colors.brand;
    return Row(
      children: [
        Expanded(
          child: PrimaryButton(
            label: 'Cash Out',
            onPressed: _openCashOut,
            icon: AppIcons.arrowUpRight,
            backgroundColor: cashOutColor,
            foregroundColor: context.colors.onHeader,
            minHeight: buttonHeight,
            borderRadius: 20,
            shadow: true,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Stack(
            alignment: Alignment.topRight,
            children: [
              SecondaryButton(
                label: 'Scan QR',
                onPressed: _openScanner,
                icon: AppIcons.qrScan,
                iconColor: context.colors.brand,
                foregroundColor: context.colors.brand,
                minHeight: buttonHeight,
                borderRadius: 20,
              ),
              if (_pending.isNotEmpty)
                Positioned(
                  top: 10,
                  right: 12,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: context.colors.danger,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final user = state.user;
    final latestPayout = _latestPayout;
    final displayedPayout = _pending.isNotEmpty ? _pending.first : latestPayout;
    final demoData = DemoAllowanceRepository.instance;
    final activity = _recent.take(3).toList();
    final expectedReleaseDate =
        displayedPayout == null ? demoData.expectedReleaseDate : null;
    final academicPeriod = demoData.academicPeriodFor(
      displayedPayout?.batchTitle ?? 'Payout Event',
    );
    final waitingTotal =
        _pending.fold<double>(0, (total, payout) => total + payout.amount);

    return Scaffold(
      backgroundColor: context.colors.background,
      body: Column(
        children: [
          AppHeader(
            name: user?.fullName ?? 'Scholar',
            initials: user?.initials ?? '?',
            subtitle: user?.studentNumber?.isNotEmpty == true
                ? 'ID: ${user!.studentNumber}'
                : '',
            notificationCount: _pending.length,
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
                behavior: const _HomeNoStretchScrollBehavior(),
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
                          enabled: _loading,
                          child: _balanceHero(context, state.balance),
                        ),
                        if (_loadError != null) ...[
                          const SizedBox(height: 16),
                          ErrorCard(message: _loadError!, onRetry: _load),
                        ],
                        const SizedBox(height: 16),
                        AppSkeletonizer(
                          enabled: _loading,
                          child: _homeActionButtons(context),
                        ),
                        const SizedBox(height: 16),
                        AppSkeletonizer(
                          enabled: _loading,
                          child: MonthlyAllowanceCard(
                            title: displayedPayout?.batchTitle ??
                                state.allowance.label,
                            amount: displayedPayout?.amount ??
                                state.allowance.allowanceAmount,
                            state: displayedPayout == null
                                ? AllowanceCardState.notReleased
                                : displayedPayout.isPending
                                    ? AllowanceCardState.waiting
                                    : displayedPayout.isReceived
                                        ? AllowanceCardState.received
                                        : AllowanceCardState.cancelled,
                            issuedDate: displayedPayout == null
                                ? null
                                : _friendlyDate(displayedPayout.issuedAt),
                            receivedDate: displayedPayout?.isReceived == true
                                ? _friendlyDate(displayedPayout!.claimedAt)
                                : null,
                            expectedReleaseDate: expectedReleaseDate,
                            academicPeriod: academicPeriod,
                            waitingCount: _pending.length,
                            waitingTotal: waitingTotal,
                            statusOnRight: true,
                            radius: 26,
                            iconTileSize: 48,
                            amountFontSize: 36,
                          ),
                        ),
                        if (!state.fingerprintRegistered) ...[
                          const SizedBox(height: 16),
                          AppSkeletonizer(
                            enabled: _loading,
                            child: BiometricStatusCard(
                              highlighted: true,
                              radius: 22,
                              iconTileSize: 52,
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const FingerprintScreen(),
                                  ),
                                );
                                if (mounted) setState(() {});
                              },
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        AppSkeletonizer(
                          enabled: _loading,
                          child: _payoutEventsRow(context),
                        ),
                        const SizedBox(height: 26),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Recent activity',
                                style: TextStyle(
                                  color: context.colors.textPrimary,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: _openTransactions,
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
                          enabled: _loading,
                          child: _activityCard(context, activity),
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
        scaleHeightForText: true,
        items: const [
          HomeNavigationItem(
              label: 'Home',
              icon: AppIcons.homeOutline,
              activeIcon: AppIcons.home),
          HomeNavigationItem(label: 'Transactions', icon: AppIcons.chart),
          HomeNavigationItem(
              label: 'My Payouts',
              icon: AppIcons.payouts,
              activeIcon: AppIcons.payouts),
          HomeNavigationItem(label: 'Profile', icon: AppIcons.user),
        ],
        onTap: (index) {
          switch (index) {
            case 1:
              _openTransactions();
            case 2:
              _openMyPayouts();
            case 3:
              _openProfile();
          }
        },
      ),
    );
  }

  Widget _activityCard(
    BuildContext context,
    List<WalletTransaction> transactions,
  ) {
    if (transactions.isEmpty) {
      return AppCard(
        radius: 24,
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
                'No activity yet',
                style: TextStyle(color: context.colors.textBody),
              ),
            ],
          ),
        ),
      );
    }

    return AppCard(
      radius: 24,
      shadow: true,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          for (var index = 0; index < transactions.length; index++) ...[
            if (index > 0) Divider(height: 1, color: context.colors.borderSoft),
            HomeActivityRow(
              transaction: transactions[index],
              friendlyDate: _friendlyDate(transactions[index].createdAt),
              statusLabel: _activityStatus(transactions[index]),
              inCard: true,
              financialPresentation: true,
              showCurrencyCode: false,
              iconSize: 48,
              statusSeparator: '·',
            ),
          ],
        ],
      ),
    );
  }

  String _activityStatus(WalletTransaction transaction) {
    final description = '${transaction.title} ${transaction.subtitle}'
        .toLowerCase()
        .replaceAll('-', ' ');
    if (description.contains('cash out') || description.contains('cashout')) {
      return 'Simulated';
    }
    return switch (transaction.status) {
      TxStatus.completed => 'Completed',
      TxStatus.pending => 'Pending',
      TxStatus.rejected => 'Rejected',
    };
  }

  Widget _payoutEventsRow(BuildContext context) {
    return ListRowCard(
      minHeight: 92,
      padding: const EdgeInsets.all(16),
      radius: 24,
      shadow: true,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PayoutEventsScreen()),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: context.colors.brandTint,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child:
                Icon(AppIcons.calendar, color: context.colors.brand, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Payout Events',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Payout batches issued to you',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style:
                      TextStyle(fontSize: 12, color: context.colors.textBody),
                ),
              ],
            ),
          ),
          Icon(AppIcons.chevronRight, color: context.colors.textBody),
        ],
      ),
    );
  }
}
