import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../services/wallet_service.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';
import '../widgets/app_icons.dart';

/// Scholar: link, view and remove accounts used for Cash Out.
/// Linking only saves the details; no money moves and nothing is verified
/// with GCash, Maya or the bank in this version.
class LinkedAccountsScreen extends StatefulWidget {
  const LinkedAccountsScreen({super.key});
  @override
  State<LinkedAccountsScreen> createState() => _LinkedAccountsScreenState();
}

class _LinkedAccountsScreenState extends State<LinkedAccountsScreen> {
  List<LinkedAccount> _accounts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final state = context.read<AppState>();
    try {
      final user = state.user ?? await state.auth.currentAppUser();
      if (user == null) {
        if (mounted) setState(() => _accounts = []);
        return;
      }
      state.user = user;
      final list = await state.wallet.getLinkedAccounts(user.id);
      if (mounted) setState(() => _accounts = list);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not load linked accounts.');
        showMsg(context, 'Could not load linked accounts.', error: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  IconData _icon(PayoutProvider provider) => switch (provider) {
        PayoutProvider.gcash => AppIcons.phone,
        PayoutProvider.maya => AppIcons.wallet,
        PayoutProvider.bank => AppIcons.bankAccount,
      };

  Color _providerColor(PayoutProvider provider) => switch (provider) {
        PayoutProvider.gcash => context.colors.brand,
        PayoutProvider.maya => context.colors.textLabel,
        PayoutProvider.bank => context.colors.textPrimary,
      };

  Color _providerTint(PayoutProvider provider) => switch (provider) {
        PayoutProvider.gcash => context.colors.brandTint,
        PayoutProvider.maya => context.colors.successBg,
        PayoutProvider.bank => context.colors.brandTint,
      };

  Future<void> _remove(LinkedAccount account) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove linked account?'),
        content: Text('${account.providerLabel} ${account.masked} will be '
            'removed. Past cash-outs are not affected.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<AppState>().wallet.unlinkAccount(account.id);
      await _load();
    } on WalletException catch (e) {
      if (mounted) showMsg(context, e.message, error: true);
    }
  }

  Future<void> _add() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _AddAccountSheet(),
    );
    if (added == true) {
      await _load();
      if (mounted) showMsg(context, 'Account linked.');
    }
  }

  Widget _infoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.brandTint,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: context.colors.surface.withValues(alpha: .75),
              shape: BoxShape.circle,
            ),
            child: Icon(
              AppIcons.info,
              color: context.colors.brand,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Link the GCash, Maya or bank account that will receive your '
              'cash-outs. It must be registered in your own name.',
              style: TextStyle(
                color: context.colors.textBody,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _accountCard(LinkedAccount account) {
    final color = _providerColor(account.provider);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.borderSoft),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _providerTint(account.provider),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _icon(account.provider),
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.accountName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${account.providerLabel} - ${account.masked}',
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
          PopupMenuButton<String>(
            tooltip: 'Account actions',
            icon: Icon(AppIcons.menu, color: context.colors.textBody),
            onSelected: (action) {
              if (action == 'remove') _remove(account);
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'remove',
                child: Row(
                  children: [
                    Icon(
                      AppIcons.delete,
                      color: context.colors.textPrimary,
                    ),
                    const SizedBox(width: 10),
                    const Text('Remove'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 52, horizontal: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: context.colors.brandTint,
              shape: BoxShape.circle,
            ),
            child: Icon(
              AppIcons.wallet,
              color: context.colors.brand,
              size: 24,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No linked accounts yet',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Link an account to receive your cash-outs.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.colors.textBody, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _errorCard() {
    return Container(
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
                  _error ?? 'Could not load linked accounts.',
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

  @override
  Widget build(BuildContext context) {
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
        title: const Text('Linked Accounts'),
        backgroundColor: context.colors.background,
        foregroundColor: context.colors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ClipRect(
              child: ScrollConfiguration(
                behavior: const _LinkedAccountsScrollBehavior(),
                child: RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    clipBehavior: Clip.hardEdge,
                    physics: const ClampingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    children: _loading
                        ? [
                            AppSkeletonizer(
                              enabled: true,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _infoCard(),
                                  const SizedBox(height: 16),
                                  _accountCard(
                                    LinkedAccount(
                                      id: -1,
                                      provider: PayoutProvider.gcash,
                                      bankName: '',
                                      accountName: 'Account holder',
                                      accountNumber: '1234567890',
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _accountCard(
                                    LinkedAccount(
                                      id: -2,
                                      provider: PayoutProvider.bank,
                                      bankName: 'Bank',
                                      accountName: 'Account holder',
                                      accountNumber: '1234567890',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ]
                        : [
                            _infoCard(),
                            const SizedBox(height: 16),
                            if (_error != null)
                              _errorCard()
                            else if (_accounts.isEmpty)
                              _emptyState()
                            else
                              ..._accounts.map(_accountCard),
                          ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _add,
                icon: Icon(
                  AppIcons.plus,
                  color: context.colors.onHeader,
                ),
                label: const Text('Link account'),
                style: FilledButton.styleFrom(
                  backgroundColor: context.colors.brand,
                  foregroundColor: context.colors.onHeader,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
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

class _AddAccountSheet extends StatefulWidget {
  const _AddAccountSheet();
  @override
  State<_AddAccountSheet> createState() => _AddAccountSheetState();
}

class _AddAccountSheetState extends State<_AddAccountSheet> {
  PayoutProvider _provider = PayoutProvider.gcash;
  final _name = TextEditingController();
  final _number = TextEditingController();
  final _bank = TextEditingController();
  bool _busy = false;
  bool _showValidation = true;

  @override
  void dispose() {
    _name.dispose();
    _number.dispose();
    _bank.dispose();
    super.dispose();
  }

  String get _digits => _number.text.replaceAll(RegExp(r'[^0-9]'), '');

  String? get _nameError => _name.text.trim().length < 2
      ? 'Enter the name registered on the account.'
      : null;

  String? get _bankError =>
      _provider == PayoutProvider.bank && _bank.text.trim().length < 2
          ? 'Enter the bank name.'
          : null;

  String? get _numberError {
    if (_provider.isMobile) {
      return RegExp(r'^09\d{9}$').hasMatch(_digits)
          ? null
          : 'Enter an 11-digit mobile number that starts with 09.';
    }
    return _digits.length >= 8 ? null : 'Enter a valid account number.';
  }

  bool get _isValid =>
      _nameError == null && _bankError == null && _numberError == null;

  Future<void> _save() async {
    setState(() => _showValidation = true);
    if (!_isValid || _busy) return;

    setState(() => _busy = true);
    try {
      await context.read<AppState>().wallet.linkAccount(
            provider: _provider,
            bankName: _bank.text,
            accountName: _name.text,
            accountNumber: _digits,
          );
      if (mounted) Navigator.pop(context, true);
    } on WalletException catch (e) {
      if (mounted) showMsg(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _providerTile(
    PayoutProvider provider,
    String label,
    IconData icon,
  ) {
    final selected = _provider == provider;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: GestureDetector(
          onTap: () => setState(() => _provider = provider),
          child: Container(
            height: 68,
            decoration: BoxDecoration(
              color:
                  selected ? context.colors.brandTint : context.colors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color:
                    selected ? context.colors.brand : context.colors.borderSoft,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: 22,
                        color: selected
                            ? context.colors.brand
                            : context.colors.textBody,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected
                              ? context.colors.brand
                              : context.colors.textBody,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Icon(
                      AppIcons.checkCircle,
                      color: context.colors.brand,
                      size: 15,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          color: context.colors.textLabel,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    required ValueChanged<String> onChanged,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      style: TextStyle(color: context.colors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: context.colors.hint, fontSize: 14),
        prefixIcon: Icon(icon, size: 20, color: context.colors.hint),
        filled: true,
        fillColor: context.colors.surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 15,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: context.colors.borderSoft),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: context.colors.brand, width: 1.5),
        ),
      ),
    );
  }

  Widget _validationError(String? error) {
    if (!_showValidation || error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 5, left: 2),
      child: Text(
        error,
        style: const TextStyle(color: AppTheme.dangerRed, fontSize: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final numberLabel = _provider.isMobile
        ? '${_provider.label} mobile number (09XXXXXXXXX)'
        : 'Account number';
    final numberHint =
        _provider.isMobile ? '09XXXXXXXXX' : 'Enter account number';

    return SafeArea(
      top: false,
      child: Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(top: 10, bottom: 20),
                    decoration: BoxDecoration(
                      color: context.colors.hint.withValues(alpha: .55),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Text(
                  'Link an account',
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose where your cash-outs will go',
                  style: TextStyle(
                    color: context.colors.textBody,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    _providerTile(
                      PayoutProvider.gcash,
                      'GCash',
                      AppIcons.phone,
                    ),
                    const SizedBox(width: 8),
                    _providerTile(
                      PayoutProvider.maya,
                      'Maya',
                      AppIcons.wallet,
                    ),
                    const SizedBox(width: 8),
                    _providerTile(
                      PayoutProvider.bank,
                      'Bank',
                      AppIcons.bankAccount,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_provider == PayoutProvider.bank) ...[
                  _fieldLabel('Bank name'),
                  _textField(
                    controller: _bank,
                    icon: AppIcons.bankAccount,
                    hint: 'Enter bank name',
                    textCapitalization: TextCapitalization.words,
                    onChanged: (_) => setState(() {}),
                  ),
                  _validationError(_bankError),
                  const SizedBox(height: 14),
                ],
                _fieldLabel('Account name'),
                _textField(
                  controller: _name,
                  icon: AppIcons.user,
                  hint: 'Exactly as registered',
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) => setState(() {}),
                ),
                _validationError(_nameError),
                const SizedBox(height: 14),
                _fieldLabel(numberLabel),
                _textField(
                  controller: _number,
                  icon: _provider.isMobile ? AppIcons.phone : AppIcons.hash,
                  hint: numberHint,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(20),
                  ],
                  onChanged: (_) => setState(() {}),
                ),
                _validationError(_numberError),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      AppIcons.lock,
                      color: context.colors.hint,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Your details are used only for cash-outs.',
                        style: TextStyle(
                          color: context.colors.textBody,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: !_busy && _isValid ? _save : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: context.colors.brand,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          context.colors.brand.withValues(alpha: .45),
                      disabledForegroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Save account'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LinkedAccountsScrollBehavior extends MaterialScrollBehavior {
  const _LinkedAccountsScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) =>
      child;
}
