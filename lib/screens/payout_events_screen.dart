import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../data/demo_allowance_repository.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';
import '../widgets/app_icons.dart';
import 'admin/issue_payout_screen.dart';

/// Payout events are existing disbursement batches, not attendance events.
/// No generic event QR is accepted by the allowance scanner.
class PayoutEventsScreen extends StatefulWidget {
  const PayoutEventsScreen({super.key});
  @override
  State<PayoutEventsScreen> createState() => _PayoutEventsScreenState();
}

class _PayoutEventsScreenState extends State<PayoutEventsScreen> {
  List<Map<String, dynamic>> _events = [];
  bool _hasLoaded = false;
  String? _error;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final state = context.read<AppState>();
      List<Map<String, dynamic>> events;
      if (state.user!.role == UserRole.admin) {
        events = await state.wallet.getDisbursements();
      } else {
        // RLS returns only this scholar's claims. No recipient list is exposed.
        final claims = await state.wallet.getMyClaims(state.user!.id);
        final batches = <String, Map<String, dynamic>>{};
        for (final c in claims) {
          batches[c.batchId] = {
            'title': c.batchTitle,
            'amount_per_scholar': c.amount,
            'status': c.status.name,
            'created_at': c.issuedAt?.toIso8601String(),
            'distribution_date': c.distributionDate?.toIso8601String(),
          };
        }
        events = batches.values.toList();
      }
      if (mounted) {
        setState(() {
          _events = events;
          _error = null;
          _offline = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = 'Could not load payout events. Pull down to retry.';
          _offline = isOfflineLoadError(error);
        });
      }
    } finally {
      if (mounted) setState(() => _hasLoaded = true);
    }
  }

  DateTime? _eventDate(Map<String, dynamic> event) {
    final value = event['created_at'];
    if (value is DateTime) return value.toLocal();
    if (value == null) return null;
    return DateTime.tryParse(value.toString())?.toLocal();
  }

  String _formattedDistributionDate(Map<String, dynamic> event) {
    final value = event['distribution_date'];
    if (value == null) return '—';
    final date =
        value is DateTime ? value : DateTime.tryParse(value.toString());
    return date == null
        ? '—'
        : DateFormat('MMM d, yyyy').format(date.toLocal());
  }

  List<Map<String, dynamic>> _newestFirst() {
    final indexedEvents = _events.asMap().entries.toList();
    indexedEvents.sort((a, b) {
      final aDate = _eventDate(a.value);
      final bDate = _eventDate(b.value);
      if (aDate == null) return bDate == null ? a.key.compareTo(b.key) : 1;
      if (bDate == null) return -1;
      final dateOrder = bDate.compareTo(aDate);
      return dateOrder == 0 ? a.key.compareTo(b.key) : dateOrder;
    });
    return indexedEvents.map((entry) => entry.value).toList();
  }

  _PayoutStatusPresentation _statusPresentation(String? rawValue) {
    final raw = rawValue?.trim() ?? '';
    final normalized = raw.toLowerCase().replaceAll(RegExp(r'[\s-]+'), '_');
    switch (normalized) {
      case 'received':
        return _PayoutStatusPresentation(
          label: 'Received',
          foreground: AppTheme.successGreen,
          background: context.colors.successBg,
        );
      case 'issued':
      case 'pending':
      case 'waiting':
        return _PayoutStatusPresentation(
          label: 'Waiting',
          foreground: AppTheme.warningAmber,
          background: context.colors.warningBg,
        );
      case 'expired':
        return _PayoutStatusPresentation(
          label: 'Expired',
          foreground: context.colors.textBody,
          background: context.colors.borderSoft,
        );
      case 'voided':
      case 'cancelled':
      case 'canceled':
        return _PayoutStatusPresentation(
          label: 'Cancelled',
          foreground: context.colors.textBody,
          background: context.colors.borderSoft,
        );
      default:
        final label = raw
            .replaceAll(RegExp(r'[_-]+'), ' ')
            .split(RegExp(r'\s+'))
            .where((word) => word.isNotEmpty)
            .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
            .join(' ');
        return _PayoutStatusPresentation(
          label: label.isEmpty ? 'Unknown' : label,
          foreground: AppTheme.successGreen,
          background: context.colors.successBg,
        );
    }
  }

  List<Widget> _eventWidgets(
    List<Map<String, dynamic>> events, {
    required bool admin,
  }) {
    final widgets = <Widget>[];
    if (events.length <= 3) {
      widgets.add(const SizedBox(height: 12));
      for (final event in events) {
        widgets
          ..add(_eventCard(event, admin: admin))
          ..add(const SizedBox(height: 12));
      }
      return widgets;
    }

    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final event in events) {
      final date = _eventDate(event);
      final month = date == null
          ? 'DATE UNAVAILABLE'
          : DateFormat('MMMM yyyy').format(date).toUpperCase();
      grouped.putIfAbsent(month, () => []).add(event);
    }
    for (final group in grouped.entries) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 24, bottom: 8),
          child: Text(
            group.key,
            style: TextStyle(
              color: context.colors.textBody,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
        ),
      );
      for (final event in group.value) {
        widgets
          ..add(_eventCard(event, admin: admin))
          ..add(const SizedBox(height: 12));
      }
    }
    return widgets;
  }

  Widget _eventCard(
    Map<String, dynamic> event, {
    required bool admin,
  }) {
    final status = _statusPresentation(event['status']?.toString());
    final successful = status.background == context.colors.successBg;
    final waiting = status.label == 'Waiting';
    final iconBackground = successful
        ? context.colors.successBg
        : waiting
            ? context.colors.warningBg
            : context.colors.borderSoft;
    final iconColor = successful
        ? AppTheme.successGreen
        : waiting
            ? AppTheme.warningAmber
            : context.colors.hintContrast;
    final title = event['title']?.toString().trim();
    final academicPeriod = title == null
        ? null
        : DemoAllowanceRepository.instance.academicPeriodFor(title);
    final amount =
        fmtPhp(((event['amount_per_scholar'] ?? 0) as num).toDouble());
    final recipientCount = event['recipient_count'];

    return AppCard(
      radius: 22,
      shadow: true,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  AppIcons.calendar,
                  color: iconColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title == null || title.isEmpty
                          ? 'Allowance batch'
                          : title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 6,
                      runSpacing: 7,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        StatusChip(
                          status.label,
                          color: status.foreground,
                          bg: status.background,
                          borderRadius: 9,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          fontSize: 11,
                          letterSpacing: .4,
                        ),
                        if (academicPeriod != null)
                          StatusChip(
                            academicPeriod,
                            color: context.colors.brandTintText,
                            bg: context.colors.brandTint,
                            borderRadius: 9,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            fontSize: 10,
                            letterSpacing: 0,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 118),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    'PHP $amount',
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      color: context.colors.brand,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(
            height: 1,
            thickness: 1,
            color: context.colors.borderSoft,
          ),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Distribution date: ${_formattedDistributionDate(event)}',
                  style: TextStyle(
                    color: context.colors.textBody,
                    fontSize: 12.5,
                  ),
                ),
                if (admin && recipientCount != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Recipients: $recipientCount',
                    style: TextStyle(
                      color: context.colors.textBody,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard() {
    return InfoBanner(
      icon: AppIcons.info,
      message: 'Each payout event is one allowance batch with a single-use QR '
          'for you. Attendance or event QR codes cannot release allowance.',
      backgroundColor: context.colors.brandTint,
      iconColor: context.colors.brand,
      textColor: context.colors.textBody,
      maxLines: 4,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: context.colors.surface.withValues(alpha: .75),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(
          AppIcons.info,
          color: context.colors.brand,
          size: 20,
        ),
      ),
      padding: const EdgeInsets.all(16),
      borderRadius: 22,
      fontSize: 13,
      textHeight: 1.4,
    );
  }

  Future<void> _openIssuePayout() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const IssuePayoutScreen()),
    );
    await _load();
  }

  Widget _errorCard() {
    return ErrorCard(
      message: _offline
          ? 'Check your connection and try again. Your balance and payouts are not changed.'
          : _error ?? 'Could not load payout events. Pull down to retry.',
      onRetry: _load,
      prominent: true,
      offline: _offline,
    );
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: AppCard(
        radius: 22,
        shadow: true,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: context.colors.brandTint,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                AppIcons.calendar,
                color: context.colors.brand,
                size: 42,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No payout events yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Allowance batches issued to you will appear here',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.colors.textBody,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AppState>().user?.role == UserRole.admin;
    final events = _newestFirst();
    return Scaffold(
      backgroundColor: context.colors.background,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: admin
          ? Padding(
              padding: const EdgeInsets.only(right: 4, bottom: 4),
              child: SizedBox(
                height: 52,
                child: FloatingActionButton.extended(
                  heroTag: 'payout-events-issue-payout',
                  tooltip: 'Issue payout',
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onPressed: _openIssuePayout,
                  backgroundColor: context.colors.brand,
                  foregroundColor: context.colors.onHeader,
                  elevation: 8,
                  shape: const StadiumBorder(),
                  icon: const Icon(AppIcons.plus, size: 22),
                  label: const Text(
                    'Issue payout',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            )
          : null,
      appBar: AppBar(
        automaticallyImplyLeading: false,
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
        centerTitle: true,
        titleSpacing: 0,
        title: const Text(
          'Payout Events',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        backgroundColor: context.colors.background,
        foregroundColor: context.colors.textPrimary,
        surfaceTintColor: context.colors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: ClipRect(
        child: ScrollConfiguration(
          behavior: const _PayoutEventsScrollBehavior(),
          child: RefreshIndicator(
            onRefresh: _load,
            child: AppInitialLoadView(
              firstLoadPending: !_hasLoaded,
              skeleton: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(20, 16, 20, admin ? 96 : 24),
                children: [
                  _infoCard(),
                  const SizedBox(height: 16),
                  for (var index = 0; index < 2; index++) ...[
                    _PayoutEventSkeleton(showRecipients: admin),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
              child: ListView(
                clipBehavior: Clip.hardEdge,
                physics: const ClampingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: EdgeInsets.fromLTRB(20, 16, 20, admin ? 96 : 24),
                children: [
                  _infoCard(),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    _errorCard(),
                  ],
                  if (events.isEmpty && _error == null) ...[
                    const SizedBox(height: 16),
                    _emptyState(),
                  ] else if (events.isNotEmpty)
                    ..._eventWidgets(events, admin: admin),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PayoutStatusPresentation {
  final String label;
  final Color foreground;
  final Color background;

  const _PayoutStatusPresentation({
    required this.label,
    required this.foreground,
    required this.background,
  });
}

class _PayoutEventSkeleton extends StatelessWidget {
  final bool showRecipients;

  const _PayoutEventSkeleton({required this.showRecipients});

  @override
  Widget build(BuildContext context) {
    return SkeletonCard(
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(width: 44, height: 44, radius: 12),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonLine(width: 100, height: 16),
                    SizedBox(height: 7),
                    Wrap(
                      spacing: 6,
                      runSpacing: 7,
                      children: [
                        SkeletonBox(width: 76, height: 24, radius: 12),
                        SkeletonBox(width: 72, height: 24, radius: 12),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              SkeletonLine(width: 90, height: 17),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, thickness: 1, color: context.colors.borderSoft),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonLine(width: 176, height: 13),
                if (showRecipients) ...[
                  const SizedBox(height: 6),
                  const SkeletonLine(width: 88, height: 13),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PayoutEventsScrollBehavior extends MaterialScrollBehavior {
  const _PayoutEventsScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
