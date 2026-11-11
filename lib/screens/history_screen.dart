import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_state.dart';
import '../models/models.dart';
import '../widgets/widgets.dart';
import '../widgets/app_icons.dart';

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

  String _friendlyDate(DateTime date) =>
      DateFormat('MMM d, h:mm a').format(date.toLocal());

  List<Widget> _grouped(List<WalletTransaction> transactions) {
    final widgets = <Widget>[];
    String? lastKey;
    for (final transaction in transactions) {
      final key =
          DateFormat('MMMM yyyy').format(transaction.createdAt.toLocal());
      if (key != lastKey) {
        lastKey = key;
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 24, bottom: 8),
            child: Text(
              key.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
                color: context.colors.hint,
              ),
            ),
          ),
        );
      }
      widgets.add(_transactionRow(transaction));
      widgets.add(const SizedBox(height: 8));
    }
    return widgets;
  }

  Widget _transactionRow(WalletTransaction transaction) {
    final isCredit = transaction.type == TxType.credit;
    final isPending = transaction.status == TxStatus.pending;
    final isReceipt =
        '${transaction.title} ${transaction.subtitle}'.toLowerCase().contains(
              'receipt',
            );
    final iconColor = isPending
        ? context.colors.hint
        : isReceipt
            ? context.colors.brand
            : context.colors.textLabel;
    final iconBackground = isPending
        ? context.colors.warningBg
        : isReceipt
            ? context.colors.brandTint
            : isCredit
                ? context.colors.successBg
                : context.colors.dangerBg;
    final amount = isPending
        ? 'Pending'
        : '${isCredit ? '+' : '-'}${fmtPhp(transaction.amount.abs())}';
    final amountColor = isPending
        ? context.colors.hint
        : isCredit
            ? AppTheme.successGreen
            : context.colors.textPrimary;
    final subtitle = [
      _statusLabel(transaction.status),
      _friendlyDate(transaction.createdAt),
      if (transaction.subtitle.trim().isNotEmpty) transaction.subtitle.trim(),
    ].join(' - ');

    return Container(
      constraints: const BoxConstraints(minHeight: 68),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.borderSoft),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBackground,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPending
                  ? AppIcons.clock
                  : isReceipt
                      ? AppIcons.receipt
                      : isCredit
                          ? AppIcons.plus
                          : AppIcons.minus,
              color: iconColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.colors.hint,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 104,
            child: Text(
              amount,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: amountColor,
                fontSize: isPending ? 12 : 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState({
    required String title,
    required String message,
    bool showClear = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: context.colors.brandTint,
              shape: BoxShape.circle,
            ),
            child: Icon(
              AppIcons.receipt,
              color: context.colors.brand,
              size: 24,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.colors.textBody, fontSize: 14),
          ),
          if (showClear) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: _clearFilters,
              child: const Text('Clear filters'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _errorCard() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.borderSoft),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: context.colors.dangerBg,
              shape: BoxShape.circle,
            ),
            child: Icon(
              AppIcons.error,
              color: context.colors.textLabel,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _error ?? 'Could not load transactions.',
                  style: TextStyle(
                    color: context.colors.textBody,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _load,
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
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
    return Expanded(
      child: SizedBox(
        height: 36,
        child: ChoiceChip(
          label: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected
                    ? context.colors.onHeader
                    : context.colors.textBody,
                fontSize: 12,
                fontWeight: FontWeight.w600,
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
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: Icon(
            AppIcons.back,
            color: context.colors.textPrimary,
          ),
        ),
        title: const Text('Transaction History'),
        backgroundColor: context.colors.background,
        foregroundColor: context.colors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: SizedBox(
              height: 48,
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: 'Search transactions',
                  hintStyle: TextStyle(color: context.colors.hint),
                  prefixIcon: Icon(
                    AppIcons.search,
                    size: 18,
                    color: context.colors.hint,
                  ),
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
                  filled: true,
                  fillColor: context.colors.surface,
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: context.colors.borderSoft),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: context.colors.brand,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(
              children: [
                _filterChip('All', _Filter.all),
                const SizedBox(width: 8),
                _filterChip('Credits', _Filter.credit),
                const SizedBox(width: 8),
                _filterChip('Debits', _Filter.debit),
              ],
            ),
          ),
          const SizedBox(height: 4),
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
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    children: _loading
                        ? [
                            AppSkeletonizer(
                              enabled: true,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: _grouped([
                                  WalletTransaction(
                                    id: 'loading-1',
                                    title: 'Allowance received',
                                    subtitle: 'Payout Event',
                                    amount: 12345,
                                    type: TxType.credit,
                                    status: TxStatus.completed,
                                    createdAt: DateTime(2026, 11, 8),
                                  ),
                                  WalletTransaction(
                                    id: 'loading-2',
                                    title: 'Cash Out',
                                    subtitle: 'Linked Account',
                                    amount: 2450,
                                    type: TxType.debit,
                                    status: TxStatus.completed,
                                    createdAt: DateTime(2026, 11, 7),
                                  ),
                                  WalletTransaction(
                                    id: 'loading-3',
                                    title: 'Allowance received',
                                    subtitle: 'Payout Event',
                                    amount: 12345,
                                    type: TxType.credit,
                                    status: TxStatus.completed,
                                    createdAt: DateTime(2026, 11, 1),
                                  ),
                                ]),
                              ),
                            ),
                          ]
                        : [
                            if (_error != null)
                              _errorCard()
                            else if (_all.isEmpty)
                              _emptyState(
                                title: 'No transactions yet',
                                message:
                                    'Your allowance and cash-outs will appear here',
                              )
                            else if (filtered.isEmpty)
                              _emptyState(
                                title: 'No matching transactions',
                                message:
                                    'Try a different search or transaction type.',
                                showClear: hasFilters,
                              )
                            else
                              ..._grouped(filtered),
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
