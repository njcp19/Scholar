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
  bool _loading = true;
  String? _error;

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
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
            () => _error = 'Could not load payout events. Pull down to retry.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
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
          foreground: context.colors.textBody,
          background: context.colors.borderSoft,
        );
    }
  }

  List<Widget> _eventWidgets(
    List<Map<String, dynamic>> events, {
    required bool admin,
  }) {
    final widgets = <Widget>[];
    if (events.length <= 3) {
      widgets.add(const SizedBox(height: 16));
      for (final event in events) {
        widgets
          ..add(_eventCard(event, admin: admin))
          ..add(const SizedBox(height: 16));
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
              color: context.colors.hint,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
        ),
      );
      for (final event in group.value) {
        widgets
          ..add(_eventCard(event, admin: admin))
          ..add(const SizedBox(height: 16));
      }
    }
    return widgets;
  }

  Widget _eventCard(
    Map<String, dynamic> event, {
    required bool admin,
  }) {
    final status = _statusPresentation(event['status']?.toString());
    final received = status.label == 'Received';
    final iconBackground = received
        ? context.colors.successBg
        : status.label == 'Waiting'
            ? context.colors.warningBg
            : context.colors.borderSoft;
    final title = event['title']?.toString().trim();
    final academicPeriod = title == null
        ? null
        : DemoAllowanceRepository.instance.academicPeriodFor(title);
    final amount =
        fmtPhp(((event['amount_per_scholar'] ?? 0) as num).toDouble());
    final recipientCount = event['recipient_count'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                  color: context.colors.brand,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title == null || title.isEmpty
                                ? 'Allowance batch'
                                : title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.colors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 112,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'PHP $amount',
                                maxLines: 1,
                                softWrap: false,
                                style: TextStyle(
                                  color: received
                                      ? AppTheme.successGreen
                                      : context.colors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (academicPeriod != null) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          StatusChip(
                            academicPeriod,
                            color: context.colors.textPrimary,
                            bg: context.colors.brandTint,
                          ),
                          StatusChip(
                            'Demo data',
                            color: context.colors.textBody,
                            bg: context.colors.borderSoft,
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      'Distribution date: ${_formattedDistributionDate(event)}',
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
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _StatusChip(status: status),
              if (admin && recipientCount != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Recipients: $recipientCount',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      color: context.colors.textBody,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
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
              'Each payout event is one allowance batch with a single-use QR '
              'for you. Attendance or event QR codes cannot release allowance.',
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
                  _error ?? 'Could not load payout events.',
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

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 56),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: context.colors.brandTint,
              shape: BoxShape.circle,
            ),
            child: Icon(
              AppIcons.calendar,
              color: context.colors.brand,
              size: 24,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No payout events yet',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Allowance batches issued to you will appear here',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.colors.textBody,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AppState>().user?.role == UserRole.admin;
    final events = _newestFirst();
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
        title: const Text('Payout Events'),
        backgroundColor: context.colors.background,
        foregroundColor: context.colors.textPrimary,
        surfaceTintColor: context.colors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      floatingActionButton: admin
          ? FloatingActionButton.extended(
              icon: Icon(
                AppIcons.plus,
                color: context.colors.brand,
              ),
              label: const Text('Issue payout'),
              onPressed: () async {
                await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const IssuePayoutScreen()));
                if (mounted) await _load();
              })
          : null,
      body: ClipRect(
        child: ScrollConfiguration(
          behavior: const _PayoutEventsScrollBehavior(),
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
                            ..._eventWidgets(
                              [
                                {
                                  'title': 'Payout Event',
                                  'amount_per_scholar': 12345,
                                  'status': 'issued',
                                  'created_at':
                                      DateTime(2026, 11, 8).toIso8601String(),
                                  'recipient_count': admin ? 24 : null,
                                },
                                {
                                  'title': 'Monthly Allowance',
                                  'amount_per_scholar': 12345,
                                  'status': 'issued',
                                  'created_at':
                                      DateTime(2026, 10, 8).toIso8601String(),
                                  'recipient_count': admin ? 24 : null,
                                },
                                {
                                  'title': 'Payout Event',
                                  'amount_per_scholar': 12345,
                                  'status': 'issued',
                                  'created_at':
                                      DateTime(2026, 9, 8).toIso8601String(),
                                  'recipient_count': admin ? 24 : null,
                                },
                              ],
                              admin: admin,
                            ),
                          ],
                        ),
                      ),
                    ]
                  : [
                      _infoCard(),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        _errorCard(),
                      ] else if (events.isEmpty) ...[
                        const SizedBox(height: 16),
                        _emptyState(),
                      ] else
                        ..._eventWidgets(events, admin: admin),
                    ],
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

class _StatusChip extends StatelessWidget {
  final _PayoutStatusPresentation status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: status.background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: status.foreground,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            status.label,
            style: TextStyle(
              color: status.foreground,
              fontSize: 11,
              fontWeight: FontWeight.w600,
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
