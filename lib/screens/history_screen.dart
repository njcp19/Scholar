import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icons.dart';
import '../widgets/widgets.dart';
import 'scan_claim_screen.dart';

/// FR-12/FR-13/FR-14 — full transaction history, grouped by month, with
/// search and a credit/debit filter.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

enum _Filter { all, credit, debit }

class _HistoryScreenState extends State<HistoryScreen> {
  List<WalletTransaction> _all = [];
  String _query = '';
  _Filter _filter = _Filter.all;
  bool _loading = true;
  String? _error;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final state = context.read<AppState>();
    try {
      final transactions =
          await state.wallet.getTransactions(state.user!.id, limit: 200);
      transactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (mounted) {
        setState(() {
          _all = transactions;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _all = [];
          _error = 'Could not load transactions.';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _retry() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    await _load();
  }

  Future<void> _openScanner() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ScanClaimScreen()),
    );
    if (result == true) _load();
  }

  String _amountSearchText(WalletTransaction transaction) {
    final formatted = fmtPhp(transaction.amount.abs());
    final sign = transaction.type == TxType.credit ? '+' : '-';
    return 'PHP $formatted $formatted $sign$formatted';
  }

  List<WalletTransaction> get _filtered {
    final query = _query.trim().toLowerCase();
    return _all.where((transaction) {
      final matchesQuery = query.isEmpty ||
          transaction.title.toLowerCase().contains(query) ||
          transaction.subtitle.toLowerCase().contains(query) ||
          _amountSearchText(transaction).toLowerCase().contains(query);
      final matchesFilter = switch (_filter) {
        _Filter.all => true,
        _Filter.credit => transaction.type == TxType.credit,
        _Filter.debit => transaction.type == TxType.debit,
      };
      return matchesQuery && matchesFilter;
    }).toList();
  }

  String _statusLabel(TxStatus status) => switch (status) {
        TxStatus.completed => 'Completed',
        TxStatus.pending => 'Pending',
        TxStatus.rejected => 'Rejected',
      };

  DateTime _localDate(DateTime date) => date.toLocal();

  String _friendlyDate(DateTime date) =>
      DateFormat('MMM d, yyyy · h:mm a').format(_localDate(date));

  bool _isCashOut(WalletTransaction transaction) {
    final description = '${transaction.title} ${transaction.subtitle}'
        .toLowerCase()
        .replaceAll('-', ' ');
    return description.contains('cash out') || description.contains('cashout');
  }

  List<Widget> _grouped(List<WalletTransaction> transactions) {
    final groups = <String, List<WalletTransaction>>{};
    for (final transaction in transactions) {
      final key =
          DateFormat('MMMM yyyy').format(_localDate(transaction.createdAt));
      groups.putIfAbsent(key, () => []).add(transaction);
    }

    return [
      for (final entry in groups.entries) ...[
        Padding(
          padding: const EdgeInsets.only(top: 24, bottom: 10),
          child: SectionLabel(entry.key.toUpperCase()),
        ),
        _monthCard(entry.value),
      ],
    ];
  }

