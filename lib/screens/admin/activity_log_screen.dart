import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/widgets.dart';

class ActivityLogScreen extends StatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  static const _recordLimit = 200;
  static const _allFilter = 'all';
  static const _payoutsFilter = 'payouts';

  List<AllowanceClaim> _claims = [];
  bool _loading = true;
  String? _error;
  String _selectedFilter = _allFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final claims = await context
          .read<AppState>()
          .wallet
          .getAllClaims(limit: _recordLimit);
      if (!mounted) return;
      setState(() {
        _claims = claims;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _claims = [];
        _error = '$error';
        _loading = false;
      });
    }
  }

  Future<void> _retry() async {
    setState(() => _loading = true);
    await _load();
  }

  List<_ActivityEvent> get _events {
    final events = <_ActivityEvent>[];
    for (final claim in _claims) {
      events.add(
        _ActivityEvent(
          claim: claim,
          kind: _ActivityKind.issued,
          timestamp: claim.issuedAt?.toLocal(),
        ),
      );
      if (claim.isReceived) {
        events.add(
          _ActivityEvent(
            claim: claim,
            kind: _ActivityKind.received,
            timestamp: claim.claimedAt?.toLocal(),
          ),
        );
      }
      if (claim.isVoided) {
        events.add(
          _ActivityEvent(
            claim: claim,
            kind: _ActivityKind.cancelled,
            timestamp: claim.issuedAt?.toLocal(),
          ),
        );
      }
    }
    events.sort((a, b) {
      final aTime = a.timestamp;
      final bTime = b.timestamp;
      if (aTime == null) return bTime == null ? 0 : 1;
      if (bTime == null) return -1;
      final timeOrder = bTime.compareTo(aTime);
      if (timeOrder != 0) return timeOrder;
      return a.kind.index.compareTo(b.kind.index);
    });
    return events;
  }

  Map<String, _ActivityDay> _groupEvents(List<_ActivityEvent> events) {
    final groups = <String, _ActivityDay>{};
    for (final event in events) {
      final date = event.timestamp;
      final key =
          date == null ? 'unavailable' : DateFormat('yyyy-MM-dd').format(date);
      groups.putIfAbsent(
        key,
        () => _ActivityDay(
          label: date == null
              ? 'DATE UNAVAILABLE'
              : DateFormat('MMM d, yyyy').format(date).toUpperCase(),
          events: [],
        ),
      );
      groups[key]!.events.add(event);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final events = _events;
    final groups = _groupEvents(events);
    final hasVoidedRecords = _claims.any((claim) => claim.isVoided);

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
          'Activity Log',
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          FilterChipsRow(
            items: const [
              FilterChipItem(value: _allFilter, label: 'All', count: 0),
              FilterChipItem(
                value: _payoutsFilter,
                label: 'Payouts',
                count: 0,
              ),
            ],
            selectedValue: _selectedFilter,
            onSelected: (value) => setState(() => _selectedFilter = value),
            showCount: false,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: InfoBanner(
              icon: AppIcons.info,
              message:
                  'Read-only. This list is built from existing payout records.',
              backgroundColor: colors.brandTint,
              iconColor: colors.brand,
              textColor: colors.brand,
              borderRadius: 18,
              fontSize: 13,
              padding: const EdgeInsets.all(16),
            ),
          ),
          if (hasVoidedRecords)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Text(
                'Cancelled entries show the available payout-record date; the cancellation time is not stored.',
                style: TextStyle(
                  color: colors.textBody,
                  fontSize: 11.5,
                ),
              ),
            ),
          Expanded(
            child: _loading
                ? _loadingContent(context)
                : _error != null
                    ? _errorContent()
                    : events.isEmpty
                        ? _emptyContent()
                        : _activityContent(groups),
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
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        children: [
          Container(
            width: 130,
            height: 14,
            color: colors.borderSoft,
          ),
          const SizedBox(height: 10),
          Divider(height: 1, thickness: 1, color: colors.borderSoft),
          for (var index = 0; index < 3; index++) ...[
            _skeletonRow(context),
            if (index < 2)
              Divider(height: 1, thickness: 1, color: colors.borderSoft),
          ],
        ],
      ),
    );
  }

  Widget _skeletonRow(BuildContext context) {
    final color = context.colors.borderSoft;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 150, height: 16, color: color),
                const SizedBox(height: 8),
                Container(width: 220, height: 13, color: color),
                const SizedBox(height: 5),
                Container(width: 120, height: 13, color: color),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorContent() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: [
        ErrorCard(
          message: 'Could not load activity.\n$_error',
          onRetry: _retry,
        ),
      ],
    );
  }

  Widget _emptyContent() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: const [
        EmptyState(
          icon: AppIcons.receipt,
          message: 'No activity yet.',
        ),
      ],
    );
  }

  Widget _activityContent(Map<String, _ActivityDay> groups) {
    final colors = context.colors;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        if (_claims.length == _recordLimit)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Showing the latest 200 records.',
              style: TextStyle(
                color: colors.textBody,
                fontSize: 11.5,
              ),
            ),
          ),
        for (final day in groups.values) ...[
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 8),
            child: Text(
              day.label,
              style: TextStyle(
                color: colors.textBody,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Divider(height: 1, thickness: 1, color: colors.borderSoft),
          for (var index = 0; index < day.events.length; index++) ...[
            _eventRow(context, day.events[index]),
            if (index < day.events.length - 1)
              Divider(height: 1, thickness: 1, color: colors.borderSoft),
          ],
        ],
      ],
    );
  }

  Widget _eventRow(BuildContext context, _ActivityEvent event) {
    final colors = context.colors;
    final details = event.details;
    final time = event.showTime && event.timestamp != null
        ? DateFormat('h:mm a').format(event.timestamp!)
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: details.backgroundColor(colors),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(
              details.icon,
              color: details.foregroundColor(colors),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        details.title,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (time != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        time,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: colors.textBody,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  details.subtitle(event.claim),
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
    );
  }
}

