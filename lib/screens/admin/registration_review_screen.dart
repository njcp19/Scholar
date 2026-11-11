import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../services/verification_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';
import '../../widgets/app_icons.dart';

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
  bool _loading = true;
  bool _initialFilterResolved = false;
  String? _error;
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
          if (!_initialFilterResolved) {
            if (!users.any(
                (u) => u.verificationStatus == VerificationStatus.pending)) {
              _filter = null;
            }
            _initialFilterResolved = true;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Could not load registrations. Check your connection, Firebase integration, and database migration.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
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
      appBar: AppBar(
        backgroundColor: context.colors.surface,
        foregroundColor: context.colors.textPrimary,
        surfaceTintColor: context.colors.surface,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(AppIcons.back),
        ),
        title: const Text('Registration Review'),
      ),
      body: ScrollConfiguration(
        behavior: const _NoStretchScrollBehavior(),
        child: RefreshIndicator(
          onRefresh: _load,
          child: ContentWidth(
            child: ListView(
              physics: const ClampingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: InfoBanner(
                    icon: AppIcons.info,
                    message:
                        'Verify existing scholars against the official roster. This is not an application for a new scholarship.',
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SectionLabel(
                    'REGISTRATIONS (${_users.length})',
                    labelColor: context.colors.textBody,
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SearchField(
                    controller: _searchController,
                    hintText: 'Search name or student number',
                    onChanged: (_) => setState(() {}),
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
                ),
                const SizedBox(height: 16),
                if (_loading)
                  SizedBox(
                    height: 180,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: context.colors.brand,
                      ),
                    ),
                  )
                else if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: ErrorCard(
                      message: _error!,
                      onRetry: _load,
                    ),
                  )
                else if (_users.isEmpty && !hasCriteria)
                  const EmptyState(
                    icon: AppIcons.userSearch,
                    title: 'No registrations in this status',
                    message: 'New registrations will appear here',
                  )
                else if (users.isEmpty)
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
                else
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
    );
  }
}

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
    final university = user.university?.trim();
    final subtitle =
        'ID ${user.studentNumber?.trim().isNotEmpty == true ? user.studentNumber : '—'} - '
        '${university?.isNotEmpty == true ? university : '—'}';

    return ListRowCard(
      onTap: onTap,
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: context.colors.brandTint,
            child: Text(
              user.initials,
              style: TextStyle(
                color: context.colors.brand,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontWeight: FontWeight.w800,
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
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 132),
              child: StatusChip(
                _statusLabel(status),
                color: _statusColor(context, status),
                bg: _statusBackground(context, status),
              ),
            ),
          ),
          const SizedBox(width: 2),
          Icon(
            AppIcons.chevronRight,
            color: context.colors.hint,
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

class _RegistrationDetailState extends State<_RegistrationDetail> {
  final _notes = TextEditingController();
  final _service = VerificationService();
  late Future<List<Map<String, dynamic>>> _history;
  bool _rosterChecked = false;
  bool _busy = false;
  VerificationStatus? _busyStatus;

  @override
  void initState() {
    super.initState();
    _history = _service.history(widget.user.id);
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
    final confirm = await ConfirmDialog.show(
      context,
      title: _statusLabel(status),
      message:
          '${widget.user.fullName}\n\n${status == VerificationStatus.approved ? "Approve this verified registration and enable payout access" : "Save this registration review"}?',
      confirmLabel: 'Save decision',
      danger: status == VerificationStatus.rejected,
    );
    if (confirm != true || !mounted) return;
    setState(() {
      _busy = true;
      _busyStatus = status;
    });
    try {
      await _service.review(widget.user, status, _notes.text);
      if (mounted) {
        showMsg(context, 'Registration review recorded.');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        showMsg(context,
            'Review was not saved. The status may have changed; reopen the registration and try again. ($e)',
            error: true);
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

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: TextStyle(
                color: context.colors.textBody,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: context.colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
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

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final status = u.verificationStatus;
    final undecided = status != VerificationStatus.approved &&
        status != VerificationStatus.rejected;

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: context.colors.surface,
        foregroundColor: context.colors.textPrimary,
        surfaceTintColor: context.colors.surface,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(AppIcons.back),
        ),
        title: const Text('Registration Review'),
      ),
      body: ScrollConfiguration(
        behavior: const _NoStretchScrollBehavior(),
        child: ContentWidth(
          child: ListView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      u.fullName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusChip(
                    _statusLabel(status),
                    color: _statusColor(context, status),
                    bg: _statusBackground(context, status),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SectionLabel(
                'SCHOLAR DETAILS',
                labelColor: context.colors.textBody,
              ),
              const SizedBox(height: 8),
              AppCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Column(
                  children: [
                    _detailRow('Email', u.email),
                    _detailRow('Student number', u.studentNumber ?? '—'),
                    _detailRow('School', u.university ?? '—'),
                    _detailRow('Program', u.program ?? '—'),
                    _detailRow('Year', u.yearLevel ?? '—'),
                    _detailRow(
                      'Declared scholar',
                      u.declaredScholar ? 'Yes' : 'No',
                    ),
                    _detailRow(
                      'Scholarship',
                      u.scholarshipName.isEmpty
                          ? 'Not provided'
                          : u.scholarshipName,
                    ),
                    _detailRow(
                      'Award reference',
                      u.scholarshipReference.isEmpty
                          ? 'Not provided'
                          : u.scholarshipReference,
                    ),
                    if (u.reviewNotes.isNotEmpty)
                      _detailRow('Previous feedback', u.reviewNotes),
                  ],
                ),
              ),
              if (undecided) ...[
                const SizedBox(height: 16),
                const InfoBanner(
                  icon: AppIcons.info,
                  message:
                      'Check the official scholarship roster. A declaration alone is not proof.',
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: context.colors.brand,
                  title: Text(
                    'I verified this scholar against the official scholarship roster',
                    style: TextStyle(color: context.colors.textPrimary),
                  ),
                  value: _rosterChecked,
                  onChanged: _busy
                      ? null
                      : (value) =>
                          setState(() => _rosterChecked = value ?? false),
                ),
                AppCard(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    controller: _notes,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Review notes / reason',
                      helperText:
                          'Required when rejecting or requesting information',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (status == VerificationStatus.pending) ...[
                  SecondaryButton(
                    label: 'Mark under review',
                    onPressed: _busy
                        ? null
                        : () => _decide(VerificationStatus.underReview),
                    loading: _busyStatus == VerificationStatus.underReview,
                  ),
                  const SizedBox(height: 8),
                ],
                SecondaryButton(
                  label: 'Request information',
                  onPressed: _busy
                      ? null
                      : () => _decide(VerificationStatus.needsInfo),
                  loading: _busyStatus == VerificationStatus.needsInfo,
                ),
                const SizedBox(height: 8),
                PrimaryButton(
                  label: 'Approve verified scholar',
                  onPressed: !_busy &&
                          _rosterChecked &&
                          u.declaredScholar &&
                          u.scholarshipName.isNotEmpty
                      ? () => _decide(VerificationStatus.approved)
                      : null,
                  loading: _busyStatus == VerificationStatus.approved,
                ),
                const SizedBox(height: 8),
                SecondaryButton(
                  label: 'Reject registration',
                  danger: true,
                  onPressed:
                      _busy ? null : () => _decide(VerificationStatus.rejected),
                  loading: _busyStatus == VerificationStatus.rejected,
                ),
              ],
              const SizedBox(height: 24),
              SectionLabel(
                'REVIEW HISTORY',
                labelColor: context.colors.textBody,
              ),
              const SizedBox(height: 8),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _history,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const AppCard(
                      child: Text('Review history could not be loaded.'),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.data!.isEmpty) {
                    return const AppCard(
                      child: Text('No review recorded yet.'),
                    );
                  }
                  return Column(
                    children: snapshot.data!
                        .map(
                          (review) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: AppCard(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  StatusChip(
                                    _statusLabel(verificationStatusFrom(
                                        review['decision'])),
                                    color: context.colors.brand,
                                    bg: context.colors.brandTint,
                                  ),
                                  const SizedBox(height: 8),
                                  _detailRow(
                                    'Notes',
                                    (review['notes'] ?? '').toString().isEmpty
                                        ? '—'
                                        : review['notes'].toString(),
                                  ),
                                  _detailRow('Date',
                                      _historyDate(review['created_at'])),
                                  _detailRow(
                                    'Reviewer',
                                    (review['reviewer_id'] ??
                                            'Scholar resubmission')
                                        .toString(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                        .toList(),
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

String _statusLabel(VerificationStatus status) => switch (status) {
      VerificationStatus.pending => 'Pending verification',
      VerificationStatus.underReview => 'Under review',
      VerificationStatus.needsInfo => 'Information required',
      VerificationStatus.approved => 'Verified',
      VerificationStatus.rejected => 'Rejected',
    };

Color _statusColor(BuildContext context, VerificationStatus status) =>
    switch (status) {
      VerificationStatus.pending ||
      VerificationStatus.needsInfo =>
        context.colors.warning,
      VerificationStatus.underReview => context.colors.brand,
      VerificationStatus.approved => context.colors.success,
      VerificationStatus.rejected => context.colors.danger,
    };

Color _statusBackground(BuildContext context, VerificationStatus status) =>
    switch (status) {
      VerificationStatus.pending ||
      VerificationStatus.needsInfo =>
        context.colors.warningBg,
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
