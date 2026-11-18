import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../services/verification_service.dart';
import '../widgets/widgets.dart';
import '../widgets/app_icons.dart';
import '../theme/app_theme.dart';

class VerificationScreen extends StatefulWidget {
  final bool gate;
  const VerificationScreen({super.key, this.gate = false});
  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _refresh() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AppState>().refreshProfile();
    } catch (_) {
      if (mounted) {
        setState(() =>
            _error = 'Could not refresh. Check your connection and try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _correct(AppUser user) async {
    bool declared = user.declaredScholar;
    final submit = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, update) => AlertDialog(
                  backgroundColor: context.colors.surface,
                  surfaceTintColor: context.colors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                    side: BorderSide(color: context.colors.borderSoft),
                  ),
                  title: Text(
                    'Update verification details',
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  content: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        activeThumbColor: context.colors.brand,
                        title: Text(
                          'I am already a scholar',
                          style: TextStyle(color: context.colors.textPrimary),
                        ),
                        value: declared,
                        onChanged: (v) => update(() => declared = v)),
                    const SizedBox(height: 12),
                    Text(
                      'These details return to the administrator for verification. No new scholarship application is created.',
                      style: TextStyle(
                        color: context.colors.textBody,
                        height: 1.45,
                      ),
                    ),
                  ])),
                  actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                  actionsAlignment: MainAxisAlignment.center,
                  actions: [
                    TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(64, 52),
                        foregroundColor: context.colors.textBody,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: BorderSide(color: context.colors.border),
                        ),
                      ),
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(64, 52),
                        backgroundColor: context.colors.brand,
                        foregroundColor: context.colors.onHeader,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx, true);
                      },
                      child: const Text('Resubmit details'),
                    ),
                  ],
                )));
    final scholarshipName = user.scholarshipName.isEmpty
        ? 'Existing scholarship'
        : user.scholarshipName;
    final scholarshipReference = user.scholarshipReference;
    // Dialog routes animate out before their text controllers are disposed.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (submit != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await VerificationService().resubmit(
          declaredScholar: declared,
          scholarshipName: scholarshipName,
          scholarshipReference: scholarshipReference);
      if (!mounted) return;
      await _refresh();
    } catch (_) {
      if (mounted) {
        showMsg(
            context, 'Could not resubmit. Refresh the status and try again.',
            error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _explanation(AppUser u) => switch (u.verificationStatus) {
        VerificationStatus.pending =>
          'Your registration is waiting for admin verification against the official scholarship roster. You do not need to apply for a scholarship again.',
        VerificationStatus.underReview =>
          'An administrator is checking your existing scholar status and registration details.',
        VerificationStatus.needsInfo =>
          'The administrator needs the information below. Update the same registration; do not submit a new scholarship application.',
        VerificationStatus.rejected =>
          'The administrator could not verify your existing scholarship. Contact the scholarship office about the reason below. Payout access is disabled.',
        VerificationStatus.approved => u.isActive
            ? 'Your existing scholar status has been verified. No separate scholarship application is required.'
            : 'Your scholar status is verified, but payout access is currently inactive. Contact the administrator.',
      };

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final u = state.user;
    if (u == null) {
      return const Scaffold(body: Center(child: Text('Please sign in again.')));
    }
    final status = u.verificationStatus;
    final adminVerificationDone = status == VerificationStatus.rejected ||
        status == VerificationStatus.approved;
    final approvedScholarCurrent = status == VerificationStatus.approved;
    final registrationRows = <MapEntry<String, String>>[
      MapEntry('Name', u.fullName),
      MapEntry('Student number', u.studentNumber ?? 'Not provided'),
      MapEntry('School', u.university ?? 'Not provided'),
      MapEntry('Program', u.program ?? 'Not provided'),
      MapEntry('Year', u.yearLevel ?? 'Not provided'),
      MapEntry('Declared scholar', u.declaredScholar ? 'Yes' : 'No'),
      MapEntry(
        'Existing scholarship',
        u.scholarshipName.isEmpty ? 'Not provided' : u.scholarshipName,
      ),
      if (u.scholarshipReference.isNotEmpty)
        MapEntry('Reference', u.scholarshipReference),
    ];

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: context.colors.background,
        foregroundColor: context.colors.textPrimary,
        surfaceTintColor: context.colors.background,
        elevation: 0,
        centerTitle: true,
        titleSpacing: 0,
        leadingWidth: 70,
        leading: widget.gate || Navigator.of(context).canPop()
            ? Padding(
                padding: const EdgeInsets.only(left: 26),
                child: IconButton(
                  tooltip: widget.gate ? 'Back to login' : 'Back',
                  style: IconButton.styleFrom(
                    fixedSize: const Size.square(44),
                    padding: EdgeInsets.zero,
                    backgroundColor: context.colors.surface,
                    side: BorderSide(color: context.colors.borderSoft),
                    shape: const CircleBorder(),
                  ),
                  icon: const Icon(AppIcons.back),
                  onPressed: widget.gate
                      ? () => confirmLogout(context)
                      : () => Navigator.maybePop(context),
                ),
              )
            : null,
        title: const Text(
          'Scholar verification',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
      ),
      body: ContentWidth(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              AppCard(
                radius: 28,
                shadow: true,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: _statusTint(context, status),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        _statusIcon(status),
                        size: 36,
                        color: _statusColor(context, status),
                      ),
                    ),
                    const SizedBox(height: 16),
                    StatusChip(
                      status.label,
                      color: _statusColor(context, status),
                      bg: _statusTint(context, status),
                      borderRadius: 12,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      fontSize: 14,
                      letterSpacing: 0,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _explanation(u),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: context.colors.textBody,
                        fontSize: 13.5,
                        height: 1.55,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AppCard(
                radius: 22,
                shadow: true,
                padding: const EdgeInsets.fromLTRB(12, 20, 12, 16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: _VerificationProgressStep(
                            number: 1,
                            label: 'Registration',
                            done: true,
                            current: false,
                          ),
                        ),
                        Expanded(
                          child: _VerificationProgressStep(
                            number: 2,
                            label: 'Admin verification',
                            done: adminVerificationDone,
                            current: !adminVerificationDone,
                          ),
                        ),
                        Expanded(
                          child: _VerificationProgressStep(
                            number: 3,
                            label: 'Approved scholar',
                            done: false,
                            current: approvedScholarCurrent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Then: Payout QR → Review amount → Biometrics → Allowance received',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: context.colors.textBody,
                        fontSize: 13.5,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              if (u.reviewNotes.isNotEmpty) ...[
                const SizedBox(height: 16),
                _AdministratorFeedback(
                  status: status,
                  message: u.reviewNotes,
                ),
              ],
              const SizedBox(height: 24),
              SectionLabel(
                'YOUR REGISTRATION',
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
                    for (var index = 0;
                        index < registrationRows.length;
                        index++)
                      _VerificationDetailRow(
                        label: registrationRows[index].key,
                        value: registrationRows[index].value,
                        divider: index > 0,
                      ),
                  ],
                ),
              ),
              if (status == VerificationStatus.needsInfo) ...[
                const SizedBox(height: 16),
                PrimaryButton(
                  label: 'Update requested information',
                  onPressed: _busy ? null : () => _correct(u),
                  minHeight: 56,
                  borderRadius: 18,
                  shadow: true,
                ),
              ],
              const SizedBox(height: 10),
              SecondaryButton(
                label: 'Refresh verification status',
                loadingLabel: 'Checking…',
                icon: AppIcons.refresh,
                foregroundColor: context.colors.brand,
                iconColor: context.colors.brand,
                minHeight: 52,
                borderRadius: 18,
                loading: _busy,
                onPressed: _busy ? null : _refresh,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                ErrorCard(
                  message: _error!,
                  onRetry: _refresh,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

IconData _statusIcon(VerificationStatus status) => switch (status) {
      VerificationStatus.pending => AppIcons.clock,
      VerificationStatus.underReview => AppIcons.eye,
      VerificationStatus.needsInfo => AppIcons.error,
      VerificationStatus.rejected => AppIcons.cancel,
      VerificationStatus.approved => AppIcons.shieldCheck,
    };

Color _statusColor(BuildContext context, VerificationStatus status) =>
    switch (status) {
      VerificationStatus.pending => context.colors.warningText,
      VerificationStatus.underReview => context.colors.brand,
      VerificationStatus.needsInfo => context.colors.infoRequiredText,
      VerificationStatus.rejected => context.colors.dangerText,
      VerificationStatus.approved => context.colors.successText,
    };

Color _statusTint(BuildContext context, VerificationStatus status) =>
    switch (status) {
      VerificationStatus.pending => context.colors.warningBg,
      VerificationStatus.underReview => context.colors.brandTint,
      VerificationStatus.needsInfo => context.colors.infoRequiredBg,
      VerificationStatus.rejected => context.colors.dangerBg,
      VerificationStatus.approved => context.colors.successBg,
    };

class _VerificationProgressStep extends StatelessWidget {
  final int number;
  final String label;
  final bool done;
  final bool current;

  const _VerificationProgressStep({
    required this.number,
    required this.label,
    required this.done,
    required this.current,
  });

  @override
  Widget build(BuildContext context) {
    final circleColor = done
        ? context.colors.successAccent
        : current
            ? context.colors.brand
            : context.colors.brandTint;
    final numberColor =
        done || current ? context.colors.onHeader : context.colors.brand;
    return Column(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: circleColor,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: done
              ? Icon(AppIcons.check, size: 18, color: numberColor)
              : Text(
                  '$number',
                  style: TextStyle(
                    color: numberColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: current || done
                ? context.colors.textPrimary
                : context.colors.textBody,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _AdministratorFeedback extends StatelessWidget {
  final VerificationStatus status;
  final String message;

  const _AdministratorFeedback({
    required this.status,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isInformationRequired = status == VerificationStatus.needsInfo;
    final isRejected = status == VerificationStatus.rejected;
    final backgroundColor = isInformationRequired
        ? colors.warningBg
        : isRejected
            ? colors.dangerBg
            : colors.surface;
    final borderColor = isInformationRequired
        ? colors.goldTintBorder
        : isRejected
            ? colors.dangerOutline
            : colors.borderSoft;
    final textColor = isInformationRequired
        ? colors.goldTintText
        : isRejected
            ? colors.dangerFeedbackText
            : colors.textBody;

    return AppCard(
      radius: 22,
      padding: const EdgeInsets.all(16),
      backgroundColor: backgroundColor,
      borderColor: borderColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Administrator feedback',
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: TextStyle(
              color: textColor,
              fontSize: 14,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _VerificationDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool divider;

  const _VerificationDetailRow({
    required this.label,
    required this.value,
    required this.divider,
  });

  @override
  Widget build(BuildContext context) {
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
}
