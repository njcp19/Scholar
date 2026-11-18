import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/app_state.dart';
import '../../services/wallet_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/widgets.dart';

class FundingAccountScreen extends StatefulWidget {
  const FundingAccountScreen({super.key});

  @override
  State<FundingAccountScreen> createState() => _FundingAccountScreenState();
}

class _FundingAccountScreenState extends State<FundingAccountScreen> {
  FundingAccount? _account;
  FundSummary? _summary;
  List<FundEntry> _entries = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool showLoading = false}) async {
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final wallet = context.read<AppState>().wallet;
      final results = await Future.wait<Object?>([
        wallet.getFundingAccount(),
        wallet.getFundSummary(),
        wallet.getFundActivity(),
      ]);
      if (!mounted) return;
      setState(() {
        _account = results[0] as FundingAccount?;
        _summary = results[1] as FundSummary;
        _entries = results[2] as List<FundEntry>;
        _error = null;
        _loading = false;
      });
    } on WalletException catch (error) {
      debugPrint('Funding account load failed: $error');
      _setLoadError(error.message);
    } on FormatException catch (error) {
      debugPrint('Funding account load failed: $error');
      _setLoadError(error.message);
    } on TypeError catch (error) {
      debugPrint('Funding account load failed: $error');
      _setLoadError('Could not read the funding account data: $error');
    } catch (error) {
      debugPrint('Funding account load failed: $error');
      _setLoadError('Could not load the funding account. Try again.');
    }
  }

  void _setLoadError(String message) {
    if (!mounted) return;
    setState(() {
      _error = message;
      _loading = false;
    });
  }

  Future<void> _openLinkSheet() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: context.colors.modalScrim.withValues(alpha: .55),
      sheetAnimationStyle: _sheetAnimationStyle(context),
      builder: (_) => _LinkFundingAccountSheet(account: _account),
    );
    if (result == true && mounted) await _load(showLoading: true);
  }

  Future<void> _openTopUpSheet() async {
    final account = _account;
    final summary = _summary;
    if (account == null || summary == null) return;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: context.colors.modalScrim.withValues(alpha: .55),
      sheetAnimationStyle: _sheetAnimationStyle(context),
      builder: (_) => _TopUpFundSheet(account: account, summary: summary),
    );
    if (result == true && mounted) await _load(showLoading: true);
  }

  AnimationStyle _sheetAnimationStyle(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimationStyle(
      duration:
          reduceMotion ? Duration.zero : const Duration(milliseconds: 250),
      reverseDuration:
          reduceMotion ? Duration.zero : const Duration(milliseconds: 200),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: colors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leadingWidth: 70,
        leading: Padding(
          padding: const EdgeInsets.only(left: 26),
          child: Material(
            color: colors.surface,
            shape: CircleBorder(side: BorderSide(color: colors.borderSoft)),
            child: IconButton(
              onPressed: () => Navigator.maybePop(context),
              tooltip: 'Back',
              constraints: const BoxConstraints.tightFor(width: 44, height: 44),
              padding: EdgeInsets.zero,
              icon: Icon(AppIcons.back, color: colors.textPrimary, size: 21),
            ),
          ),
        ),
        title: Text(
          'Funding account',
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? _loadingContent(context)
                : _error != null
                    ? _errorContent()
                    : _account == null
                        ? _notLinkedContent()
                        : _linkedContent(),
          ),
          if (!_loading && _error == null)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                child: PrimaryButton(
                  label: _account == null ? 'Link bank account' : 'Top up fund',
                  icon: _account == null ? AppIcons.link : AppIcons.plus,
                  minHeight: 56,
                  borderRadius: 18,
                  shadow: true,
                  onPressed:
                      _account == null ? _openLinkSheet : _openTopUpSheet,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _loadingContent(BuildContext context) {
    final colors = context.colors;
    return AppSkeletonizer(
      enabled: true,
      reduceMotion: MediaQuery.disableAnimationsOf(context),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          AppCard(
            radius: 28,
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 160, height: 14, color: colors.borderSoft),
                const SizedBox(height: 14),
                Container(width: 220, height: 38, color: colors.borderSoft),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 58,
                        color: colors.borderSoft,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        height: 58,
                        color: colors.borderSoft,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _skeletonSection(context),
          const SizedBox(height: 18),
          _skeletonSection(context),
        ],
      ),
    );
  }

  Widget _skeletonSection(BuildContext context) {
    final color = context.colors.borderSoft;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(width: 150, height: 12, color: color),
        const SizedBox(height: 10),
        AppCard(
          radius: 22,
          shadow: true,
          child: Column(
            children: [
              for (var index = 0; index < 2; index++) ...[
                if (index > 0) Divider(height: 18, color: color),
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(width: 130, height: 13, color: color),
                          const SizedBox(height: 8),
                          Container(width: 180, height: 11, color: color),
                        ],
                      ),
                    ),
                    Container(width: 70, height: 13, color: color),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _errorContent() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: [
        ErrorCard(
          message: _error!,
          onRetry: () => _load(showLoading: true),
          prominent: true,
        ),
      ],
    );
  }

  Widget _notLinkedContent() {
    final colors = context.colors;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        AppCard(
          radius: 22,
          shadow: true,
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  color: colors.warningBg,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  AppIcons.bankAccount,
                  color: colors.warningText,
                  size: 42,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'No funding account yet',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Link the bank account that holds the money for scholar payouts.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.textBody,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        InfoBanner(
          icon: AppIcons.warning,
          message:
              "Payout Events can't be issued until a funding account is linked.",
          backgroundColor: colors.warningBg,
          iconColor: colors.warningText,
          textColor: colors.warningText,
          borderRadius: 18,
          padding: const EdgeInsets.all(16),
        ),
      ],
    );
  }

  Widget _linkedContent() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        _summaryHero(_summary!),
        const SizedBox(height: 20),
        SectionLabel(
          'LINKED BANK ACCOUNT',
          labelColor: context.colors.textBody,
          fontSize: 11,
          letterSpacing: 1.2,
        ),
        const SizedBox(height: 10),
        _linkedAccountCard(_account!),
        const SizedBox(height: 20),
        SectionLabel(
          'FUND ACTIVITY',
          labelColor: context.colors.textBody,
          fontSize: 11,
          letterSpacing: 1.2,
        ),
        const SizedBox(height: 10),
        _activityCard(_entries),
      ],
    );
  }

  Widget _summaryHero(FundSummary summary) {
    final colors = context.colors;
    final muted = colors.onHeader.withValues(alpha: .88);
    return AppCard(
      radius: 28,
      padding: const EdgeInsets.all(22),
      shadow: true,
      clipBehavior: Clip.hardEdge,
      borderColor: Colors.transparent,
      borderWidth: 0,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [colors.header, colors.heroGradientEnd],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -118,
            right: -100,
            child: _heroCircle(colors.onHeader.withValues(alpha: .12), 230),
          ),
          Positioned(
            bottom: -132,
            left: -104,
            child: _heroCircle(colors.onHeader.withValues(alpha: .1), 250),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'AVAILABLE FUND',
                    style: TextStyle(
                      color: muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.3,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: colors.onHeader.withValues(alpha: .2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'DEMO',
                      style: TextStyle(
                        color: colors.onHeader,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text.rich(
                    TextSpan(
                      style: TextStyle(
                        color: colors.onHeader,
                        fontWeight: FontWeight.w800,
                      ),
                      children: [
                        const TextSpan(
                          text: 'PHP ',
                          style: TextStyle(fontSize: 16),
                        ),
                        TextSpan(
                          text: fmtPhp(summary.available),
                          style: const TextStyle(
                            fontSize: 36,
                            letterSpacing: -.8,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    softWrap: false,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _heroAmountCard(
                        label: 'Reserved for payouts',
                        amount: summary.reserved,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _heroAmountCard(
                        label: 'Disbursed so far',
                        amount: summary.disbursed,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroAmountCard({required String label, required double amount}) {
    final colors = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.onHeader.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.onHeader.withValues(alpha: .12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: mutedHeroText(colors),
              fontSize: 11.5,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'PHP ${fmtPhp(amount)}',
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  color: colors.onHeader,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color mutedHeroText(AppColors colors) =>
      colors.onHeader.withValues(alpha: .88);

  Widget _heroCircle(Color color, double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );

  Widget _linkedAccountCard(FundingAccount account) {
    final colors = context.colors;
    return AppCard(
      radius: 22,
      shadow: true,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: colors.warningBg,
              borderRadius: BorderRadius.circular(15),
            ),
            alignment: Alignment.center,
            child: Icon(
              AppIcons.bankAccount,
              color: colors.warningText,
              size: 23,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.bankName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${account.accountName} · •••• ${account.last4}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textBody,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Funding account options',
            icon: Icon(AppIcons.menu, color: colors.textBody),
            onSelected: (value) {
              if (value == 'change') _openLinkSheet();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'change',
                child: Text('Change account'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _activityCard(List<FundEntry> entries) {
    if (entries.isEmpty) {
      return const AppCard(
        radius: 22,
        shadow: true,
        child: EmptyState(
          icon: AppIcons.wallet,
          message: 'No fund activity yet.',
        ),
      );
    }

    final displayable = entries
        .map((entry) =>
            (entry: entry, presentation: _activityPresentation(entry)))
        .where((item) => item.presentation != null)
        .toList(growable: false);
    if (displayable.isEmpty) {
      return const AppCard(
        radius: 22,
        shadow: true,
        child: EmptyState(
          icon: AppIcons.wallet,
          message: 'No fund activity yet.',
        ),
      );
    }

    return AppCard(
      radius: 22,
      shadow: true,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Column(
        children: [
          for (var index = 0; index < displayable.length; index++) ...[
            if (index > 0)
              Divider(
                  height: 1, thickness: 1, color: context.colors.borderSoft),
            _activityRow(
              displayable[index].entry,
              displayable[index].presentation!,
            ),
          ],
        ],
      ),
    );
  }

  _FundActivityPresentation? _activityPresentation(FundEntry entry) {
    final colors = context.colors;
    switch (entry.kind) {
      case FundEntryKind.topup:
        return _FundActivityPresentation(
          title: 'Fund top-up',
          icon: AppIcons.arrowDown,
          tileColor: colors.successBg,
          iconColor: colors.successText,
          amountColor: colors.successText,
          sign: '+',
        );
      case FundEntryKind.reserve:
        return _FundActivityPresentation(
          title: 'Payout Event issued',
          icon: AppIcons.wallet,
          tileColor: colors.brandTint,
          iconColor: colors.textBody,
          amountColor: colors.dangerText,
          sign: '-',
        );
      case FundEntryKind.release:
        return _FundActivityPresentation(
          title: 'Payout cancelled (released)',
          icon: AppIcons.refresh,
          tileColor: colors.brandTint,
          iconColor: colors.textBody,
          amountColor: colors.successText,
          sign: '+',
        );
      case FundEntryKind.disburse:
        return _FundActivityPresentation(
          title: 'Payout received (disbursed)',
          icon: AppIcons.arrowUpRight,
          tileColor: colors.dangerBg,
          iconColor: colors.dangerText,
          amountColor: colors.dangerText,
          sign: '-',
        );
    }
  }

  Widget _activityRow(
    FundEntry entry,
    _FundActivityPresentation presentation,
  ) {
    final colors = context.colors;
    final note = entry.note?.trim();
    final date = DateFormat('MMM d, yyyy · h:mm a').format(entry.createdAt);
    final subtitle = note == null || note.isEmpty ? date : '$note · $date';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: presentation.tileColor,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              presentation.icon,
              color: presentation.iconColor,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  presentation.title,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: colors.textBody,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 92,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.topRight,
              child: Text(
                '${presentation.sign}PHP ${fmtPhp(entry.amount)}',
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  color: presentation.amountColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FundActivityPresentation {
  final String title;
  final IconData icon;
  final Color tileColor;
  final Color iconColor;
  final Color amountColor;
  final String sign;

  const _FundActivityPresentation({
    required this.title,
    required this.icon,
    required this.tileColor,
    required this.iconColor,
    required this.amountColor,
    required this.sign,
  });
}

class _LinkFundingAccountSheet extends StatefulWidget {
  final FundingAccount? account;

  const _LinkFundingAccountSheet({this.account});

  @override
  State<_LinkFundingAccountSheet> createState() =>
      _LinkFundingAccountSheetState();
}

class _LinkFundingAccountSheetState extends State<_LinkFundingAccountSheet> {
  late final TextEditingController _bank;
  late final TextEditingController _accountName;
  late final TextEditingController _accountNumber;
  bool _bankTouched = false;
  bool _nameTouched = false;
  bool _numberTouched = false;
  bool _busy = false;
  String? _saveError;

  String get _digits => _accountNumber.text.replaceAll(RegExp(r'[^0-9]'), '');

  String? get _bankError =>
      _bank.text.trim().length < 2 ? 'Enter the bank name.' : null;

  String? get _nameError => _accountName.text.trim().length < 2
      ? 'Enter the name registered on the account.'
      : null;

  String? get _numberError =>
      _digits.length < 8 || _digits.length > 20
          ? 'Enter an account number with 8 to 20 digits.'
          : null;

  bool get _isValid =>
      _bankError == null && _nameError == null && _numberError == null;

  @override
  void initState() {
    super.initState();
    _bank = TextEditingController(text: widget.account?.bankName ?? '');
    _accountName =
        TextEditingController(text: widget.account?.accountName ?? '');
    _accountNumber = TextEditingController();
  }

  @override
  void dispose() {
    _bank.dispose();
    _accountName.dispose();
    _accountNumber.clear();
    _accountNumber.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_isValid) return;
    setState(() {
      _busy = true;
      _saveError = null;
    });

    var linked = false;
    try {
      await context.read<AppState>().wallet.linkFundingAccount(
            bank: _bank.text.trim(),
            accountName: _accountName.text.trim(),
            accountNumber: _digits,
          );
      linked = true;
    } on WalletException catch (error) {
      if (mounted) setState(() => _saveError = error.message);
    } finally {
      if (mounted) {
        _accountNumber.clear();
        setState(() => _busy = false);
      }
    }

    if (linked && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppBottomSheet(
      title: 'Link funding account',
      radius: 28,
      showDragHandle: true,
      dragHandleSize: const Size(44, 5),
      dragHandleColor: colors.sheetHandle,
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Link funding account',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'The bank account that holds the money for payouts',
            style: TextStyle(color: colors.textBody, fontSize: 13),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: _bank,
            labelText: 'Bank name',
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {
              _bankTouched = true;
              _saveError = null;
            }),
            decoration: _formDecoration(
              context,
              label: 'Bank name',
              errorText: _bankTouched ? _bankError : null,
            ),
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _accountName,
            labelText: 'Account name',
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {
              _nameTouched = true;
              _saveError = null;
            }),
            decoration: _formDecoration(
              context,
              label: 'Account name',
              errorText: _nameTouched ? _nameError : null,
            ),
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _accountNumber,
            labelText: 'Account number',
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {
              _numberTouched = true;
              _saveError = null;
            }),
            decoration: _formDecoration(
              context,
              label: 'Account number',
              errorText: _numberTouched ? _numberError : null,
            ),
          ),
          const SizedBox(height: 14),
          InfoBanner(
            icon: AppIcons.lock,
            message: 'Your details are used only to fund payouts.',
            backgroundColor: colors.brandTint,
            iconColor: colors.brand,
            textColor: colors.textBody,
            borderRadius: 16,
          ),
          if (_saveError != null) ...[
            const SizedBox(height: 12),
            InfoBanner(
              icon: AppIcons.error,
              message: _saveError!,
              backgroundColor: colors.dangerBg,
              iconColor: colors.dangerText,
              textColor: colors.dangerText,
              borderRadius: 16,
            ),
          ],
          const SizedBox(height: 16),
          PrimaryButton(
            label: 'Save account',
            icon: AppIcons.check,
            loading: _busy,
            loadingLabel: 'Saving account',
            minHeight: 56,
            borderRadius: 18,
            onPressed: _isValid && !_busy ? _save : null,
          ),
        ],
      ),
    );
  }
}

class _TopUpFundSheet extends StatefulWidget {
  final FundingAccount account;
  final FundSummary summary;

  const _TopUpFundSheet({
    required this.account,
    required this.summary,
  });

  @override
  State<_TopUpFundSheet> createState() => _TopUpFundSheetState();
}

class _TopUpFundSheetState extends State<_TopUpFundSheet> {
  final TextEditingController _amountController = TextEditingController();
  bool _busy = false;
  String? _topUpError;

  double? get _amount => double.tryParse(_amountController.text.trim());
  bool get _isValid => (_amount ?? 0) > 0;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _setAmount(String value) {
    _amountController.text = value;
    _amountController.selection = TextSelection.collapsed(offset: value.length);
    setState(() => _topUpError = null);
  }

  Future<void> _topUp() async {
    final amount = _amount;
    if (_busy || amount == null || amount <= 0) return;
    setState(() {
      _busy = true;
      _topUpError = null;
    });

    var toppedUp = false;
    try {
      await context.read<AppState>().wallet.topUpFund(amount);
      toppedUp = true;
    } on WalletException catch (error) {
      if (mounted) setState(() => _topUpError = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }

    if (toppedUp && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final double amount = _isValid ? (_amount ?? 0.0) : 0.0;
    final presets = <String, String>{
      '5000': '₱5,000',
      '10000': '₱10,000',
      '25000': '₱25,000',
      '50000': '₱50,000',
    };
    final selectedPreset = presets.containsKey(_amountController.text)
        ? _amountController.text
        : '';

    return AppBottomSheet(
      title: 'Top up fund',
      radius: 28,
      showDragHandle: true,
      dragHandleSize: const Size(44, 5),
      dragHandleColor: colors.sheetHandle,
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top up fund',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Add simulated funds to the payout balance',
            style: TextStyle(color: colors.textBody, fontSize: 13),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionLabel(
            'FROM',
            labelColor: colors.textBody,
            fontSize: 11,
            letterSpacing: 1.2,
          ),
          const SizedBox(height: 8),
          AppCard(
            radius: 22,
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colors.warningBg,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    AppIcons.bankAccount,
                    color: colors.warningText,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.account.bankName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '•••• ${widget.account.last4}',
                        style: TextStyle(
                          color: colors.textBody,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          AppTextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
            onChanged: (_) => setState(() => _topUpError = null),
            decoration: InputDecoration(
              prefixText: '₱',
              prefixStyle: TextStyle(
                color: colors.textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
              hintText: '0.00',
              hintStyle: TextStyle(color: colors.hint, fontSize: 28),
              filled: true,
              fillColor: colors.surface,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: colors.brand, width: 2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: colors.brand, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: colors.dangerBorder, width: 2),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: colors.dangerBorder, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilterChipsRow(
            items: [
              for (final preset in presets.entries)
                FilterChipItem(
                  value: preset.key,
                  label: preset.value,
                  count: 0,
                ),
            ],
            selectedValue: selectedPreset,
            onSelected: _setAmount,
            padding: EdgeInsets.zero,
            showCount: false,
          ),
          const SizedBox(height: 14),
          AppCard(
            radius: 22,
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'New available fund',
                    style: TextStyle(
                      color: colors.textBody,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'PHP ${fmtPhp(widget.summary.available + amount)}',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Demo mode: top-up is a simulation. No real money moves from your bank.',
            style: TextStyle(
              color: colors.textBody,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          if (_topUpError != null) ...[
            const SizedBox(height: 12),
            InfoBanner(
              icon: AppIcons.error,
              message: _topUpError!,
              backgroundColor: colors.dangerBg,
              iconColor: colors.dangerText,
              textColor: colors.dangerText,
              borderRadius: 16,
            ),
          ],
          const SizedBox(height: 18),
          PrimaryButton(
            label: 'Top up PHP ${fmtPhp(amount)}',
            icon: AppIcons.plus,
            loading: _busy,
            loadingLabel: 'Topping up fund',
            minHeight: 56,
            borderRadius: 18,
            onPressed: _isValid && !_busy ? _topUp : null,
          ),
        ],
      ),
    );
  }
}

InputDecoration _formDecoration(
  BuildContext context, {
  required String label,
  String? errorText,
}) {
  final colors = context.colors;
  return InputDecoration(
    labelText: label,
    errorText: errorText,
    labelStyle: TextStyle(color: colors.textBody),
    hintStyle: TextStyle(color: colors.hint),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: colors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: colors.brand, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: colors.dangerBorder),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: colors.dangerBorder, width: 1.5),
    ),
  );
}
