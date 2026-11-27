import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../services/selfie_service.dart';
import '../../services/verification_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';
import '../../widgets/app_icons.dart';
import '../selfie_flow_screen.dart';

Future<bool?> showRegistrationDecisionDialog(
  BuildContext context, {
  required VerificationStatus status,
  required String scholarName,
  bool askForNewSelfie = false,
}) {
  final (
    title,
    message,
    confirmLabel,
    icon,
    iconBackground,
    iconForeground,
    iconHalo,
    confirmColor,
  ) = switch (status) {
    VerificationStatus.approved => (
        'Approve this scholar?',
        'They will be able to receive allowances once their account is active.',
        'Approve',
        AppIcons.check,
        const Color(0xFFE5F8F0),
        const Color(0xFF08734D),
        const Color(0xFFF2FBF7),
        const Color(0xFF1E5AA8),
      ),
    VerificationStatus.underReview => (
        'Mark as under review?',
        'The scholar stays pending while you check the details.',
        'Mark under review',
        AppIcons.eye,
        const Color(0xFFEAF2FE),
        const Color(0xFF1E5AA8),
        const Color(0xFFF4F8FE),
        const Color(0xFF1E5AA8),
      ),
    VerificationStatus.needsInfo => (
        'Request more information?',
        'Your review note will be shown to the scholar.',
        'Send request',
        AppIcons.error,
        const Color(0xFFFFF6E3),
        const Color(0xFF8A5A00),
        const Color(0xFFFFFBF2),
        const Color(0xFF1E5AA8),
      ),
    VerificationStatus.rejected => (
        'Reject this registration?',
        'Your review note will be shown to the scholar.',
        'Reject',
        AppIcons.cancel,
        const Color(0xFFFDECEC),
        const Color(0xFFB83232),
        const Color(0xFFFFF4F4),
        const Color(0xFFC41E1E),
      ),
    VerificationStatus.pending => throw ArgumentError.value(
        status,
        'status',
        'A review decision is required.',
      ),
  };

  return showDialog<bool>(
    context: context,
    builder: (_) => _RegistrationDecisionDialog(
      title: title,
      scholarName: scholarName,
      message: message,
      confirmLabel: confirmLabel,
      icon: icon,
      iconBackground: iconBackground,
      iconForeground: iconForeground,
      iconHalo: iconHalo,
      confirmColor: confirmColor,
      showSelfieInfo: status == VerificationStatus.needsInfo && askForNewSelfie,
    ),
  );
}

class _RegistrationDecisionDialog extends StatelessWidget {
  final String title;
  final String scholarName;
  final String message;
  final String confirmLabel;
  final IconData icon;
  final Color iconBackground;
  final Color iconForeground;
  final Color iconHalo;
  final Color confirmColor;
  final bool showSelfieInfo;

  const _RegistrationDecisionDialog({
    required this.title,
    required this.scholarName,
    required this.message,
    required this.confirmLabel,
    required this.icon,
    required this.iconBackground,
    required this.iconForeground,
    required this.iconHalo,
    required this.confirmColor,
    required this.showSelfieInfo,
  });

  @override
  Widget build(BuildContext context) {
    const textColor = Color(0xFF1A2530);
    final innerWidth = MediaQuery.sizeOf(context).width - 24 * 2 - 22 * 2;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: iconHalo,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: iconBackground,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: iconForeground, size: 28),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: textColor,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 14),
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: innerWidth),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7FA),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    scholarName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF4A5568),
                fontSize: 14,
                height: 1.5,
              ),
            ),
            if (showSelfieInfo) ...[
              const SizedBox(height: 14),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF2FE),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'The scholar will also be asked for a new selfie.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF123F86),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  flex: 8,
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      key: const ValueKey('decision-cancel'),
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: textColor,
                        side: const BorderSide(
                          color: Color(0xFFE3E8EF),
                          width: 1,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 14,
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: confirmColor.withValues(alpha: .3),
                          blurRadius: 16,
                          offset: const Offset(0, 7),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      key: const ValueKey('decision-confirm'),
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: confirmColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        confirmLabel,
                        maxLines: 1,
                        softWrap: false,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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
}

