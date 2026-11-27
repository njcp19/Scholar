import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/destructive_confirm_dialog.dart';
import '../../widgets/shell_tab_controller.dart';
import '../../widgets/widgets.dart';

/// FR-23 — Admin controls who receives an allowance by activating or
/// deactivating scholar accounts, and can delete accounts one at a time.
/// Deactivated scholars are excluded from the Disburse Allowance recipient list.
class ManageScholarsScreen extends StatefulWidget {
  final bool embedded;

  const ManageScholarsScreen({super.key, this.embedded = false});

  @override
  State<ManageScholarsScreen> createState() => _ManageScholarsScreenState();
}

class _ManageScholarsScreenState extends State<ManageScholarsScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Scholar> _scholars = [];
  final Set<String> _updatingIds = {};
  bool _hasLoaded = false;
  String _query = '';
  String? _error;
  bool _offline = false;
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
    if (_tabController?.selectedIndex == 2) _load();
  }

  @override
  void dispose() {
    _tabController?.removeListener(_onTabChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      _scholars = (await context.read<AppState>().wallet.getScholars())
          .where(
            (scholar) =>
                scholar.verificationStatus != VerificationStatus.rejected,
          )
          .toList();
      _error = null;
      _offline = false;
    } catch (e) {
      _error = 'Could not load scholars. Please try again.';
      _offline = isOfflineLoadError(e);
    }
    if (mounted) {
      setState(() {
        _hasLoaded = true;
      });
    }
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
    } catch (_) {
      if (mounted) {
        showMsg(
          context,
          'Could not update the scholar account. Please try again.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _updatingIds.remove(scholar.id));
    }
  }

  Future<void> _delete(Scholar scholar) async {
    final result = await DestructiveConfirmDialog.show(
      context,
      title: 'Delete ${scholar.name}?',
      message: 'This will permanently remove ${scholar.name} and all of their '
          'transaction, payout, linked-account, and registration-review records. '
          'Accounts with a balance cannot be deleted. This cannot be undone.',
      dismissLabel: 'Cancel',
      confirmLabel: 'Delete',
      semanticsLabel: 'Delete scholar confirmation',
      icon: AppIcons.delete,
      dismissButtonKey: const ValueKey('manage-scholar-delete-cancel'),
      confirmButtonKey: const ValueKey('manage-scholar-delete-confirm'),
    );
    final ok = result == true;
    if (!ok || !mounted) return;
    try {
      await context.read<AppState>().wallet.deleteScholar(scholar.id);
      if (!mounted) return;
      setState(() => _scholars.removeWhere((item) => item.id == scholar.id));
      showMsg(context, '${scholar.name} deleted.');
    } catch (_) {
      if (mounted) {
        showMsg(context, 'Could not delete the scholar. Please try again.',
            error: true);
      }
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
        leadingWidth: widget.embedded ? null : 70,
        centerTitle: !widget.embedded,
        titleSpacing: widget.embedded ? 20 : 0,
        title: Text(
          'Manage Scholars',
          style: TextStyle(
            color: context.colors.textPrimary,
            fontSize: widget.embedded ? 26 : 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        leading: widget.embedded
            ? null
            : Padding(
                padding: const EdgeInsets.only(left: 26),
                child: _RoundToolbarButton(
                  icon: AppIcons.back,
                  onPressed: () => Navigator.maybePop(context),
                ),
              ),
      ),
      body: AppInitialLoadView(
        firstLoadPending: !_hasLoaded,
        skeleton: _loadingBody(),
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              if (_error != null) ...[
                ErrorCard(
                  message: _offline
                      ? 'Check your connection and try again. Your balance and payouts are not changed.'
                      : 'Could not load scholars.\n$_error',
                  onRetry: _load,
                  prominent: _scholars.isEmpty,
                  offline: _offline,
                ),
                if (_scholars.isNotEmpty) const SizedBox(height: 12),
              ],
              _heroCard(),
              const SizedBox(height: 16),
              SearchField(
                controller: _searchController,
                hintText: 'Search by name or ID',
                radius: 16,
                minHeight: 50,
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
              if (_scholars.isEmpty && _error == null)
                const AppCard(
                  radius: 22,
                  shadow: true,
                  child: EmptyState(
                    icon: AppIcons.users,
                    title: 'No scholars registered yet',
                    message: 'Registered scholar accounts will appear here.',
                  ),
                )
              else if (_scholars.isNotEmpty && _visibleScholars.isEmpty)
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
              else if (_visibleScholars.isNotEmpty)
                ..._visibleScholars.map(_scholarCard),
            ],
          ),
        ),
      ),
    );
  }

  Widget _loadingBody() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        const SkeletonCard(
          radius: 22,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonLine(width: 140),
              SizedBox(height: 10),
              SkeletonLine(width: 68, height: 44),
              SizedBox(height: 14),
              Row(
                children: [
                  SkeletonBox(width: 102, height: 34, radius: 17),
                  SizedBox(width: 8),
                  SkeletonBox(width: 120, height: 34, radius: 17),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const SkeletonBox(height: 52, radius: 18),
        const SizedBox(height: 20),
        const SkeletonLine(width: 210, height: 13),
        const SizedBox(height: 12),
        for (var index = 0; index < 4; index++) ...[
          if (index > 0) const SizedBox(height: 12),
          const SkeletonCard(
            child: Column(
              children: [
                Row(
                  children: [
                    SkeletonCircle(diameter: 48),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonLine(width: 150, height: 15),
                          SizedBox(height: 8),
                          SkeletonLine(width: 100, height: 12),
                        ],
                      ),
                    ),
                    SkeletonBox(width: 40, height: 24, radius: 12),
                  ],
                ),
                SizedBox(height: 16),
                SkeletonLine(height: 1),
                SizedBox(height: 12),
                Row(
                  children: [
                    SkeletonBox(width: 74, height: 24, radius: 12),
                    SizedBox(width: 12),
                    SkeletonLine(width: 104, height: 16),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _heroCard() {
    return ManageScholarsHeroCard(
      scholarCount: _scholars.length,
      verifiedCount: _verifiedCount,
      activeCount: _activeCount,
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                const SizedBox(width: 8),
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
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (updating)
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.colors.brand,
                        ),
                      )
                    else
                      Switch.adaptive(
                        value: scholar.active,
                        onChanged: verified
                            ? (value) => _toggle(scholar, value)
                            : null,
                      ),
                    const SizedBox(height: 3),
                    SizedBox(
                      width: 120,
                      child: Text(
                        updating
                            ? 'Updating'
                            : scholar.active
                                ? 'Receives allowance'
                                : 'Inactive',
                        maxLines: 2,
                        softWrap: true,
                        textAlign: TextAlign.end,
                        overflow: TextOverflow.clip,
                        style: TextStyle(
                          color: context.colors.textBody,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Divider(height: 1, color: context.colors.borderSoft),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: _verificationChip(
                            scholar.verificationStatus,
                          ),
                        ),
                      ),
                      if (scholar.scholarshipName.trim().isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: _scholarshipChip(
                            scholar.scholarshipName.trim(),
                            scholar.id,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
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

  Widget _scholarshipChip(String name, String scholarId) {
    final colors = context.colors;
    return Container(
      key: ValueKey('scholarship-chip-$scholarId'),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.borderSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppIcons.award, size: 14, color: colors.textBody),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.textBody,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _deleteButton(Scholar scholar) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _delete(scholar),
        borderRadius: BorderRadius.circular(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Align(
            alignment: Alignment.center,
            widthFactor: 1,
            heightFactor: 1,
            child: Ink(
              width: 96,
              height: 40,
              decoration: BoxDecoration(
                color: context.colors.dangerBg,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    AppIcons.delete,
                    size: 18,
                    color: context.colors.dangerText,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Delete',
                        maxLines: 1,
                        style: TextStyle(
                          color: context.colors.dangerText,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ManageScholarsHeroCard extends StatelessWidget {
  final int scholarCount;
  final int verifiedCount;
  final int activeCount;

  const ManageScholarsHeroCard({
    super.key,
    required this.scholarCount,
    required this.verifiedCount,
    required this.activeCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [context.colors.header, context.colors.heroGradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TOTAL SCHOLARS',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.colors.onHeader.withValues(alpha: .88),
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            HeroAmountText(
              amount: '$scholarCount',
              color: context.colors.onHeader,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _heroPill(context, '$verifiedCount verified', showDot: true),
                _heroPill(context, '$activeCount allowance on'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroPill(
    BuildContext context,
    String label, {
    bool showDot = false,
  }) {
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
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: context.colors.onHeader,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundToolbarButton extends StatelessWidget {
  const _RoundToolbarButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, color: context.colors.textPrimary, size: 21),
      style: IconButton.styleFrom(
        backgroundColor: context.colors.surface,
        fixedSize: const Size(42, 42),
        side: BorderSide(color: context.colors.borderSoft),
      ),
    );
  }
}
