import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/widgets.dart';
import '../fingerprint_screen.dart';

/// Admin: every payout QR ever issued, with its live status.
class ClaimsMonitorScreen extends StatefulWidget {
  const ClaimsMonitorScreen({super.key});

  @override
  State<ClaimsMonitorScreen> createState() => _ClaimsMonitorScreenState();
}

class _ClaimsMonitorScreenState extends State<ClaimsMonitorScreen> {
  List<AllowanceClaim> _claims = [];
  bool _loading = true;
  String? _error;
  String _filter = 'all';
  String _query = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final claims = await context.read<AppState>().wallet.getAllClaims();
      if (!mounted) return;
      setState(() {
        _claims = claims;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _claims = [];
        _error = '$error';
        _loading = false;
      });
    }
  }

  Future<void> _retry() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    await _load();
  }

  List<AllowanceClaim> get _visible {
    final query = _query.trim().toLowerCase();
    return _claims.where((claim) {
      final matchesFilter = switch (_filter) {
        'waiting' => claim.isPending,
        'received' => claim.isReceived,
        'cancelled' => claim.isVoided,
        _ => true,
      };
      return matchesFilter &&
          (query.isEmpty || claim.scholarName.toLowerCase().contains(query));
    }).toList()
      ..sort((a, b) => _dateFor(b).compareTo(_dateFor(a)));
  }

  DateTime _dateFor(AllowanceClaim claim) =>
      (claim.isReceived ? claim.claimedAt : claim.issuedAt) ??
      claim.issuedAt ??
      claim.distributionDate ??
      DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> _void(AllowanceClaim claim) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Cancel this payout?',
      message: 'PHP ${fmtPhp(claim.amount)} reserved for '
          '${claim.scholarName} will be released. Their QR code will stop working.',
      confirmLabel: 'Cancel payout',
      cancelLabel: 'Keep',
      danger: true,
    );
    if (confirmed != true) return;
    if (!mounted) return;

    // Cancelling a waiting payout requires device biometric confirmation.
    final state = context.read<AppState>();
    if (!state.fingerprintRegistered) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const FingerprintScreen(required: true),
        ),
      );
      if (!mounted || !state.fingerprintRegistered) return;
    }
    final verified = await state.verifyFingerprint(
      'Cancel the PHP ${fmtPhp(claim.amount)} payout for ${claim.scholarName}?',
    );
    if (!mounted) return;
    if (!verified) {
      showMsg(
        context,
        'Biometrics not verified. Payout not cancelled.',
        error: true,
      );
      return;
    }
    try {
      await context.read<AppState>().wallet.voidClaim(claim.id);
      if (!mounted) return;
      showMsg(context, 'Payout cancelled.');
      _load();
    } catch (error) {
      if (mounted) showMsg(context, 'Failed: $error', error: true);
    }
  }

  void _showQr(AllowanceClaim claim) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => AppBottomSheet(
        title: 'Payout QR',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              claim.scholarName,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'PHP ${fmtPhp(claim.amount)}',
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            StatusChip(
              _statusLabel(claim),
              color: _statusColor(claim),
              bg: _statusBackground(claim),
            ),
            const SizedBox(height: 14),
            ClaimQrPanel(claim: claim, size: 210),
            const SizedBox(height: 16),
            if (claim.isPending)
              SecondaryButton(
                label: 'Cancel payout',
                icon: AppIcons.cancel,
                danger: true,
                minHeight: 52,
                borderRadius: 16,
                onPressed: () {
                  Navigator.pop(sheetContext);
                  _void(claim);
                },
              )
            else
              PrimaryButton(
                label: 'Close',
                minHeight: 52,
                borderRadius: 16,
                onPressed: () => Navigator.pop(sheetContext),
              ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(AllowanceClaim claim) => claim.isReceived
      ? 'Received'
      : claim.isVoided
          ? 'Cancelled'
          : 'Waiting for scan';

  Color _statusColor(AllowanceClaim claim) => claim.isReceived
      ? context.colors.successText
      : claim.isVoided
          ? context.colors.dangerText
          : context.colors.warningText;

  Color _statusBackground(AllowanceClaim claim) => claim.isReceived
      ? context.colors.successBg
      : claim.isVoided
          ? context.colors.dangerBg
          : context.colors.warningBg;

  Widget _roundButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
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

  Widget _hero(int receivedCount, double totalPaid) {
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
              right: -42,
              child:
                  _circle(context.colors.onHeader.withValues(alpha: .12), 230),
            ),
            Positioned(
              right: -116,
              bottom: -132,
              child:
                  _circle(context.colors.onHeader.withValues(alpha: .1), 250),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TOTAL PAID OUT',
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
                            text: fmtPhp(totalPaid),
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
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
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
    required String value,
    required Color dotColor,
    required Color valueColor,
  }) {
    return AppCard(
      radius: 22,
      shadow: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: valueColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: value.startsWith('PHP') ? 19 : 25,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String value, String label) {
    final selected = _filter == value;
    return Expanded(
      child: SizedBox(
        height: 42,
        child: ChoiceChip(
          label: SizedBox(
            width: double.infinity,
            child: Center(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected
                      ? context.colors.onHeader
                      : context.colors.textBody,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          selected: selected,
          showCheckmark: false,
          onSelected: (_) => setState(() => _filter = value),
          padding: EdgeInsets.zero,
          labelPadding: const EdgeInsets.symmetric(horizontal: 4),
          shape: const StadiumBorder(),
          side: BorderSide(
            color: selected ? context.colors.brand : context.colors.borderSoft,
          ),
          backgroundColor: context.colors.surface,
          selectedColor: context.colors.brand,
        ),
      ),
    );
  }

  Map<String, List<AllowanceClaim>> _groupedClaims(
    List<AllowanceClaim> claims,
  ) {
    final groups = <String, List<AllowanceClaim>>{};
    for (final claim in claims) {
      final key = DateFormat('MMMM yyyy').format(_dateFor(claim).toLocal());
      groups.putIfAbsent(key, () => []).add(claim);
    }
    return groups;
  }

  Widget _claimCard(List<AllowanceClaim> claims) {
    return AppCard(
      radius: 22,
      shadow: true,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          for (var index = 0; index < claims.length; index++) ...[
            if (index > 0) Divider(height: 1, color: context.colors.borderSoft),
            _claimRow(claims[index]),
          ],
        ],
      ),
    );
  }

  Widget _claimRow(AllowanceClaim claim) {
    final received = claim.isReceived;
    final cancelled = claim.isVoided;
    final foreground = received
        ? context.colors.successText
        : cancelled
            ? context.colors.warningText
            : context.colors.warningText;
    final background = received
        ? context.colors.successBg
        : cancelled
            ? context.colors.avatarBackground
            : context.colors.warningBg;
    final displayDate = _dateFor(claim).millisecondsSinceEpoch == 0
        ? null
        : DateFormat('MMM d, h:mm a').format(_dateFor(claim).toLocal());

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: background,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              claim.scholarName.trim().isNotEmpty
                  ? claim.scholarName.trim()[0].toUpperCase()
                  : '?',
              style: TextStyle(
                color: foreground,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  claim.scholarName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                if (displayDate != null)
                  Text(
                    displayDate,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.colors.textBody,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 96,
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
                        color: cancelled
                            ? context.colors.textBody
                            : context.colors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        decoration: cancelled
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                StatusChip(
                  _statusLabel(claim),
                  color: claim.isVoided
                      ? context.colors.dangerText
                      : _statusColor(claim),
                  bg: claim.isVoided
                      ? context.colors.dangerBg
                      : _statusBackground(claim),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Column(
            children: [
              Material(
                color: context.colors.brandTint,
                borderRadius: BorderRadius.circular(14),
                child: IconButton(
                  onPressed: () => _showQr(claim),
                  tooltip: 'View QR',
                  constraints:
                      const BoxConstraints.tightFor(width: 44, height: 44),
                  padding: EdgeInsets.zero,
                  icon: Icon(AppIcons.qrCode, color: context.colors.brand),
                ),
              ),
              if (claim.isPending)
                SizedBox(
                  width: 28,
                  height: 28,
                  child: PopupMenuButton<String>(
                    tooltip: 'Payout actions',
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints.tightFor(width: 28, height: 28),
                    iconSize: 18,
                    onSelected: (action) {
                      if (action == 'cancel') _void(claim);
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'cancel',
                        child: Text('Cancel payout'),
                      ),
                    ],
                    icon: Icon(AppIcons.menu, color: context.colors.textBody),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _loadingSkeleton() {
    return AppSkeletonizer(
      enabled: true,
      child: Column(
        children: [
          AppCard(
            radius: 26,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 140, height: 14, color: Colors.white),
                const SizedBox(height: 12),
                Container(width: 230, height: 42, color: Colors.white),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            radius: 22,
            child: Container(height: 56, color: Colors.white),
          ),
          const SizedBox(height: 16),
          AppCard(
            radius: 22,
            child: Column(
              children: List.generate(
                3,
                (index) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Container(height: 42, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyCard({
    required String title,
    bool showClear = false,
  }) {
    return AppCard(
      radius: 22,
      shadow: true,
      padding: const EdgeInsets.all(28),
      child: EmptyState(
        icon: AppIcons.qrCode,
        title: title,
        message: showClear
            ? 'Try another filter to find payouts.'
            : 'Payouts will appear here after they are issued.',
        action: showClear
            ? SecondaryButton(
                label: 'Clear filters',
                onPressed: () {
                  setState(() {
                    _filter = 'all';
                    _query = '';
                    _searchController.clear();
                  });
                },
              )
            : null,
      ),
    );
  }

  Widget _roundBackButton() {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Material(
        color: context.colors.surface,
        shape: CircleBorder(
          side: BorderSide(color: context.colors.borderSoft),
        ),
        child: IconButton(
          onPressed: () => Navigator.maybePop(context),
          tooltip: 'Back',
          constraints: const BoxConstraints.tightFor(width: 44, height: 44),
          padding: EdgeInsets.zero,
          icon: Icon(AppIcons.back, color: context.colors.textPrimary),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final waiting = _claims.where((claim) => claim.isPending).length;
    final receivedClaims = _claims.where((claim) => claim.isReceived).toList();
    final totalPaid = receivedClaims.fold<double>(
      0,
      (sum, claim) => sum + claim.amount,
    );
    final reserved = _claims
        .where((claim) => claim.isPending)
        .fold<double>(0, (sum, claim) => sum + claim.amount);
    final visible = _visible;
    final grouped = _groupedClaims(visible);
    final filterOptions = [
      ('all', 'All'),
      ('waiting', 'Waiting'),
      ('received', 'Received'),
      ('cancelled', 'Cancelled'),
    ];

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        leadingWidth: 60,
        leading: _roundBackButton(),
        centerTitle: true,
        title: Text(
          'Payout Monitor',
          style: TextStyle(
            color: context.colors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          _roundButton(
            icon: AppIcons.refresh,
            tooltip: 'Refresh payouts',
            onPressed: _load,
          ),
          const SizedBox(width: 4),
        ],
        backgroundColor: context.colors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ScrollConfiguration(
          behavior: const _ClaimsMonitorScrollBehavior(),
          child: ListView(
            physics: const ClampingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              if (_loading)
                _loadingSkeleton()
              else if (_error != null)
                ErrorCard(
                  message: 'Could not load payouts. $_error',
                  onRetry: _retry,
                )
              else ...[
                _hero(receivedClaims.length, totalPaid),
                const SizedBox(height: 16),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _statCard(
                          label: 'Waiting',
                          value: '$waiting',
                          dotColor: context.colors.warning,
                          valueColor: context.colors.warningText,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _statCard(
                          label: 'Received',
                          value: '${receivedClaims.length}',
                          dotColor: context.colors.success,
                          valueColor: context.colors.successText,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _statCard(
                          label: 'Reserved',
                          value: 'PHP ${fmtPhp(reserved)}',
                          dotColor: context.colors.brand,
                          valueColor: context.colors.brand,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SearchField(
                  controller: _searchController,
                  hintText: 'Search scholar name',
                  radius: 18,
                  minHeight: 48,
                  onChanged: (value) => setState(() => _query = value),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: Icon(
                            AppIcons.close,
                            color: context.colors.textBody,
                          ),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    children: [
                      for (var index = 0;
                          index < filterOptions.length;
                          index++) ...[
                        if (index > 0) const SizedBox(width: 8),
                        _filterChip(
                          filterOptions[index].$1,
                          filterOptions[index].$2,
                        ),
                      ],
                    ],
                  ),
                ),
                if (visible.isEmpty) ...[
                  const SizedBox(height: 24),
                  _emptyCard(
                    title: _claims.isEmpty
                        ? 'No payouts yet'
                        : 'No matching payouts',
                    showClear: _claims.isNotEmpty,
                  ),
                ] else
                  for (final entry in grouped.entries) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 24, bottom: 10),
                      child: SectionLabel(
                        '${entry.key.toUpperCase()} · ${entry.value.length} '
                        '${entry.value.length == 1 ? 'PAYOUT' : 'PAYOUTS'}',
                      ),
                    ),
                    _claimCard(entry.value),
                  ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ClaimsMonitorScrollBehavior extends MaterialScrollBehavior {
  const _ClaimsMonitorScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) =>
      child;
}
