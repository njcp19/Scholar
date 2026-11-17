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
        if (mounted) {
          setState(() {
            _accounts = [];
            _error = null;
          });
        }
        return;
      }
      state.user = user;
      final list = await state.wallet.getLinkedAccounts(user.id);
      if (mounted) {
        setState(() {
          _accounts = list;
          _error = null;
        });
      }
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
        PayoutProvider.maya => context.colors.brand,
        PayoutProvider.bank => context.colors.brand,
      };

  Color _providerTint(PayoutProvider provider) => switch (provider) {
        PayoutProvider.gcash => context.colors.brandTint,
        PayoutProvider.maya => context.colors.brandTint,
        PayoutProvider.bank => context.colors.brandTint,
      };

  Future<void> _remove(LinkedAccount account) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        var removing = false;
        String? errorMessage;
        return StatefulBuilder(
          builder: (context, setDialogState) => ConfirmDialog(
            title: 'Remove this account?',
            message: '${account.accountName} · ${account.providerLabel} '
                '${account.masked} will be removed. You can link it again anytime.',
            confirmLabel: 'Remove',
            cancelLabel: 'Cancel',
            danger: true,
            icon: AppIcons.delete,
            loading: removing,
            errorMessage: errorMessage,
            onCancel: () => Navigator.pop(dialogContext, false),
            onConfirm: () async {
              if (removing) return;
              setDialogState(() => removing = true);
              try {
                await context.read<AppState>().wallet.unlinkAccount(account.id);
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext, true);
                }
              } on WalletException catch (error) {
                if (dialogContext.mounted) {
                  setDialogState(() {
                    removing = false;
                    errorMessage = error.message;
                  });
                }
              }
            },
          ),
        );
      },
    );
    if (ok == true && mounted) {
      await _load();
      if (mounted) showMsg(context, 'Account removed.');
    }
  }

  Future<void> _add() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface.withValues(alpha: 0),
      barrierColor: context.colors.scanGradientStart.withValues(alpha: .64),
      builder: (_) => const _AddAccountSheet(),
    );
    if (added == true) {
      await _load();
      if (mounted) showMsg(context, 'Account linked.');
    }
  }

  Widget _infoCard() {
    return InfoBanner(
      icon: AppIcons.info,
      message: 'Link the GCash, Maya or bank account that will receive your '
          'cash-outs. It must be registered in your own name.',
      maxLines: 8,
      backgroundColor: context.colors.brandTint,
      textColor: Theme.of(context).brightness == Brightness.dark
          ? context.colors.textBody
          : context.colors.brand,
      borderRadius: 24,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: context.colors.surface,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(
          AppIcons.info,
          color: context.colors.brand,
          size: 21,
        ),
      ),
    );
  }

  Widget _accountCard(LinkedAccount account) {
    final color = _providerColor(account.provider);
    return AppCard(
      padding: const EdgeInsets.all(16),
      radius: 24,
      shadow: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _providerTint(account.provider),
              borderRadius: BorderRadius.circular(18),
            ),
            alignment: Alignment.center,
            child: Icon(
              _icon(account.provider),
              color: color,
              size: 26,
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
                  '${account.providerLabel} · ${account.masked}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.colors.textBody,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Account actions',
            position: PopupMenuPosition.under,
            offset: const Offset(0, 8),
            color: context.colors.surface,
            elevation: 10,
            shadowColor: context.colors.cardShadow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: context.colors.borderSoft),
            ),
            constraints: const BoxConstraints(minWidth: 150),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: context.colors.brandTint.withValues(alpha: .65),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(AppIcons.menu, color: context.colors.textBody),
            ),
            onSelected: (action) {
              if (action == 'remove') _remove(account);
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'remove',
                padding: const EdgeInsets.all(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: context.colors.dangerBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(AppIcons.delete, color: context.colors.dangerText),
                      const SizedBox(width: 10),
                      Text(
                        'Remove',
                        style: TextStyle(
                          color: context.colors.dangerText,
                          fontWeight: FontWeight.w700,
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

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 52, horizontal: 12),
      child: EmptyState(
        icon: AppIcons.link,
        iconContainerSize: 72,
        iconSize: 28,
        iconColor: context.colors.brand,
        titleFontSize: 20,
        messageFontSize: 15,
        title: 'No linked accounts yet',
        message: 'Link an account to receive your cash-outs.',
      ),
    );
  }

  Widget _errorCard() {
    return ErrorCard(
      message: _error ?? 'Could not load linked accounts.',
      onRetry: _retryLoad,
    );
  }

  Future<void> _retryLoad() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        leadingWidth: 62,
        leading: Padding(
          padding: const EdgeInsets.only(left: 20),
          child: IconButton(
            onPressed: () => Navigator.maybePop(context),
            style: IconButton.styleFrom(
              fixedSize: const Size(42, 42),
              padding: EdgeInsets.zero,
              backgroundColor: context.colors.surface,
              foregroundColor: context.colors.textPrimary,
              shape: const CircleBorder(),
              side: BorderSide(color: context.colors.borderSoft),
            ),
            icon: const Icon(AppIcons.back, size: 22),
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
                              ..._accounts.expand(
                                (account) => [
                                  _accountCard(account),
                                  const SizedBox(height: 16),
                                ],
                              ),
                          ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: PrimaryButton(
              label: 'Link account',
              onPressed: _add,
              icon: AppIcons.plus,
              minHeight: 56,
              borderRadius: 20,
              shadow: true,
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
  final _nameFocus = FocusNode();
  final _numberFocus = FocusNode();
  final _bankFocus = FocusNode();
  bool _busy = false;
  bool _showAllErrors = false;
  bool _nameTouched = false;
  bool _numberTouched = false;
  bool _bankTouched = false;
  bool _resettingProviderFields = false;
  bool _nameHadFocus = false;
  bool _numberHadFocus = false;
  bool _bankHadFocus = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _nameFocus.addListener(_nameFocusChanged);
    _numberFocus.addListener(_numberFocusChanged);
    _bankFocus.addListener(_bankFocusChanged);
  }

  @override
  void dispose() {
    _name.dispose();
    _number.dispose();
    _bank.dispose();
    _nameFocus.dispose();
    _numberFocus.dispose();
    _bankFocus.dispose();
    super.dispose();
  }

  void _nameFocusChanged() {
    if (_nameFocus.hasFocus) {
      _nameHadFocus = true;
    } else if (_nameHadFocus) {
      _nameHadFocus = false;
      _touchName();
    }
  }

  void _numberFocusChanged() {
    if (_numberFocus.hasFocus) {
      _numberHadFocus = true;
    } else if (_numberHadFocus) {
      _numberHadFocus = false;
      _touchNumber();
    }
  }

  void _bankFocusChanged() {
    if (_bankFocus.hasFocus) {
      _bankHadFocus = true;
    } else if (_bankHadFocus) {
      _bankHadFocus = false;
      if (_provider == PayoutProvider.bank) _touchBank();
    }
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
    if (_busy) return;
    setState(() {
      _showAllErrors = true;
      _saveError = null;
    });
    if (!_isValid) return;

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
      if (mounted) setState(() => _saveError = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _selectProvider(PayoutProvider provider) {
    if (_provider == provider) return;
    _resettingProviderFields = true;
    _number.clear();
    _bank.clear();
    _resettingProviderFields = false;
    setState(() {
      _provider = provider;
      _numberTouched = false;
      _bankTouched = false;
      _showAllErrors = false;
      _saveError = null;
    });
  }

  void _touchName() {
    if (_resettingProviderFields) return;
    setState(() => _nameTouched = true);
  }

  void _touchNumber() {
    if (_resettingProviderFields) return;
    setState(() => _numberTouched = true);
  }

  void _touchBank() {
    if (_resettingProviderFields) return;
    setState(() => _bankTouched = true);
  }

  void _nameChanged() {
    if (_resettingProviderFields) return;
    setState(() {
      _nameTouched = true;
      _saveError = null;
    });
  }

  void _numberChanged() {
    if (_resettingProviderFields) return;
    setState(() {
      _numberTouched = true;
      _saveError = null;
    });
  }

  void _bankChanged() {
    if (_resettingProviderFields) return;
    setState(() {
      _bankTouched = true;
      _saveError = null;
    });
  }

  Widget _providerTile(
    PayoutProvider provider,
    String label,
    IconData icon,
  ) {
    final colors = context.colors;
    final selected = _provider == provider;
    final providerColor = switch (provider) {
      PayoutProvider.gcash => colors.brand,
      PayoutProvider.maya => colors.successText,
      PayoutProvider.bank => colors.warningText,
    };
    final providerTint = switch (provider) {
      PayoutProvider.gcash => colors.brandTint,
      PayoutProvider.maya => colors.successBg,
      PayoutProvider.bank => colors.warningBg,
    };
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: context.colors.surface.withValues(alpha: 0),
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: () => _selectProvider(provider),
          borderRadius: BorderRadius.circular(22),
          child: Container(
            constraints: const BoxConstraints(minHeight: 100),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? colors.brandTint : colors.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: selected ? colors.brand : colors.borderSoft,
                width: selected ? 2 : 1,
              ),
            ),
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: selected ? colors.brand : providerTint,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          icon,
                          size: 25,
                          color: selected ? colors.onHeader : providerColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected ? colors.brand : colors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: colors.brand,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        AppIcons.check,
                        color: colors.onHeader,
                        size: 13,
                      ),
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
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required IconData icon,
    required String hint,
    required String? error,
    required ValueChanged<String> onChanged,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
  }) {
    final colors = context.colors;
    final borderColor = error == null ? colors.borderSoft : colors.dangerText;
    OutlineInputBorder border({double width = 1}) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: borderColor, width: width),
        );

    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      style: TextStyle(color: colors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: colors.hint, fontSize: 14),
        prefixIcon: Icon(icon, size: 20, color: colors.textBody),
        filled: true,
        fillColor: colors.surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 15,
        ),
        border: border(),
        enabledBorder: border(),
        focusedBorder: error == null
            ? OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: colors.brand, width: 2),
              )
            : border(width: 1.5),
        errorBorder: border(width: 1.5),
        focusedErrorBorder: border(width: 2),
      ),
    );
  }

  Widget _validationError(String? error) {
    if (error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 2),
      child: Text(
        error,
        style: TextStyle(
          color: context.colors.dangerText,
          fontSize: 14,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final numberLabel = _provider.isMobile
        ? '${_provider.label} mobile number (09XXXXXXXXX)'
        : 'Account number';
    final numberHint =
        _provider.isMobile ? '09XXXXXXXXXX' : 'Enter account number';
    final errorBg = colors.dangerBg;

    return AppBottomSheet(
      title: 'Link an account',
      radius: 32,
      maxHeightFactor: .92,
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      showDragHandle: true,
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Link an account',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Choose where your cash-outs will go.',
            style: TextStyle(color: colors.textBody, fontSize: 16),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _providerTile(
                  PayoutProvider.gcash,
                  'GCash',
                  AppIcons.phone,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _providerTile(
                  PayoutProvider.maya,
                  'Maya',
                  AppIcons.wallet,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _providerTile(
                  PayoutProvider.bank,
                  'Bank',
                  AppIcons.bankAccount,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (_provider == PayoutProvider.bank) ...[
            _fieldLabel('Bank name'),
            _textField(
              controller: _bank,
              focusNode: _bankFocus,
              icon: AppIcons.bankAccount,
              hint: 'Enter bank name',
              error: (_showAllErrors || _bankTouched) ? _bankError : null,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => _bankChanged(),
            ),
            _validationError(
              (_showAllErrors || _bankTouched) ? _bankError : null,
            ),
            const SizedBox(height: 16),
          ],
          _fieldLabel('Account name'),
          _textField(
            controller: _name,
            focusNode: _nameFocus,
            icon: AppIcons.user,
            hint: 'Exactly as registered',
            error: (_showAllErrors || _nameTouched) ? _nameError : null,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => _nameChanged(),
          ),
          _validationError(
            (_showAllErrors || _nameTouched) ? _nameError : null,
          ),
          const SizedBox(height: 16),
          _fieldLabel(numberLabel),
          _textField(
            controller: _number,
            focusNode: _numberFocus,
            icon: _provider.isMobile ? AppIcons.phone : AppIcons.hash,
            hint: numberHint,
            error: (_showAllErrors || _numberTouched) ? _numberError : null,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(_provider.isMobile ? 11 : 20),
            ],
            onChanged: (_) => _numberChanged(),
          ),
          _validationError(
            (_showAllErrors || _numberTouched) ? _numberError : null,
          ),
          if (_saveError != null) ...[
            const SizedBox(height: 14),
            InfoBanner(
              icon: AppIcons.error,
              message: _saveError!,
              maxLines: 3,
              backgroundColor: errorBg,
              iconColor: colors.dangerText,
              textColor: colors.dangerText,
              borderRadius: 16,
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Icon(AppIcons.lock, color: colors.textBody, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Your details are used only for cash-outs.',
                  style: TextStyle(color: colors.textBody, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          PrimaryButton(
            label: 'Save account',
            onPressed: _busy ? null : _save,
            loading: _busy,
            loadingLabel: 'Saving...',
            backgroundColor:
                _isValid ? colors.brand : colors.brand.withValues(alpha: .45),
            disabledBackgroundColor: colors.brand.withValues(alpha: .45),
            foregroundColor: colors.onHeader,
            disabledForegroundColor: colors.onHeader,
            minHeight: 56,
            borderRadius: 20,
            shadow: _isValid,
          ),
        ],
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