  Widget _monthCard(List<WalletTransaction> transactions) {
    return AppCard(
      radius: 22,
      shadow: true,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          for (var index = 0; index < transactions.length; index++) ...[
            if (index > 0) Divider(height: 1, color: context.colors.borderSoft),
            _transactionRow(transactions[index]),
          ],
        ],
      ),
    );
  }

  Widget _transactionRow(WalletTransaction transaction) {
    final isCredit = transaction.type == TxType.credit;
    final isPending = transaction.status == TxStatus.pending;
    final isCashOut = !isCredit && _isCashOut(transaction);
    final statusColor = isPending
        ? context.colors.warningText
        : transaction.status == TxStatus.rejected
            ? context.colors.dangerText
            : isCredit
                ? context.colors.successText
                : context.colors.brand;
    final statusBackground = isPending
        ? context.colors.warningBg
        : transaction.status == TxStatus.rejected
            ? context.colors.dangerBg
            : isCredit
                ? context.colors.successBg
                : context.colors.brandTint;
    final chipLabel =
        isCashOut ? 'Simulated' : _statusLabel(transaction.status);
    final amount = '${isCredit ? '+' : '-'}${fmtPhp(transaction.amount.abs())}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color:
                  isCredit ? context.colors.successBg : context.colors.dangerBg,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              isCredit ? AppIcons.arrowDown : AppIcons.arrowUpRight,
              color: isCredit
                  ? context.colors.successText
                  : context.colors.dangerText,
              size: 23,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _friendlyDate(transaction.createdAt),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.colors.textBody,
                    fontSize: 12,
                  ),
                ),
                if (transaction.subtitle.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    transaction.subtitle.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.colors.textBody,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 112,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      isPending ? 'Pending' : amount,
                      maxLines: 1,
                      style: TextStyle(
                        color: isPending
                            ? context.colors.textBody
                            : isCredit
                                ? context.colors.successText
                                : context.colors.dangerText,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                StatusChip(
                  chipLabel,
                  color: statusColor,
                  bg: statusBackground,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryHalf({
    required String label,
    required double total,
    required bool credit,
  }) {
    final color =
        credit ? context.colors.successText : context.colors.dangerText;
    final tileColor =
        credit ? context.colors.successBg : context.colors.dangerBg;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
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
            child: Icon(
              credit ? AppIcons.arrowDown : AppIcons.arrowUpRight,
              color: color,
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.colors.textBody,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'PHP ${fmtPhp(total)}',
                      maxLines: 1,
                      style: TextStyle(
                        color: color,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(List<WalletTransaction> transactions) {
    final credits = transactions
        .where((transaction) => transaction.type == TxType.credit)
        .fold<double>(0, (sum, transaction) => sum + transaction.amount.abs());
    final debits = transactions
        .where((transaction) => transaction.type == TxType.debit)
        .fold<double>(0, (sum, transaction) => sum + transaction.amount.abs());

    return AppCard(
      radius: 22,
      shadow: true,
      padding: EdgeInsets.zero,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _summaryHalf(
                label: 'Received',
                total: credits,
                credit: true,
              ),
            ),
            VerticalDivider(width: 1, color: context.colors.borderSoft),
            Expanded(
              child: _summaryHalf(
                label: 'Cashed out',
                total: debits,
                credit: false,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyCard({
    required String title,
    required String message,
    bool noTransactions = false,
    bool showClear = false,
  }) {
    return AppCard(
      radius: 22,
      shadow: true,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: context.colors.brandTint,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  AppIcons.receipt,
                  color: context.colors.brand,
                  size: 38,
                ),
              ),
              Positioned(
                top: 0,
                right: 2,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: context.colors.avatarBackground,
                    shape: BoxShape.circle,
                    border: Border.all(color: context.colors.surface, width: 3),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.colors.textBody,
              fontSize: 14,
            ),
          ),
          if (noTransactions) ...[
            const SizedBox(height: 22),
            PrimaryButton(
              label: 'Scan payout QR',
              icon: AppIcons.qrScan,
              onPressed: _openScanner,
              minHeight: 54,
              borderRadius: 18,
            ),
          ],
          if (showClear) ...[
            const SizedBox(height: 14),
            SecondaryButton(
              label: 'Clear filters',
              onPressed: _clearFilters,
              minHeight: 48,
            ),
          ],
        ],
      ),
    );
  }

  void _clearFilters() {
    setState(() {
      _query = '';
      _searchController.clear();
      _filter = _Filter.all;
    });
  }

  Widget _filterChip(String label, _Filter filter) {
    final selected = _filter == filter;
    return SizedBox(
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
        onSelected: (_) => setState(() => _filter = filter),
        padding: EdgeInsets.zero,
        labelPadding: const EdgeInsets.symmetric(horizontal: 6),
        shape: const StadiumBorder(),
        side: BorderSide(
          color: selected ? context.colors.brand : context.colors.borderSoft,
        ),
        backgroundColor: context.colors.surface,
        selectedColor: context.colors.brand,
      ),
    );
  }

  Widget _loadingSkeleton() {
    return AppSkeletonizer(
      enabled: true,
      child: Column(
        children: [
          AppCard(
            radius: 22,
            child: Container(height: 80, color: Colors.white),
          ),
          const SizedBox(height: 22),
          AppCard(
            radius: 22,
            child: Column(
              children: [
                for (var index = 0; index < 3; index++) ...[
                  if (index > 0)
                    Divider(height: 1, color: context.colors.borderSoft),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            height: 16,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 18),
                        Container(width: 80, height: 16, color: Colors.white),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
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
    final filtered = _filtered;
    final hasFilters = _query.trim().isNotEmpty || _filter != _Filter.all;

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        leadingWidth: 60,
        leading: _roundBackButton(),
        centerTitle: true,
        title: Text(
          'Transaction History',
          style: TextStyle(
            color: context.colors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: context.colors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: SearchField(
              controller: _searchController,
              hintText: 'Search transactions',
              radius: 18,
              minHeight: 52,
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
                        size: 18,
                        color: context.colors.textBody,
                      ),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Row(
              children: [
                Expanded(child: _filterChip('All', _Filter.all)),
                const SizedBox(width: 10),
                Expanded(child: _filterChip('Credits', _Filter.credit)),
                const SizedBox(width: 10),
                Expanded(child: _filterChip('Debits', _Filter.debit)),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: ClipRect(
              child: ScrollConfiguration(
                behavior: const _HistoryScrollBehavior(),
                child: RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    clipBehavior: Clip.hardEdge,
                    physics: const ClampingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    children: [
                      if (_loading)
                        _loadingSkeleton()
                      else if (_error != null)
                        ErrorCard(
                          message: _error!,
                          onRetry: _retry,
                        )
                      else if (_all.isEmpty)
                        _emptyCard(
                          title: 'No transactions yet',
                          message:
                              'Your allowance and cash-outs will appear here.',
                          noTransactions: true,
                        )
                      else if (filtered.isEmpty)
                        _emptyCard(
                          title: 'No matching transactions',
                          message:
                              'Try a different search or transaction type.',
                          showClear: hasFilters,
                        )
                      else ...[
                        _summaryCard(filtered),
                        ..._grouped(filtered),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryScrollBehavior extends MaterialScrollBehavior {
  const _HistoryScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) =>
      child;
}
