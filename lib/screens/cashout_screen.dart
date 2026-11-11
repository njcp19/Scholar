import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_state.dart';
import '../services/wallet_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icons.dart';
import '../widgets/success_animation.dart';
import '../widgets/widgets.dart';
import 'fingerprint_screen.dart';
import 'linked_accounts_screen.dart';

/// Scholar: Cash Out.
/// The transfer is simulated: the balance is reduced and a reference is shown.
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
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LinkedAccountsScreen()),
    );
    _load();
  }

  Future<void> _selectAccount() async {
    if (_accounts.length < 2) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => AppBottomSheet(
        title: 'Choose an account',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final account in _accounts) ...[
              if (account != _accounts.first) const SizedBox(height: 10),
              _accountCard(
                account,
                selected: account.id == _selected,
                onTap: () {
                  setState(() => _selected = account.id);
                  Navigator.pop(sheetContext);
                },
              ),
            ],
          ],
        ),
      ),
    );
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
      showMsg(
        context,
        'Minimum cash-out is PHP ${fmtPhp(WalletService.minCashout)}.',
        error: true,
      );
      return;
    }
    if (amount > state.balance) {
      showMsg(context, 'Amount is more than your balance.', error: true);
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => AppBottomSheet(
        title: 'Review Cash Out',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PHP ${fmtPhp(amount)}',
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'To: ${acc.providerLabel} ${acc.masked}',
              style: TextStyle(color: context.colors.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              'Name: ${acc.accountName}',
              style: TextStyle(color: context.colors.textBody),
            ),
            const SizedBox(height: 14),
            InfoBanner(
              icon: AppIcons.demo,
              message:
                  'Demo mode: The amount is deducted from your balance, but no real money is sent to the account.',
              emphasizedPrefix: 'Demo mode:',
              backgroundColor: context.colors.warningBg,
              iconColor: context.colors.warningText,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    label: 'Back',
                    onPressed: () => Navigator.pop(sheetContext, false),
                    minHeight: 50,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PrimaryButton(
                    label: 'Confirm',
                    icon: AppIcons.fingerprint,
                    onPressed: () => Navigator.pop(sheetContext, true),
                    minHeight: 50,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    try {
      if (!state.fingerprintRegistered) {
        await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => const FingerprintScreen(required: true),
          ),
        );
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

  Widget _balanceHero(double balance) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
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
              top: -116,
              right: -42,
              child: _circle(
                context.colors.onGold.withValues(alpha: .1),
                230,
              ),
            ),
            Positioned(
              right: -115,
              bottom: -132,
              child: _circle(
                context.colors.onGold.withValues(alpha: .08),
                250,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AVAILABLE BALANCE',
                  style: TextStyle(
                    color: context.colors.balanceHeroText,
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
                          color: context.colors.balanceHeroText,
                          fontWeight: FontWeight.w800,
                        ),
                        children: [
                          const TextSpan(
                            text: 'PHP ',
                            style: TextStyle(fontSize: 24),
                          ),
                          TextSpan(
                            text: fmtPhp(balance),
                            style: const TextStyle(fontSize: 46),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ),
                ),
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

  Widget _accountCard(
    LinkedAccount account, {
    required bool selected,
    required VoidCallback onTap,
  }) {
    final icon = account.provider == PayoutProvider.bank
        ? AppIcons.bankAccount
        : AppIcons.phone;
    final subtitle = '${account.accountName} · ${account.masked}';
    return Material(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color:
                  selected ? context.colors.brand : context.colors.borderSoft,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: context.colors.brandTint,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: context.colors.brand, size: 23),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.providerLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.colors.textBody,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (selected)
                Icon(
                  AppIcons.checkCircle,
                  color: context.colors.brand,
                  size: 26,
                )
              else
                Icon(AppIcons.chevronRight, color: context.colors.hint),
            ],
          ),
        ),
      ),
    );
  }

  Widget _linkAccountCard() {
    return Material(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: _manageAccounts,
        child: CustomPaint(
          foregroundPainter: _DashedBorderPainter(
            color: context.colors.brand.withValues(alpha: .58),
            radius: 22,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: context.colors.brandTint,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Icon(AppIcons.plus, color: context.colors.brand),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Link an account',
                        style: TextStyle(
                          color: context.colors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'GCash, Maya or bank',
                        style: TextStyle(
                          color: context.colors.textBody,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(AppIcons.chevronRight, color: context.colors.textBody),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _amountCard({
    required double? amount,
    required String? error,
    required double balance,
  }) {
    return AppCard(
      radius: 22,
      shadow: true,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'PHP',
                style: TextStyle(
                  color: context.colors.textBody,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: TextField(
                  controller: _amount,
                  onChanged: (_) => setState(() {}),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,2}'),
                    ),
                  ],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _amount.text.trim().isEmpty
                        ? context.colors.hint
                        : context.colors.textPrimary,
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                  ),
                  decoration: InputDecoration(
                    hintText: '0.00',
                    hintStyle: TextStyle(color: context.colors.hint),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Available PHP ${fmtPhp(balance)} · Minimum PHP ${fmtPhp(WalletService.minCashout)}',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.colors.textBody, fontSize: 13),
          ),
          if (error != null) ...[
            const SizedBox(height: 6),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.colors.dangerText,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _amountChip(
                  label: '500',
                  selected: amount == 500,
                  onPressed: () => _setAmount(500),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _amountChip(
                  label: '1,000',
                  selected: amount == 1000,
                  onPressed: () => _setAmount(1000),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _amountChip(
                  label: 'Max',
                  selected: amount != null && amount == balance,
                  onPressed: balance > 0 ? () => _setAmount(balance) : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _setAmount(double value) {
    final text = value.toStringAsFixed(2);
    setState(() {
      _amount.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    });
  }

  Widget _amountChip({
    required String label,
    required bool selected,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor:
              selected ? context.colors.brand : context.colors.textBody,
          backgroundColor:
              selected ? context.colors.brandTint : context.colors.background,
          side: BorderSide(
            color: selected ? context.colors.brand : context.colors.borderSoft,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
        child: Text(label, maxLines: 1),
      ),
    );
  }

  String? _amountError(double? amount, double balance) {
    if (_amount.text.trim().isEmpty) return null;
    if (amount == null || amount < WalletService.minCashout) {
      return 'Minimum cash-out is PHP ${fmtPhp(WalletService.minCashout)}.';
    }
    if (amount > balance) return 'Amount is more than your balance.';
    return null;
  }

  String _disabledHint({
    required double balance,
    required double? amount,
    required String? error,
  }) {
    if (_accounts.isEmpty) {
      return 'Link an account and receive an allowance to cash out.';
    }
    if (balance < WalletService.minCashout) {
      return 'Receive an allowance of at least PHP ${fmtPhp(WalletService.minCashout)} to cash out.';
    }
    if (amount == null) {
      return 'Enter an amount of at least PHP ${fmtPhp(WalletService.minCashout)} to continue.';
    }
    if (error != null) return 'Enter an amount within your available balance.';
    return '';
  }

  Widget _emptyHistoryCard() {
    return AppCard(
      radius: 22,
      shadow: true,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: context.colors.brandTint,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(AppIcons.receipt, color: context.colors.brand),
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
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Your cash-outs will show up here',
                  style: TextStyle(
                    color: context.colors.textBody,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(WithdrawalStatus status) => switch (status) {
        WithdrawalStatus.completed => context.colors.successText,
        WithdrawalStatus.pending => context.colors.warningText,
        _ => context.colors.dangerText,
      };

  Color _statusBackground(WithdrawalStatus status) => switch (status) {
        WithdrawalStatus.completed => context.colors.successBg,
        WithdrawalStatus.pending => context.colors.warningBg,
        _ => context.colors.dangerBg,
      };

  Widget _withdrawalCard(Withdrawal withdrawal) {
    final statusColor = _statusColor(withdrawal.status);
    final lastFour = withdrawal.accountNumber.length > 4
        ? '•••• ${withdrawal.accountNumber.substring(withdrawal.accountNumber.length - 4)}'
        : withdrawal.accountNumber;
    final date = DateFormat('MMM d, yyyy · h:mm a')
        .format(withdrawal.createdAt.toLocal());
    final statusLabel = switch (withdrawal.status) {
      WithdrawalStatus.completed => 'Completed',
      WithdrawalStatus.pending => 'Pending',
      _ => 'Failed',
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ListRowCard(
        minHeight: 86,
        padding: const EdgeInsets.all(16),
        radius: 22,
        shadow: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: context.colors.dangerBg,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                AppIcons.arrowUpRight,
                color: context.colors.dangerText,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'To ${withdrawal.providerLabel}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$date · $lastFour',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.colors.textBody,
                      fontSize: 12,
                    ),
                  ),
                  if (withdrawal.reference.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      'Simulated reference: ${withdrawal.reference}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.colors.textBody,
                        fontSize: 11,
                      ),
                    ),
                  ],
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      StatusChip(
                        'Simulated',
                        color: context.colors.brand,
                        bg: context.colors.brandTint,
                      ),
                      StatusChip(
                        statusLabel,
                        color: statusColor,
                        bg: _statusBackground(withdrawal.status),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 102,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  '-${fmtPhp(withdrawal.amount)}',
                  maxLines: 1,
                  style: TextStyle(
                    color: context.colors.dangerText,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
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
                Container(width: 150, height: 14, color: Colors.white),
                const SizedBox(height: 12),
                Container(width: 230, height: 42, color: Colors.white),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            radius: 16,
            child: Container(height: 52, color: Colors.white),
          ),
          const SizedBox(height: 16),
          AppCard(
            radius: 22,
            child: Container(height: 58, color: Colors.white),
          ),
          const SizedBox(height: 16),
          AppCard(
            radius: 22,
            child: Container(height: 120, color: Colors.white),
          ),
          const SizedBox(height: 16),
          AppCard(
            radius: 22,
            child: Container(height: 52, color: Colors.white),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final amount = double.tryParse(_amount.text.trim());
    final amountError = _amountError(amount, state.balance);
    final selectedAccount =
        _accounts.where((account) => account.id == _selected).firstOrNull;
    final accountAvailable = selectedAccount != null;
    final canSubmit = !_loading &&
        !_busy &&
        accountAvailable &&
        state.balance >= WalletService.minCashout &&
        amount != null &&
        amountError == null;
    final disabledHint = _disabledHint(
      balance: state.balance,
      amount: amount,
      error: amountError,
    );

    return Scaffold(
      backgroundColor: context.colors.background,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: context.colors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leadingWidth: 60,
        leading: _roundBackButton(),
        title: Text(
          'Cash Out',
          style: TextStyle(
            color: context.colors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
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
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                children: [
                  if (_loading)
                    _loadingSkeleton()
                  else ...[
                    _balanceHero(state.balance),
                    const SizedBox(height: 16),
                    InfoBanner(
                      icon: AppIcons.demo,
                      message:
                          'Demo mode: Cash Out is a simulation. No real money is sent to GCash, Maya or a bank.',
                      emphasizedPrefix: 'Demo mode:',
                      backgroundColor: context.colors.warningBg,
                      iconColor: context.colors.warningText,
                    ),
                    const SizedBox(height: 22),
                    SectionLabel(
                      'CASH OUT TO',
                      trailing: TextButton(
                        onPressed: _manageAccounts,
                        style: TextButton.styleFrom(
                          foregroundColor: context.colors.brand,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: const Text('Manage'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_accounts.isEmpty)
                      _linkAccountCard()
                    else if (selectedAccount != null)
                      _accountCard(
                        selectedAccount,
                        selected: true,
                        onTap: _accounts.length > 1 ? _selectAccount : () {},
                      ),
                    const SizedBox(height: 22),
                    const SectionLabel('AMOUNT (PHP)'),
                    const SizedBox(height: 10),
                    _amountCard(
                      amount: amount,
                      error: amountError,
                      balance: state.balance,
                    ),
                    const SizedBox(height: 16),
                    PrimaryButton(
                      label: 'Review and Cash Out',
                      icon: AppIcons.arrowUpRight,
                      onPressed: canSubmit ? _submit : null,
                      loading: _busy,
                      minHeight: 56,
                      borderRadius: 18,
                      backgroundColor: context.colors.brand,
                      disabledBackgroundColor: context.colors.borderSoft,
                      disabledForegroundColor: context.colors.textBody,
                    ),
                    if (!canSubmit && disabledHint.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        disabledHint,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.colors.textBody,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    SectionLabel('MY CASH-OUTS (${_history.length})'),
                    const SizedBox(height: 10),
                    if (_history.isEmpty)
                      _emptyHistoryCard()
                    else
                      ..._history.map(_withdrawalCard),
                  ],
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
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;

  const _DashedBorderPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(radius),
        ),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + 7).clamp(0, metric.length).toDouble();
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + 5;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      color != oldDelegate.color || radius != oldDelegate.radius;
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
