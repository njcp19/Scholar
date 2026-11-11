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
                  title: const Text('Update verification details'),
                  content: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('I am already a scholar'),
                        value: declared,
                        onChanged: (v) => update(() => declared = v)),
                    const SizedBox(height: 12),
                    const Text(
                        'These details return to the administrator for verification. No new scholarship application is created.'),
                  ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () {
                          Navigator.pop(ctx, true);
                        },
                        child: const Text('Resubmit details')),
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
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: widget.gate || Navigator.of(context).canPop()
            ? IconButton(
                tooltip: widget.gate ? 'Back to login' : 'Back',
                icon: Icon(
                  AppIcons.back,
                  color: context.colors.textPrimary,
                ),
                onPressed: widget.gate
                    ? () => confirmLogout(context)
                    : () => Navigator.maybePop(context),
              )
            : null,
        title: const Text('Scholar Verification'),
      ),
      body: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            children: [
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: u.canReceiveAllowance
                        ? context.colors.successBg
                        : context.colors.warningBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    AppIcons.shieldCheck,
                    size: 24,
                    color: u.canReceiveAllowance
                        ? context.colors.brand
                        : context.colors.textLabel,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(u.verificationStatus.label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              Text(_explanation(u), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              Card(
                  child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(u.fullName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            Text(
                                'Student number: ${u.studentNumber ?? "Not provided"}'),
                            Text('School: ${u.university ?? "Not provided"}'),
                            Text('Program: ${u.program ?? "Not provided"}'),
                            Text('Year: ${u.yearLevel ?? "Not provided"}'),
                            Text(
                                'Declared scholar: ${u.declaredScholar ? "Yes" : "No"}'),
                            Text(
                                'Existing scholarship: ${u.scholarshipName.isEmpty ? "Not provided" : u.scholarshipName}'),
                            if (u.scholarshipReference.isNotEmpty)
                              Text('Reference: ${u.scholarshipReference}'),
                          ]))),
              if (u.reviewNotes.isNotEmpty)
                Card(
                    child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Administrator feedback',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              Text(u.reviewNotes),
                            ]))),
              const SizedBox(height: 16),
              if (_error != null)
                Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              FilledButton.icon(
                  onPressed: _busy ? null : _refresh,
                  icon: Icon(
                    AppIcons.refresh,
                    color: context.colors.brand,
                  ),
                  label: Text(
                      _busy ? 'Checking…' : 'Refresh verification status')),
              if (u.verificationStatus == VerificationStatus.needsInfo)
                OutlinedButton(
                    onPressed: _busy ? null : () => _correct(u),
                    child: const Text('Update requested information')),
              const SizedBox(height: 18),
              const Text(
                  'Registration → Admin verification → Approved scholar → Payout QR → Review amount → Biometrics → Allowance received',
                  textAlign: TextAlign.center),
            ],
          )),
    );
  }
}
