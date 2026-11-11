import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/widgets.dart';

/// FR-23 — Admin controls who receives an allowance by activating or
/// deactivating scholar accounts, and can delete accounts (one at a time or
/// all finished inactive ones). Deactivated scholars are excluded from the
/// Disburse Allowance recipient list.
class ManageScholarsScreen extends StatefulWidget {
  const ManageScholarsScreen({super.key});

  @override
  State<ManageScholarsScreen> createState() => _ManageScholarsScreenState();
}

class _ManageScholarsScreenState extends State<ManageScholarsScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Scholar> _scholars = [];
  final Set<String> _updatingIds = {};
  bool _loading = true;
  String _query = '';
  String? _error;

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
      _scholars = await context.read<AppState>().wallet.getScholars();
      _error = null;
    } catch (e) {
      _scholars = [];
      _error = '$e';
    }
    if (mounted) setState(() => _loading = false);
  }

  List<Scholar> get _visibleScholars {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _scholars;
    return _scholars
        .where((scholar) =>
            scholar.name.toLowerCase().contains(query) ||
            scholar.studentId.toLowerCase().contains(query))
        .toList();
  }

  int get _verifiedCount => _scholars
      .where((scholar) =>
          scholar.verificationStatus == VerificationStatus.approved)
      .length;

  int get _activeCount => _scholars.where((scholar) => scholar.active).length;

  Future<void> _toggle(Scholar scholar, bool active) async {
    setState(() => _updatingIds.add(scholar.id));
    try {
      await context
          .read<AppState>()
          .wallet
          .setScholarActive(scholar.id, active);
      if (!mounted) return;
      setState(() => scholar.active = active);
      showMsg(
        context,
        active ? '${scholar.name} activated.' : '${scholar.name} deactivated.',
      );
    } catch (e) {
      if (mounted) {
        showMsg(
          context,
          'Failed to update the scholar account. ($e)',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _updatingIds.remove(scholar.id));
    }
  }

  Future<bool> _confirm({
    required String title,
    required String body,
    required String action,
  }) async {
    final result = await ConfirmDialog.show(
      context,
      title: title,
      message: body,
      confirmLabel: action,
      danger: true,
    );
    return result == true;
  }

  Future<void> _delete(Scholar scholar) async {
    final ok = await _confirm(
      title: 'Delete ${scholar.name}?',
      body: 'This will permanently remove ${scholar.name} and all of their '
          'transaction, payout, linked-account, and registration-review records. '
          'Accounts with a balance cannot be deleted. This cannot be undone.',
      action: 'Delete',
    );
    if (!ok || !mounted) return;
    try {
      await context.read<AppState>().wallet.deleteScholar(scholar.id);
      if (!mounted) return;
      setState(() => _scholars.removeWhere((item) => item.id == scholar.id));
      showMsg(context, '${scholar.name} deleted.');
    } catch (e) {
      if (mounted) showMsg(context, '$e', error: true);
    }
  }

  Future<void> _deleteInactive() async {
    final count = _scholars
        .where((scholar) =>
            !scholar.active &&
            scholar.balance == 0 &&
            (scholar.verificationStatus == VerificationStatus.rejected ||
                scholar.verificationStatus == VerificationStatus.approved))
        .length;
    if (count == 0) {
      showMsg(context, 'No inactive accounts to delete.');
      return;
    }
    final ok = await _confirm(
      title: 'Delete inactive accounts?',
      body: '$count inactive scholar account(s) marked Verified or '
          'Registration rejected, with zero balance, will be permanently '
          'deleted. Registrations still waiting for a decision are not '
          'affected. This cannot be undone.',
      action: 'Delete $count',
    );
    if (!ok || !mounted) return;
    try {
      final deletedCount =
          await context.read<AppState>().wallet.deleteInactiveScholars();
      if (!mounted) return;
      showMsg(context, '$deletedCount inactive account(s) deleted.');
      await _load();
    } catch (e) {
      if (mounted) showMsg(context, '$e', error: true);
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: const Text('Manage Scholars'),
        leading: _RoundToolbarButton(
          icon: AppIcons.back,
          onPressed: () => Navigator.maybePop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _RoundToolbarButton(
              icon: AppIcons.delete,
              tooltip: 'Delete inactive accounts',
              danger: true,
              onPressed: _loading ? null : _deleteInactive,
            ),
          ),
        ],
      ),
      body: _loading
          ? _loadingBody()
          : _error != null
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  children: [
                    ErrorCard(
                      message: 'Could not load scholars.\n$_error',
                      onRetry: _load,
                    ),
                  ],
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    children: [
                      _heroCard(),
                      const SizedBox(height: 16),
                      SearchField(
                        controller: _searchController,
                        hintText: 'Search by name or ID',
                        radius: 18,
                        minHeight: 52,
                        onChanged: (value) => setState(() => _query = value),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                onPressed: _clearSearch,
                                icon: Icon(
                                  AppIcons.close,
                                  color: context.colors.textBody,
                                ),
                              ),
                      ),
                      const SizedBox(height: 20),
                      SectionLabel(
                        'SCHOLARS (${_visibleScholars.length}) · '
                        'TOGGLE TO CONTROL ALLOWANCE',
                      ),
                      const SizedBox(height: 12),
                      if (_scholars.isEmpty)
                        const AppCard(
                          radius: 22,
                          shadow: true,
                          child: EmptyState(
                            icon: AppIcons.users,
                            title: 'No scholars registered yet',
                            message:
                                'Registered scholar accounts will appear here.',
                          ),
                        )
                      else if (_visibleScholars.isEmpty)
                        AppCard(
                          radius: 22,
                          shadow: true,
                          child: EmptyState(
                            icon: AppIcons.search,
                            title: 'No matching scholars',
                            message: 'Try another name or student ID.',
                            action: TextButton(
                              onPressed: _clearSearch,
                              child: const Text('Clear filters'),
                            ),
                          ),
                        )
                      else
                        ..._visibleScholars.map(_scholarCard),
                    ],
                  ),
                ),
    );
  }

  Widget _loadingBody() {
    return AppSkeletonizer(
      enabled: true,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          _loadingHero(),
          const SizedBox(height: 16),
          SearchField(
            controller: _searchController,
            hintText: 'Search by name or ID',
            radius: 18,
            minHeight: 52,
          ),
          const SizedBox(height: 20),
          const SectionLabel('SCHOLARS · TOGGLE TO CONTROL ALLOWANCE'),
          const SizedBox(height: 12),
          for (var index = 0; index < 3; index++) ...[
            _loadingCard(),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _loadingHero() {
    return AppCard(
      radius: 26,
      padding: const EdgeInsets.all(22),
      backgroundColor: context.colors.borderSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 12, width: 140, color: Colors.white),
          const SizedBox(height: 10),
          Container(height: 44, width: 68, color: Colors.white),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                height: 34,
                width: 110,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.all(Radius.circular(24)),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                height: 34,
                width: 138,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.all(Radius.circular(24)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _loadingCard() {
    return AppCard(
      radius: 22,
      shadow: true,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              const CircleAvatar(radius: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 16, width: 150, color: Colors.white),
                    const SizedBox(height: 8),
                    Container(height: 12, width: 100, color: Colors.white),
                  ],
                ),
              ),
              const SizedBox(width: 40, height: 24),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: context.colors.borderSoft),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(height: 24, width: 74, color: Colors.white),
              const SizedBox(width: 12),
              Container(height: 16, width: 104, color: Colors.white),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [context.colors.header, context.colors.heroGradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -62,
            top: -90,
            child: _heroCircle(220),
          ),
          Positioned(
            right: -85,
            bottom: -132,
            child: _heroCircle(250),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TOTAL SCHOLARS',
                style: TextStyle(
                  color: context.colors.onHeader.withValues(alpha: .88),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_scholars.length}',
                style: TextStyle(
                  color: context.colors.onHeader,
                  fontSize: 44,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _heroPill('$_verifiedCount verified', showDot: true),
                  _heroPill('$_activeCount allowance on'),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroCircle(double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: context.colors.onHeader.withValues(alpha: .10),
          shape: BoxShape.circle,
        ),
      );

  Widget _heroPill(String label, {bool showDot = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.colors.onHeader.withValues(alpha: .18),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: context.colors.success,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 7),
          ],
          Text(
            label,
            style: TextStyle(
              color: context.colors.onHeader,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _scholarCard(Scholar scholar) {
    final verified = scholar.verificationStatus == VerificationStatus.approved;
    final updating = _updatingIds.contains(scholar.id);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        radius: 22,
        shadow: true,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: context.colors.successBg,
                  child: Text(
                    scholar.name.isNotEmpty
                        ? scholar.name[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: context.colors.successText,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        scholar.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.colors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'ID: ${scholar.studentId}',
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
                SizedBox(
                  width: 82,
                  child: Column(
                    children: [
                      SizedBox(
                        height: 32,
                        child: updating
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: context.colors.brand,
                                ),
                              )
                            : Switch.adaptive(
                                value: scholar.active,
                                onChanged: verified
                                    ? (value) => _toggle(scholar, value)
                                    : null,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        updating
                            ? 'Updating'
                            : scholar.active
                                ? 'Receives allowance'
                                : 'Paused',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.colors.textBody,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Divider(height: 1, color: context.colors.borderSoft),
            const SizedBox(height: 12),
            Row(
              children: [
                _verificationChip(scholar.verificationStatus),
                const SizedBox(width: 8),
                Expanded(
                  child: FittedBox(
                    alignment: Alignment.centerLeft,
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'PHP ${fmtPhp(scholar.balance)}',
                      maxLines: 1,
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                _deleteButton(scholar),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _verificationChip(VerificationStatus status) {
    final (label, color, background) = switch (status) {
      VerificationStatus.approved => (
          'Verified',
          context.colors.successText,
          context.colors.successBg
        ),
      VerificationStatus.rejected => (
          status.label,
          context.colors.dangerText,
          context.colors.dangerBg
        ),
      VerificationStatus.underReview => (
          status.label,
          context.colors.brand,
          context.colors.brandTint
        ),
      VerificationStatus.pending || VerificationStatus.needsInfo => (
          status.label,
          context.colors.warningText,
          context.colors.warningBg
        ),
    };
    return StatusChip(label, color: color, bg: background);
  }

  Widget _deleteButton(Scholar scholar) {
    return Material(
      color: context.colors.dangerBg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => _delete(scholar),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(AppIcons.delete, size: 16, color: context.colors.dangerText),
              const SizedBox(width: 5),
              Text(
                'Delete',
                style: TextStyle(
                  color: context.colors.dangerText,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundToolbarButton extends StatelessWidget {
  const _RoundToolbarButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.danger = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final background =
        danger ? context.colors.dangerBg : context.colors.surface;
    final foreground =
        danger ? context.colors.dangerText : context.colors.textPrimary;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, color: foreground, size: 21),
      style: IconButton.styleFrom(
        backgroundColor: background,
        fixedSize: const Size(42, 42),
        side: BorderSide(color: context.colors.borderSoft),
      ),
    );
  }
}
