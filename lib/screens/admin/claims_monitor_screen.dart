import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/app_state.dart';
import '../../services/wallet_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/destructive_confirm_dialog.dart';
import '../../widgets/shell_tab_controller.dart';
import '../../widgets/widgets.dart';
import '../fingerprint_screen.dart';
import 'program_payout_qr_screen.dart';

/// Admin: every payout QR ever issued, with its live status.
class ClaimsMonitorScreen extends StatefulWidget {
  final bool embedded;

  const ClaimsMonitorScreen({super.key, this.embedded = false});

  @override
  State<ClaimsMonitorScreen> createState() => _ClaimsMonitorScreenState();
}

class _ClaimsMonitorScreenState extends State<ClaimsMonitorScreen> {
  List<AllowanceClaim> _claims = [];
  Map<String, String> _programNames = {};
  bool _hasLoaded = false;
  String? _error;
  bool _offline = false;
  String _filter = 'all';
  String _query = '';
  final _searchController = TextEditingController();
  ShellTabController? _tabController;

  @override
  void initState() {
    super.initState();
    _load();
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
    if (_tabController?.selectedIndex == 1) _load();
  }

  @override
  void dispose() {
    _tabController?.removeListener(_onTabChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final wallet = context.read<AppState>().wallet;
      final results = await Future.wait<dynamic>([
        wallet.getAllClaims(),
        wallet.getDisbursements(),
      ]);
      final claims = results[0] as List<AllowanceClaim>;
      final events = results[1] as List<Map<String, dynamic>>;
      if (!mounted) return;
      setState(() {
        _claims = claims;
        _programNames = {
          for (final event in events)
            if (event['program_name'] is String &&
                (event['program_name'] as String).trim().isNotEmpty)
              event['id'].toString(): event['program_name'] as String,
        };
        _error = null;
        _offline = false;
        _hasLoaded = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load Payouts. Please try again.';
        _offline = isOfflineLoadError(error);
        _hasLoaded = true;
      });
    }
  }

  Future<void> _retry() async {
    setState(() {
      _error = null;
      _offline = false;
    });
    await _load();
  }