enum _ActivityKind { issued, received, cancelled }

class _ActivityEvent {
  const _ActivityEvent({
    required this.claim,
    required this.kind,
    required this.timestamp,
  });

  final AllowanceClaim claim;
  final _ActivityKind kind;
  final DateTime? timestamp;

  bool get showTime => kind != _ActivityKind.cancelled;

  _ActivityDetails get details => switch (kind) {
        _ActivityKind.issued => const _ActivityDetails(
            title: 'Payout issued',
            icon: AppIcons.qrCode,
            colorKind: _ActivityColorKind.brand,
          ),
        _ActivityKind.received => const _ActivityDetails(
            title: 'Payout received',
            icon: AppIcons.checkCircle,
            colorKind: _ActivityColorKind.success,
          ),
        _ActivityKind.cancelled => const _ActivityDetails(
            title: 'Payout cancelled',
            icon: AppIcons.cancel,
            colorKind: _ActivityColorKind.warning,
          ),
      };
}

enum _ActivityColorKind { brand, success, warning }

class _ActivityDetails {
  const _ActivityDetails({
    required this.title,
    required this.icon,
    required this.colorKind,
  });

  final String title;
  final IconData icon;
  final _ActivityColorKind colorKind;

  String subtitle(AllowanceClaim claim) => switch (colorKind) {
        _ActivityColorKind.brand =>
          '${claim.batchTitle} · ${claim.scholarName}',
        _ActivityColorKind.success =>
          '${claim.scholarName} · confirmed with device biometrics',
        _ActivityColorKind.warning =>
          '${claim.scholarName} · ${claim.batchTitle}',
      };

  Color backgroundColor(AppColors colors) => switch (colorKind) {
        _ActivityColorKind.brand => colors.brandTint,
        _ActivityColorKind.success => colors.successBg,
        _ActivityColorKind.warning => colors.warningBg,
      };

  Color foregroundColor(AppColors colors) => switch (colorKind) {
        _ActivityColorKind.brand => colors.brand,
        _ActivityColorKind.success => colors.successText,
        _ActivityColorKind.warning => colors.warningText,
      };
}

class _ActivityDay {
  const _ActivityDay({required this.label, required this.events});

  final String label;
  final List<_ActivityEvent> events;
}