class RegistrationReviewScreen extends StatefulWidget {
  const RegistrationReviewScreen({super.key});
  @override
  State<RegistrationReviewScreen> createState() =>
      _RegistrationReviewScreenState();
}

class _RegistrationReviewScreenState extends State<RegistrationReviewScreen> {
  final _service = VerificationService();
  final _searchController = TextEditingController();
  List<AppUser> _users = [];
  bool _hasLoaded = false;
  bool _initialFilterResolved = false;
  String? _error;
  bool _offline = false;
  VerificationStatus? _filter = VerificationStatus.pending;

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
      final users = await _service.registrations();
      if (mounted) {
        setState(() {
          _users = users;
          _error = null;
          _offline = false;
          if (!_initialFilterResolved) {
            if (!users.any(
                (u) => u.verificationStatus == VerificationStatus.pending)) {
              _filter = null;
            }
            _initialFilterResolved = true;
          }
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error =
              'Could not load registrations. Check your connection, Firebase integration, and database migration.';
          _offline = isOfflineLoadError(error);
        });
      }
    } finally {
      if (mounted) setState(() => _hasLoaded = true);
    }
  }

  Future<void> _open(AppUser user) async {
    final changed = await Navigator.push<bool>(context,
        MaterialPageRoute(builder: (_) => _RegistrationDetail(user: user)));
    if (changed == true) await _load();
  }

  List<AppUser> get _visibleUsers {
    final query = _searchController.text.trim().toLowerCase();
    return _users.where((user) {
      final matchesStatus =
          _filter == null || user.verificationStatus == _filter;
      final matchesSearch = query.isEmpty ||
          user.fullName.toLowerCase().contains(query) ||
          (user.studentNumber ?? '').toLowerCase().contains(query);
      return matchesStatus && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filterItems = [
      FilterChipItem(value: 'all', label: 'All', count: _users.length),
      ...VerificationStatus.values.map(
        (status) => FilterChipItem(
          value: status.databaseValue,
          label: _statusLabel(status),
          count:
              _users.where((user) => user.verificationStatus == status).length,
        ),
      ),
    ];
    final selectedFilter = _filter?.databaseValue ?? 'all';
    final users = _visibleUsers;
    final hasCriteria =
        _filter != null || _searchController.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: _registrationAppBar(context),
      body: ScrollConfiguration(
        behavior: const _NoStretchScrollBehavior(),
        child: RefreshIndicator(
          onRefresh: _load,
          child: ContentWidth(
            child: AppInitialLoadView(
              firstLoadPending: !_hasLoaded,
              skeleton: const RegistrationLoadingSkeleton(),
              child: ListView(
                physics: const ClampingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(0, 16, 0, 24),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SearchField(
                      controller: _searchController,
                      hintText: 'Search name or student number',
                      onChanged: (_) => setState(() {}),
                      minHeight: 50,
                      radius: 16,
                      borderColor: context.colors.border,
                      iconColor: context.colors.hintContrast,
                      iconSize: 19,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilterChipsRow(
                    items: filterItems,
                    selectedValue: selectedFilter,
                    onSelected: (value) => setState(() {
                      _filter = value == 'all'
                          ? null
                          : VerificationStatus.values.firstWhere(
                              (status) => status.databaseValue == value,
                            );
                    }),
                    selectedBackgroundColor: context.colors.brandTint,
                    selectedTextColor: context.colors.brand,
                    unselectedTextColor: context.colors.textBody,
                    selectedBorderWidth: 1.5,
                    countBadge: true,
                    countBackgroundColor: context.colors.filterCountBackground,
                    selectedCountBackgroundColor: context.colors.brand,
                    countTextColor: context.colors.textBody,
                    selectedCountTextColor: context.colors.onHeader,
                    chipRadius: 18,
                    chipFontSize: 14,
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SectionLabel(
                      'REGISTRATIONS (${_users.length})',
                      labelColor: context.colors.textBody,
                      fontSize: 11.5,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_error != null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: ErrorCard(
                        message: _offline
                            ? 'Check your connection and try again. Your balance and payouts are not changed.'
                            : _error!,
                        onRetry: _load,
                        prominent: _users.isEmpty,
                        offline: _offline,
                      ),
                    ),
                    if (_users.isNotEmpty) const SizedBox(height: 12),
                  ],
                  if (_error == null && _users.isEmpty && !hasCriteria)
                    const EmptyState(
                      icon: AppIcons.userSearch,
                      title: 'No registrations in this status',
                      message: 'New registrations will appear here',
                    )
                  else if (_users.isNotEmpty && users.isEmpty)
                    EmptyState(
                      icon: AppIcons.search,
                      title: 'No matching registrations',
                      message: 'Try a different search or status filter.',
                      action: TextButton(
                        onPressed: () {
                          setState(() {
                            _filter = null;
                            _searchController.clear();
                          });
                        },
                        child: const Text('Clear filters'),
                      ),
                    )
                  else if (users.isNotEmpty)
                    ...users.map(
                      (user) => Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                        child: _RegistrationRow(
                          user: user,
                          onTap: () => _open(user),
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

AppBar _registrationAppBar(BuildContext context) => AppBar(
      backgroundColor: context.colors.background,
      foregroundColor: context.colors.textPrimary,
      surfaceTintColor: context.colors.background,
      elevation: 0,
      centerTitle: true,
      titleSpacing: 0,
      leadingWidth: 70,
      leading: Padding(
        padding: const EdgeInsets.only(left: 26),
        child: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.maybePop(context),
          style: IconButton.styleFrom(
            fixedSize: const Size.square(44),
            padding: EdgeInsets.zero,
            backgroundColor: context.colors.surface,
            side: BorderSide(color: context.colors.borderSoft),
            shape: const CircleBorder(),
          ),
          icon: const Icon(AppIcons.back),
        ),
      ),
      title: const Text(
        'Registration Verification',
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
      ),
    );

class _RegistrationRow extends StatelessWidget {
  final AppUser user;
  final VoidCallback onTap;

  const _RegistrationRow({
    required this.user,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final status = user.verificationStatus;
    final studentNumber = user.studentNumber?.trim();

    return ListRowCard(
      onTap: onTap,
      radius: 22,
      padding: const EdgeInsets.all(16),
      shadow: true,
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: context.colors.avatarTint,
            child: Text(
              user.initials,
              style: TextStyle(
                color: context.colors.avatarText,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Student number: ${studentNumber?.isNotEmpty == true ? studentNumber : '—'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.colors.textBody,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 7),
                StatusChip(
                  status.label,
                  color: _statusColor(context, status),
                  bg: _statusBackground(context, status),
                  borderRadius: 9,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  fontSize: 11,
                  letterSpacing: .4,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            AppIcons.chevronRight,
            color: context.colors.hintContrast,
            size: 18,
          ),
        ],
      ),
    );
  }
}

class _RegistrationDetail extends StatefulWidget {
  final AppUser user;
  const _RegistrationDetail({required this.user});
  @override
  State<_RegistrationDetail> createState() => _RegistrationDetailState();
}

List<MapEntry<String, String>> registrationDetailRows(AppUser user) => [
      MapEntry('Email', user.email),
      MapEntry('Student number', user.studentNumber ?? '—'),
      MapEntry('School', user.university ?? '—'),
      MapEntry('Program', user.program ?? '—'),
      MapEntry('Year', user.yearLevel ?? '—'),
      if (user.birthdate != null)
        MapEntry(
          'Birthdate',
          DateFormat('MMM d, yyyy').format(user.birthdate!),
        ),
      MapEntry('Declared scholar', user.declaredScholar ? 'Yes' : 'No'),
      MapEntry(
        'Scholarship',
        user.scholarshipName.isEmpty ? 'Not provided' : user.scholarshipName,
      ),
    ];

class _RegistrationDetailState extends State<_RegistrationDetail> {
  final _notes = TextEditingController();
  final _service = VerificationService();
  final _selfieService = SelfieService();
  late Future<List<Map<String, dynamic>>> _history;
  Future<String>? _selfieUrl;
  bool _rosterChecked = false;
  bool _askForNewSelfie = false;
  bool _busy = false;
  VerificationStatus? _busyStatus;

  @override
  void initState() {
    super.initState();
    _history = _service.history(widget.user.id);
    final path = widget.user.selfiePath;
    if (path != null && path.isNotEmpty) {
      _selfieUrl = _selfieService.signedUrl(path);
    }
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _decide(VerificationStatus status) async {
    if (status == VerificationStatus.approved && !_rosterChecked) return;
    if ((status == VerificationStatus.rejected ||
            status == VerificationStatus.needsInfo) &&
        _notes.text.trim().isEmpty) {
      showMsg(context, 'Provide a reason or describe the information required.',
          error: true);
      return;
    }
    final confirm = await showRegistrationDecisionDialog(
      context,
      status: status,
      scholarName: widget.user.fullName,
      askForNewSelfie:
          status == VerificationStatus.needsInfo && _askForNewSelfie,
    );
    if (confirm != true || !mounted) return;
    setState(() {
      _busy = true;
      _busyStatus = status;
    });
    try {
      await _service.review(widget.user, status, _notes.text);
      String? selfieRequestError;
      if (status == VerificationStatus.needsInfo && _askForNewSelfie) {
        try {
          await _selfieService.requestRetake(widget.user.id);
        } catch (error) {
          selfieRequestError = selfieFriendlyErrorMessage(error);
        }
      }
      if (mounted) {
        showMsg(
          context,
          selfieRequestError ?? 'Registration verification recorded.',
          error: selfieRequestError != null,
        );
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) {
        showMsg(context, selfieFriendlyErrorMessage(error), error: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyStatus = null;
        });
      }
    }
  }

  Widget _detailRow(String label, String value, {bool divider = false}) {
    return Column(
      children: [
        if (divider)
          Divider(
            height: 1,
            thickness: 1,
            color: context.colors.borderSoft,
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 4,
                child: Text(
                  label,
                  style: TextStyle(
                    color: context.colors.textBody,
                    fontSize: 13.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 6,
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  softWrap: true,
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _historyDate(Object? raw) {
    final date = raw is DateTime
        ? raw
        : raw is String
            ? DateTime.tryParse(raw)
            : null;
    return date == null
        ? 'Date unavailable'
        : DateFormat('MMM d, yyyy • h:mm a').format(date.toLocal());
  }

  void _viewSelfie(String signedUrl) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => SelfieFullScreenViewer(signedUrl: signedUrl),
      ),
    );
  }

  Widget _selfieSection() {
    final path = widget.user.selfiePath;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(
          'SELFIE',
          labelColor: context.colors.textBody,
          fontSize: 11.5,
          letterSpacing: 1.2,
        ),
        const SizedBox(height: 8),
        if (path == null || path.isEmpty)
          AppCard(
            radius: 22,
            shadow: true,
            child: Text(
              'No selfie submitted yet',
              style: TextStyle(
                color: context.colors.textBody,
                fontSize: 14,
              ),
            ),
          )
        else
          AppCard(
            radius: 22,
            shadow: true,
            padding: const EdgeInsets.all(16),
            child: FutureBuilder<String>(
              future: _selfieUrl,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return AppSkeletonizer(
                    enabled: true,
                    child: Container(
                      height: 110,
                      decoration: BoxDecoration(
                        color: context.colors.surface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  );
                }
                if (snapshot.hasError || snapshot.data == null) {
                  return Text(
                    'Could not load this selfie.',
                    style: TextStyle(
                      color: context.colors.dangerText,
                      fontSize: 12,
                    ),
                  );
                }
                final signedUrl = snapshot.data!;
                return Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        width: 88,
                        height: 104,
                        child: Image.network(
                          signedUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => ColoredBox(
                            color: context.colors.brandTint,
                            child: Icon(
                              AppIcons.image,
                              color: context.colors.brand,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Submitted by the scholar',
                            style: TextStyle(
                              color: context.colors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () => _viewSelfie(signedUrl),
                            icon: Icon(
                              AppIcons.image,
                              size: 18,
                              color: context.colors.brand,
                            ),
                            label: Text(
                              'View full size',
                              style: TextStyle(
                                color: context.colors.brand,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              alignment: Alignment.centerLeft,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final hasSelfie = u.selfiePath?.isNotEmpty == true;
    final status = u.verificationStatus;
    final undecided = status != VerificationStatus.approved &&
        status != VerificationStatus.rejected;
    final details = registrationDetailRows(u);
    if (u.reviewNotes.isNotEmpty) {
      details.add(MapEntry('Previous feedback', u.reviewNotes));
    }

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: _registrationAppBar(context),
      body: ScrollConfiguration(
        behavior: const _NoStretchScrollBehavior(),
        child: ContentWidth(
          child: ListView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              AppCard(
                radius: 22,
                shadow: true,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: context.colors.avatarTint,
                      child: Text(
                        u.initials,
                        style: TextStyle(
                          color: context.colors.avatarText,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            u.fullName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.colors.textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          StatusChip(
                            status.label,
                            color: _statusColor(context, status),
                            bg: _statusBackground(context, status),
                            borderRadius: 10,
                            fontSize: 11,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _selfieSection(),
              const SizedBox(height: 16),
              SectionLabel(
                'SCHOLAR DETAILS',
                labelColor: context.colors.textBody,
                fontSize: 11.5,
                letterSpacing: 1.2,
              ),
              const SizedBox(height: 8),
              AppCard(
                radius: 22,
                shadow: true,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    for (var index = 0; index < details.length; index++)
                      _detailRow(
                        details[index].key,
                        details[index].value,
                        divider: index > 0,
                      ),
                  ],
                ),
              ),
              if (undecided) ...[
                const SizedBox(height: 16),
                InfoBanner(
                  icon: AppIcons.warning,
                  message:
                      'Check the official scholarship roster. A declaration alone is not proof.',
                  backgroundColor: context.colors.warningBg,
                  borderColor: context.colors.goldTintBorder,
                  iconColor: context.colors.warningText,
                  textColor: context.colors.goldTintText,
                  leading: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: context.colors.avatarTint,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      AppIcons.warning,
                      color: context.colors.warningText,
                      size: 19,
                    ),
                  ),
                  padding: const EdgeInsets.all(14),
                  borderRadius: 22,
                  fontSize: 12.5,
                ),
                const SizedBox(height: 12),
                Theme(
                  data: Theme.of(context).copyWith(
                    checkboxTheme: CheckboxThemeData(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      side: BorderSide(color: context.colors.border),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  child: CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    visualDensity: VisualDensity.compact,
                    activeColor: context.colors.brand,
                    title: Text(
                      'I verified this scholar against the official scholarship roster',
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    value: _rosterChecked,
                    onChanged: _busy
                        ? null
                        : (value) =>
                            setState(() => _rosterChecked = value ?? false),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Notes (optional)',
                  style: TextStyle(
                    color: context.colors.textLabel,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                AppTextField(
                  minLines: 3,
                  maxLines: 4,
                  controller: _notes,
                  decoration: InputDecoration(
                    hintText:
                        'Required when rejecting or requesting information',
                    hintStyle: TextStyle(color: context.colors.hintContrast),
                    filled: true,
                    fillColor: context.colors.surface,
                    alignLabelWithHint: true,
                    contentPadding: const EdgeInsets.all(14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: context.colors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: context.colors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: context.colors.brand),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: context.colors.brand,
                  title: Text(
                    'Ask for a new selfie',
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  value: _askForNewSelfie,
                  onChanged: _busy || !hasSelfie
                      ? null
                      : (value) => setState(() => _askForNewSelfie = value),
                ),
                const SizedBox(height: 8),
                PrimaryButton(
                  label: 'Approve verified scholar',
                  icon: AppIcons.shieldCheck,
                  minHeight: 56,
                  borderRadius: 18,
                  shadow: true,
                  onPressed: !_busy &&
                          _rosterChecked &&
                          u.declaredScholar &&
                          u.scholarshipName.isNotEmpty &&
                          hasSelfie
                      ? () => _decide(VerificationStatus.approved)
                      : null,
                  loading: _busyStatus == VerificationStatus.approved,
                ),
                if (!hasSelfie) ...[
                  const SizedBox(height: 8),
                  Text(
                    'A selfie is required before approval.',
                    style: TextStyle(
                      color: context.colors.textBody,
                      fontSize: 12.5,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                if (status == VerificationStatus.pending) ...[
                  SecondaryButton(
                    label: 'Mark under review',
                    icon: AppIcons.eye,
                    foregroundColor: context.colors.brand,
                    iconColor: context.colors.brand,
                    minHeight: 52,
                    borderRadius: 18,
                    onPressed: _busy
                        ? null
                        : () => _decide(VerificationStatus.underReview),
                    loading: _busyStatus == VerificationStatus.underReview,
                  ),
                  const SizedBox(height: 10),
                ],
                SecondaryButton(
                  label: 'Request information',
                  icon: AppIcons.error,
                  foregroundColor: context.colors.brand,
                  iconColor: context.colors.brand,
                  minHeight: 52,
                  borderRadius: 18,
                  onPressed: _busy
                      ? null
                      : () => _decide(VerificationStatus.needsInfo),
                  loading: _busyStatus == VerificationStatus.needsInfo,
                ),
                const SizedBox(height: 10),
                SecondaryButton(
                  label: 'Reject registration',
                  icon: AppIcons.cancel,
                  danger: true,
                  dangerTextColor: context.colors.dangerText,
                  iconColor: context.colors.dangerText,
                  borderColor: context.colors.dangerOutline,
                  minHeight: 52,
                  borderRadius: 18,
                  onPressed:
                      _busy ? null : () => _decide(VerificationStatus.rejected),
                  loading: _busyStatus == VerificationStatus.rejected,
                ),
              ],
              const SizedBox(height: 24),
              SectionLabel(
                'REVIEW HISTORY',
                labelColor: context.colors.textBody,
                fontSize: 11.5,
                letterSpacing: 1.2,
              ),
              const SizedBox(height: 8),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _history,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return AppCard(
                      radius: 22,
                      shadow: true,
                      child: Text(
                        'Review history could not be loaded.',
                        style: TextStyle(color: context.colors.textBody),
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.data!.isEmpty) {
                    return AppCard(
                      radius: 22,
                      shadow: true,
                      child: Text(
                        'No review recorded yet.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: context.colors.textBody),
                      ),
                    );
                  }
                  return Column(
                    children: snapshot.data!.map((review) {
                      final reviewStatus = verificationStatusFrom(
                        review['decision'],
                      );
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AppCard(
                          radius: 22,
                          shadow: true,
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              StatusChip(
                                reviewStatus.label,
                                color: _statusColor(context, reviewStatus),
                                bg: _statusBackground(context, reviewStatus),
                                borderRadius: 9,
                                fontSize: 11,
                                letterSpacing: .4,
                              ),
                              const SizedBox(height: 8),
                              _detailRow(
                                'Notes',
                                (review['notes'] ?? '').toString().isEmpty
                                    ? '—'
                                    : review['notes'].toString(),
                              ),
                              _detailRow(
                                  'Date', _historyDate(review['created_at'])),
                              _detailRow(
                                'Reviewer',
                                (review['reviewer_id'] ??
                                        'Scholar resubmission')
                                    .toString(),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _statusLabel(VerificationStatus status) => status.label;

Color _statusColor(BuildContext context, VerificationStatus status) =>
    switch (status) {
      VerificationStatus.pending => context.colors.warningText,
      VerificationStatus.needsInfo => context.colors.infoRequiredText,
      VerificationStatus.underReview => context.colors.brand,
      VerificationStatus.approved => context.colors.successText,
      VerificationStatus.rejected => context.colors.dangerText,
    };

Color _statusBackground(BuildContext context, VerificationStatus status) =>
    switch (status) {
      VerificationStatus.pending => context.colors.warningBg,
      VerificationStatus.needsInfo => context.colors.infoRequiredBg,
      VerificationStatus.underReview => context.colors.brandTint,
      VerificationStatus.approved => context.colors.successBg,
      VerificationStatus.rejected => context.colors.dangerBg,
    };

class _NoStretchScrollBehavior extends MaterialScrollBehavior {
  const _NoStretchScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) =>
      child;
}
