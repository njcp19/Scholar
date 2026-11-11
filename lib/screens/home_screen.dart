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
              if (_pending.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                      child: Text('No new notifications.',
                          style: TextStyle(color: context.colors.textBody))),
                )
              else
                ..._pending.map((c) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: context.colors.brandTint,
                        child: Icon(
                          AppIcons.qrCode,
                          color: context.colors.brand,
                        ),
                      ),
                      title: Text('Allowance ready: PHP ${fmtPhp(c.amount)}'),
                      subtitle: Text(
                          '${c.batchTitle}\nTap to see your QR, then scan it to receive.'),
                      isThreeLine: true,
                      onTap: () {
                        Navigator.pop(ctx);
                        showPayoutQrSheet(context, c, onScan: _openScanner);
                      },
                    )),
            ],
          ),
        ),
      ),
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              context.colors.balanceHeroStart,
              context.colors.balanceHeroEnd,
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -70,
              right: 12,
              child: _balanceHeroCircle(
                context.colors.onHeader.withValues(alpha: .13),
                164,
              ),
            ),
            Positioned(
              bottom: -96,
              right: -72,
              child: _balanceHeroCircle(
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
                        'CURRENT BALANCE',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.colors.balanceHeroText,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Material(
                      color:
                          context.colors.balanceHeroText.withValues(alpha: .12),
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: () async {
                          await Clipboard.setData(
                            ClipboardData(text: balanceText),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Balance copied'),
                              ),
                            );
                          }
                        },
                        customBorder: const CircleBorder(),
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: Icon(
                            AppIcons.copy,
                            color: context.colors.balanceHeroText,
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
                    child: Text(
                      balanceText,
                      maxLines: 1,
                      style: TextStyle(
                        color: context.colors.balanceHeroText,
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
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
                    Expanded(
                      child: Text(
                        'Money received and verified by QR',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.colors.balanceHeroText,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
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
        (textScaler.scale(18) + 22).clamp(54.0, 100.0).toDouble();
    return Row(
      children: [
        Expanded(
          child: _homeActionButton(
            context,
            label: 'Cash Out',
            icon: AppIcons.arrowUpRight,
            primary: true,
            height: buttonHeight,
            onTap: _openCashOut,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _homeActionButton(
            context,
            label: 'Scan QR',
            icon: AppIcons.qrScan,
            primary: false,
            height: buttonHeight,
            showNotificationDot: _pending.isNotEmpty,
            onTap: _openScanner,
          ),
        ),
      ],
    );
  }

  Widget _homeActionButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required bool primary,
    required double height,
    required VoidCallback onTap,
    bool showNotificationDot = false,
  }) {
    final background = primary ? context.colors.brand : context.colors.surface;
    final foreground = primary ? context.colors.onHeader : context.colors.brand;
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          constraints: BoxConstraints(minHeight: height),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: primary ? context.colors.brand : context.colors.border,
            ),
            boxShadow: primary
                ? [
                    BoxShadow(
                      color: context.colors.cardShadow,
                      blurRadius: 16,
                      offset: const Offset(0, 7),
                    ),
                  ]
                : null,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: foreground, size: 22),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: foreground,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (showNotificationDot)
                Positioned(
                  top: 9,
                  right: 10,
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final user = state.user;
    final latestPayout = _latestPayout;
    final displayedPayout = _pending.isNotEmpty ? _pending.first : latestPayout;
    final demoData = DemoAllowanceRepository.instance;
    final activity = _loading
        ? [
            for (final item in [
              (title: 'Allowance received', amount: 12345.0, day: 8),
              (title: 'Cash Out', amount: 2450.0, day: 7),
              (title: 'Allowance received', amount: 12345.0, day: 1),
            ])
              WalletTransaction(
                id: 'loading-${item.day}',
                title: item.title,
                subtitle: item.title == 'Cash Out'
                    ? 'Linked Account'
                    : 'Payout Event',
                amount: item.amount,
                type: item.title == 'Cash Out' ? TxType.debit : TxType.credit,
                status: TxStatus.completed,
                createdAt: DateTime(2026, 11, item.day),
              ),
          ]
        : _recent.take(3).toList();
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
                          ),
                        ),
                        if (!state.fingerprintRegistered) ...[
                          const SizedBox(height: 16),
                          AppSkeletonizer(
                            enabled: _loading,
                            child: BiometricStatusCard(
                              highlighted: true,
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
                        SectionLabel(
                          'RECENT ACTIVITY',
                          labelColor: context.colors.textBody,
                          trailing: TextButton(
                            onPressed: _openTransactions,
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
                'No activity yet',
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
          for (var index = 0; index < transactions.length; index++) ...[
            if (index > 0) Divider(height: 1, color: context.colors.borderSoft),
            HomeActivityRow(
              transaction: transactions[index],
              friendlyDate: _friendlyDate(transactions[index].createdAt),
              statusLabel: _activityStatus(transactions[index]),
              inCard: true,
            ),
          ],
        ],
      ),
    );
  }

  String _activityStatus(WalletTransaction transaction) {
    if (transaction.title.toLowerCase().contains('cash out')) {
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
      minHeight: 76,
      radius: 20,
      shadow: true,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PayoutEventsScreen()),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: context.colors.brandTint,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child:
                Icon(AppIcons.calendar, color: context.colors.brand, size: 22),
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
