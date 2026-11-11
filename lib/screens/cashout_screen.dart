import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../services/wallet_service.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';
import '../widgets/app_icons.dart';
import '../widgets/success_animation.dart';
import 'fingerprint_screen.dart';
import 'linked_accounts_screen.dart';

/// Scholar: Cash Out.
/// MOCKUP / DEMO: pick a linked account, enter the amount, review, confirm
/// with device biometrics. The transfer is simulated: the balance is reduced
/// and a simulated reference is shown. No real money moves.
class CashoutScreen extends StatefulWidget {
  const CashoutScreen({super.key});
  @override
  State<CashoutScreen> createState() => _CashoutScreenState();
}

class _CashoutScreenState extends State<CashoutScreen> {
  final _amount = TextEditingController();
  List<LinkedAccount> _accounts = [];
  List<Withdrawal> _history = [];
  int? _selected;
  bool _loading = true;
  bool _busy = false;
  bool _showSuccessAnimation = false;
  Timer? _successAnimationTimer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _successAnimationTimer?.cancel();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final state = context.read<AppState>();
    try {
      final user = state.user ?? await state.auth.currentAppUser();
      if (user == null) {
        if (!mounted) return;
        setState(() {
          _accounts = [];
          _history = [];
          _selected = null;
        });
        return;
      }
      state.user = user;
      await state.refreshBalance();
      final accounts = await state.wallet.getLinkedAccounts(user.id);
      final history = await state.wallet.getMyWithdrawals(user.id);
      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        _history = history;
        if (_selected == null || !accounts.any((a) => a.id == _selected)) {
          _selected = accounts.isEmpty ? null : accounts.first.id;
        }
      });
    } catch (_) {
      if (mounted) {
        showMsg(context, 'Could not load cash-out details.', error: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _manageAccounts() async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => const LinkedAccountsScreen()));
    _load();
  }

  Future<void> _submit() async {
    final state = context.read<AppState>();
    final amount = double.tryParse(_amount.text.trim());
    final acc = _accounts.where((a) => a.id == _selected).firstOrNull;
    if (acc == null) {
      showMsg(context, 'Link and select an account first.', error: true);
      return;
    }
    if (amount == null || amount < WalletService.minCashout) {
      showMsg(context,
          'Minimum cash-out is PHP ${fmtPhp(WalletService.minCashout)}.',
          error: true);
      return;
    }
    if (amount > state.balance) {
      showMsg(context, 'Amount is more than your balance.', error: true);
      return;
    }

    // Review screen: amount comes from the field, destination from the record.
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Review cash-out'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('PHP ${fmtPhp(amount)}',
                style:
                    const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Text('To: ${acc.providerLabel} ${acc.masked}'),
            Text('Name: ${acc.accountName}'),
            const SizedBox(height: 12),
            const Text(
                'DEMO ONLY: this is a simulation. The amount is deducted from '
                'your wallet balance, but no real money is sent to the account.'),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Back')),
          FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: Icon(
                AppIcons.fingerprint,
                color: context.colors.onHeader,
              ),
              label: const Text('Confirm')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    try {
      if (!state.fingerprintRegistered) {
        await Navigator.push<bool>(
            context,
            MaterialPageRoute(
                builder: (_) => const FingerprintScreen(required: true)));
        if (!mounted || !state.fingerprintRegistered) return;
      }
      final verified = await state
          .verifyFingerprint('Confirm cash-out: PHP ${fmtPhp(amount)}');
      if (!mounted) return;
      if (!verified) {
        throw WalletException('Biometrics not verified. Nothing was deducted.');
      }
      await state.wallet.requestWithdrawal(accountId: acc.id, amount: amount);
      _amount.clear();
      await _load();
      if (mounted) {
        _successAnimationTimer?.cancel();
        setState(() => _showSuccessAnimation = true);
        _successAnimationTimer = Timer(const Duration(seconds: 2), () {
          if (mounted) setState(() => _showSuccessAnimation = false);
        });
        showMsg(context, 'Demo cash-out completed. No real money was sent.');
      }
    } on WalletException catch (e) {
      if (mounted) showMsg(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Color _statusColor(WithdrawalStatus s) => switch (s) {
        WithdrawalStatus.completed => AppTheme.successGreen,
        WithdrawalStatus.pending => AppTheme.warningAmber,
        _ => AppTheme.dangerRed,
      };

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final amount = double.tryParse(_amount.text.trim());
    final amountError = _amount.text.trim().isEmpty
        ? null
        : amount == null || amount < WalletService.minCashout
            ? 'Minimum cash-out is PHP ${fmtPhp(WalletService.minCashout)}.'
            : amount > state.balance
                ? 'Amount is more than your balance.'
                : null;
    final canSubmit = !_busy && amount != null && amountError == null;
    final displayedAccounts = _loading
        ? [
            LinkedAccount(
              id: -1,
              provider: PayoutProvider.gcash,
              bankName: '',
              accountName: 'Account holder',
              accountNumber: '1234567890',
            ),
          ]
        : _accounts;
    final displayedHistory = _loading
        ? [
            Withdrawal(
              id: -1,
              scholarId: '',
              amount: 12345,
              provider: PayoutProvider.gcash,
              bankName: '',
              accountName: 'Account holder',
              accountNumber: '1234567890',
              status: WithdrawalStatus.pending,
              reference: 'ABC12345',
              adminNote: '',
              createdAt: DateTime(2026, 11, 8),
            ),
          ]
        : _history;

    void setAmount(double value) {
      final text = value.toStringAsFixed(2);
      setState(() {
        _amount.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
      });
    }

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
        title: const Text('Cash Out'),
        backgroundColor: context.colors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: Stack(
        children: [
          ScrollConfiguration(
            behavior: const _CashoutScrollBehavior(),
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const ClampingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  AppSkeletonizer(
                    enabled: _loading,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        BalanceCard(
                          balance: _loading ? 12345.67 : state.balance,
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: context.colors.warningBg,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: context.colors.surface.withValues(
                                    alpha: .75,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  AppIcons.demo,
                                  color: context.colors.textLabel,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Demo mode: Cash Out is a simulation. No real money is sent to GCash, Maya or a bank.',
                                  style: TextStyle(
                                    color: context.colors.textBody,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        SectionLabel(
                          'CASH OUT TO',
                          trailing: TextButton(
                            onPressed: _manageAccounts,
                            style: TextButton.styleFrom(
                              foregroundColor: context.colors.brand,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            child: const Text('Manage'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (displayedAccounts.isEmpty)
                          _accountCard(
                            context,
                            icon: AppIcons.link,
                            title: 'Link an account',
                            subtitle: 'GCash, Maya or bank',
                            onTap: _manageAccounts,
                          )
                        else
                          ...displayedAccounts.map((account) {
                            final selected = account.id == _selected;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _accountCard(
                                context,
                                icon: account.provider == PayoutProvider.bank
                                    ? AppIcons.bankAccount
                                    : AppIcons.phone,
                                title: account.accountName,
                                subtitle: account.masked,
                                selected: selected,
                                onTap: () =>
                                    setState(() => _selected = account.id),
                              ),
                            );
                          }),
                        const SizedBox(height: 8),
                        const SectionLabel('AMOUNT (PHP)'),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: context.colors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border:
                                Border.all(color: context.colors.borderSoft),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                controller: _amount,
                                onChanged: (_) => setState(() {}),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d*\.?\d{0,2}'),
                                  ),
                                ],
                                style: TextStyle(
                                  color: context.colors.textPrimary,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                                decoration: InputDecoration(
                                  isDense: true,
                                  filled: true,
                                  fillColor: context.colors.surface,
                                  prefixText: 'PHP ',
                                  prefixStyle: TextStyle(
                                    color: context.colors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                  hintText:
                                      'Minimum ${fmtPhp(WalletService.minCashout)}',
                                  hintStyle: TextStyle(
                                    color: context.colors.hint,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 14,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                      color: context.colors.borderSoft,
                                    ),
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
                              const SizedBox(height: 10),
                              Text(
                                'Available: PHP ${fmtPhp(state.balance)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.colors.textBody,
                                ),
                              ),
                              if (amountError != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  amountError,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _amountChip(
                                    context,
                                    '500',
                                    () => setAmount(500),
                                  ),
                                  _amountChip(
                                    context,
                                    '1,000',
                                    () => setAmount(1000),
                                  ),
                                  _amountChip(
                                    context,
                                    'Max',
                                    state.balance > 0
                                        ? () => setAmount(state.balance)
                                        : null,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: canSubmit ? _submit : null,
                            icon: _busy
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: context.colors.onHeader,
                                    ),
                                  )
                                : Icon(
                                    AppIcons.fingerprint,
                                    color: context.colors.onHeader,
                                  ),
                            label: const Text(
                              'Review and Cash Out',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: context.colors.brand,
                              foregroundColor: context.colors.onHeader,
                              disabledBackgroundColor:
                                  context.colors.borderSoft,
                              disabledForegroundColor: context.colors.hint,
                              minimumSize: const Size.fromHeight(52),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        SectionLabel(
                          'MY CASH-OUTS (${displayedHistory.length})',
                        ),
                        const SizedBox(height: 8),
                        if (displayedHistory.isEmpty)
                          _emptyHistoryCard(context)
                        else
                          ...displayedHistory.map((withdrawal) {
                            final statusColor = _statusColor(withdrawal.status);
                            final statusBackground =
                                switch (withdrawal.status) {
                              WithdrawalStatus.completed =>
                                context.colors.successBg,
                              WithdrawalStatus.pending =>
                                context.colors.warningBg,
                              _ => context.colors.dangerBg,
                            };
                            final statusLabel = switch (withdrawal.status) {
                              WithdrawalStatus.completed => 'Completed',
                              WithdrawalStatus.pending => 'Pending',
                              _ => 'Failed',
                            };
                            final lastFour = withdrawal.accountNumber.length > 4
                                ? '•••• ${withdrawal.accountNumber.substring(withdrawal.accountNumber.length - 4)}'
                                : withdrawal.accountNumber;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: context.colors.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: context.colors.borderSoft),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: context.colors.brandTint,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            withdrawal.provider ==
                                                    PayoutProvider.bank
                                                ? AppIcons.bankAccount
                                                : AppIcons.phone,
                                            color: context.colors.brand,
                                            size: 18,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${withdrawal.providerLabel} $lastFour',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: context
                                                      .colors.textPrimary,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                _fmtDate(withdrawal.createdAt),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color:
                                                      context.colors.textBody,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              if (withdrawal
                                                  .reference.isNotEmpty)
                                                Text(
                                                  'Simulated reference: ${withdrawal.reference}',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: context.colors.hint,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'PHP ${fmtPhp(withdrawal.amount)}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.end,
                                            style: TextStyle(
                                              color: context.colors.textPrimary,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        StatusChip(
                                          statusLabel,
                                          color: statusColor,
                                          bg: statusBackground,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_showSuccessAnimation)
            const Positioned.fill(
              child: IgnorePointer(
                child: Center(child: SuccessAnimation()),
              ),
            ),
        ],
      ),
    );
  }

  Widget _accountCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool selected = false,
  }) {
    return Material(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  selected ? context.colors.brand : context.colors.borderSoft,
              width: selected ? 1.5 : 1,
            ),
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
                child: Icon(icon, color: context.colors.brand),
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
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
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
              const SizedBox(width: 8),
              Icon(
                AppIcons.chevronRight,
                color: selected ? context.colors.brand : context.colors.hint,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _amountChip(
    BuildContext context,
    String label,
    VoidCallback? onPressed,
  ) {
    return SizedBox(
      height: 36,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: context.colors.textPrimary,
          side: BorderSide(color: context.colors.borderSoft),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: const StadiumBorder(),
        ),
        child: Text(label),
      ),
    );
  }

  Widget _emptyHistoryCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
              color: context.colors.brandTint,
              shape: BoxShape.circle,
            ),
            child: Icon(
              AppIcons.receipt,
              color: context.colors.brand,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No cash-outs yet',
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Your cash-outs will show up here',
                  style: TextStyle(
                    color: context.colors.textBody,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }
}

class _CashoutScrollBehavior extends MaterialScrollBehavior {
  const _CashoutScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) =>
      child;
}