  List<AllowanceClaim> get _visible {
    final query = _query.trim().toLowerCase();
    return _claims.where((claim) {
      final matchesFilter = switch (_filter) {
        'all' => !claim.isVoided,
        'waiting' => claim.isPending,
        'received' => claim.isReceived,
        _ => !claim.isVoided,
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
    final confirmed = await DestructiveConfirmDialog.show(
      context,
      title: 'Cancel this payout?',
      message: 'PHP ${fmtPhp(claim.amount)} reserved for '
          '${claim.scholarName} will be released. Their QR code will stop working.',
      dismissLabel: 'Keep',
      confirmLabel: 'Cancel payout',
      semanticsLabel: 'Cancel payout confirmation',
      icon: AppIcons.cancel,
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
    } on ClaimNotPendingException {
      if (!mounted) return;
      showMsg(
        context,
        'This Payout is no longer waiting. Refresh the list and try again.',
        error: true,
      );
      await _load();
    } catch (_) {
      if (mounted) {
        showMsg(context, 'Could not cancel this Payout. Please try again.',
            error: true);
      }
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
                borderRadius: 18,
                onPressed: () {
                  Navigator.pop(sheetContext);
                  _void(claim);
                },
              )
            else
              PrimaryButton(
                label: 'Close',
                minHeight: 52,
                borderRadius: 18,
                onPressed: () => Navigator.pop(sheetContext),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showProgramEventQr(AllowanceClaim claim) async {
    final programName = _programNames[claim.batchId];
    if (programName == null) return;
    try {
      final wallet = context.read<AppState>().wallet;
      final token = await wallet.getPayoutEventToken(claim.batchId);
      if (!mounted) return;
      final recipients =
          _claims.where((item) => item.batchId == claim.batchId).toList();
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProgramPayoutQrScreen(
            batchId: claim.batchId,
            programName: programName,
            title: claim.batchTitle,
            amountPerScholar: claim.amount,
            recipientNames:
                recipients.map((recipient) => recipient.scholarName).toList(),
            eventToken: token,
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        showMsg(
          context,
          error is WalletException
              ? error.message
              : 'Could not load this payout event QR.',
          error: true,
        );
      }
    }
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

  Widget _hero(int receivedCount, double totalPaid) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.zero,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [context.colors.header, context.colors.heroGradientEnd],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TOTAL PAID OUT',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.colors.onHeader.withValues(alpha: .92),
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            HeroAmountText(
              prefix: 'PHP ',
              amount: fmtPhp(totalPaid),
              color: context.colors.onHeader,
            ),
            if (receivedCount > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: context.colors.onHeader.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
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
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statCard({
    required String label,
    required String value,
    required Color dotColor,
    required Color valueColor,
  }) {
    final hasCurrencyPrefix = value.startsWith('PHP ');
    return AppCard(
      radius: 22,
      shadow: true,
      padding: const EdgeInsets.all(16),
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
          StatNumberText(
            prefix: hasCurrencyPrefix ? 'PHP' : null,
            value: hasCurrencyPrefix ? value.substring(4) : value,
            color: context.colors.textPrimary,
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

  Widget _claimCard(
    List<AllowanceClaim> claims,
    Set<String> eventQrClaimIds,
  ) {
    return AppCard(
      radius: 22,
      shadow: true,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          for (var index = 0; index < claims.length; index++) ...[
            if (index > 0) Divider(height: 1, color: context.colors.borderSoft),
            _claimRow(
              claims[index],
              showProgramEventQr: eventQrClaimIds.contains(claims[index].id),
            ),
          ],
        ],
      ),
    );
  }

  Widget _claimRow(
    AllowanceClaim claim, {
    required bool showProgramEventQr,
  }) {
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
    final programName = _programNames[claim.batchId];

    return Padding(
      key: ValueKey('payout-row-${claim.id}'),
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
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
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      softWrap: true,
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
                    const SizedBox(height: 6),
                    Wrap(
                      children: [
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
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 78,
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
                    if (programName == null && claim.isPending) ...[
                      const SizedBox(height: 5),
                      Material(
                        color: context.colors.brandTint,
                        borderRadius: BorderRadius.circular(14),
                        child: IconButton(
                          onPressed: () => _showQr(claim),
                          tooltip: 'View QR',
                          constraints: const BoxConstraints.tightFor(
                            width: 40,
                            height: 40,
                          ),
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            AppIcons.qrCode,
                            color: context.colors.brand,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (programName != null && (showProgramEventQr || claim.isPending))
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 4,
              children: [
                if (showProgramEventQr)
                  TextButton.icon(
                    onPressed: () => _showProgramEventQr(claim),
                    icon: const Icon(AppIcons.qrCode, size: 17),
                    label: const Text('Show event QR'),
                    style: TextButton.styleFrom(
                      foregroundColor: context.colors.brand,
                      minimumSize: const Size(0, 40),
                    ),
                  ),
                if (claim.isPending)
                  TextButton(
                    onPressed: () => _void(claim),
                    style: TextButton.styleFrom(
                      foregroundColor: context.colors.dangerText,
                      minimumSize: const Size(0, 40),
                    ),
                    child: const Text('Void'),
                  ),
              ],
            )
        ],
      ),
    );
  }

  Widget _loadingSkeleton() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        const SkeletonCard(
          radius: 28,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonLine(width: 140, height: 14),
              SizedBox(height: 12),
              SkeletonLine(width: 230, height: 42),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Row(
          children: [
            Expanded(child: SkeletonBox(height: 72, radius: 22)),
            SizedBox(width: 10),
            Expanded(child: SkeletonBox(height: 72, radius: 22)),
            SizedBox(width: 10),
            Expanded(child: SkeletonBox(height: 72, radius: 22)),
          ],
        ),
        const SizedBox(height: 14),
        const SkeletonBox(height: 48, radius: 16),
        const SizedBox(height: 12),
        const Row(
          children: [
            SkeletonBox(width: 56, height: 34, radius: 17),
            SizedBox(width: 8),
            SkeletonBox(width: 82, height: 34, radius: 17),
            SizedBox(width: 8),
            SkeletonBox(width: 90, height: 34, radius: 17),
          ],
        ),
        const SizedBox(height: 16),
        SkeletonCard(
          child: Column(
            children: [
              for (var index = 0; index < 4; index++) ...[
                if (index > 0) const SizedBox(height: 18),
                const Row(
                  children: [
                    SkeletonCircle(diameter: 42),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonLine(width: 142, height: 13),
                          SizedBox(height: 8),
                          SkeletonLine(width: 92, height: 11),
                        ],
                      ),
                    ),
                    SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        SkeletonLine(width: 72, height: 13),
                        SizedBox(height: 8),
                        SkeletonBox(width: 58, height: 20, radius: 8),
                      ],
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
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
      padding: const EdgeInsets.only(left: 26),
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
    final waitingProgramBatches = _claims
        .where(
          (claim) =>
              claim.isPending && _programNames.containsKey(claim.batchId),
        )
        .map((claim) => claim.batchId)
        .toSet();
    final eventQrClaimIds = <String>{};
    final seenProgramBatches = <String>{};
    for (final claim in visible) {
      if (waitingProgramBatches.contains(claim.batchId) &&
          seenProgramBatches.add(claim.batchId)) {
        eventQrClaimIds.add(claim.id);
      }
    }
    final filterOptions = [
      ('all', 'All'),
      ('waiting', 'Waiting'),
      ('received', 'Received'),
    ];

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embedded,
        leadingWidth: 70,
        leading: widget.embedded ? null : _roundBackButton(),
        centerTitle: !widget.embedded,
        titleSpacing: widget.embedded ? 20 : 0,
        title: Text(
          'Payout Monitor',
          style: TextStyle(
            color: context.colors.textPrimary,
            fontSize: widget.embedded ? 26 : 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: context.colors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ScrollConfiguration(
          behavior: const _ClaimsMonitorScrollBehavior(),
          child: AppInitialLoadView(
            firstLoadPending: !_hasLoaded,
            skeleton: _loadingSkeleton(),
            child: ListView(
              physics: const ClampingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                if (_error != null && _claims.isEmpty)
                  ErrorCard(
                    message: _offline
                        ? 'Check your connection and try again. Your balance and payouts are not changed.'
                        : 'Could not load payouts. $_error',
                    onRetry: _retry,
                    prominent: true,
                    offline: _offline,
                  )
                else ...[
                  if (_error != null) ...[
                    ErrorCard(
                      message: _offline
                          ? 'Check your connection and try again. Your balance and payouts are not changed.'
                          : 'Could not load payouts. $_error',
                      onRetry: _retry,
                      offline: _offline,
                    ),
                    const SizedBox(height: 12),
                  ],
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
                    radius: 16,
                    minHeight: 50,
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
                      _claimCard(entry.value, eventQrClaimIds),
                    ],
                ],
              ],
            ),
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
