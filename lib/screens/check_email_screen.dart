import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icons.dart';
import '../widgets/password_reset_scaffold.dart';
import '../widgets/widgets.dart';

class CheckEmailScreen extends StatefulWidget {
  final String email;

  const CheckEmailScreen({
    super.key,
    required this.email,
  });

  @override
  State<CheckEmailScreen> createState() => _CheckEmailScreenState();
}

class _CheckEmailScreenState extends State<CheckEmailScreen> {
  static const _cooldownDuration = 30;
  Timer? _timer;
  int _secondsRemaining = _cooldownDuration;
  bool _resending = false;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown({bool reset = false}) {
    _timer?.cancel();
    if (reset) {
      setState(() => _secondsRemaining = _cooldownDuration);
    } else {
      _secondsRemaining = _cooldownDuration;
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final next = _secondsRemaining - 1;
      setState(() => _secondsRemaining = next);
      if (next == 0) {
        timer.cancel();
        if (identical(_timer, timer)) _timer = null;
      }
    });
  }

  Future<void> _resend() async {
    if (_secondsRemaining > 0 || _resending) return;
    setState(() => _resending = true);
    final auth = context.read<AppState>().auth;

    try {
      await auth.sendPasswordReset(widget.email);
      if (!mounted) return;
      _startCooldown(reset: true);
      showMsg(context, 'Password reset email sent.');
    } catch (error) {
      if (mounted) {
        showMsg(context, auth.friendlyError(error), error: true);
      }
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  String get _countdownLabel {
    final minutes = (_secondsRemaining ~/ 60).toString();
    final seconds = (_secondsRemaining % 60).toString().padLeft(2, '0');
    return 'Resend in $minutes:$seconds';
  }

  Widget _emailPill(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: colors.avatarTint.withValues(alpha: .6),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        widget.email,
        maxLines: 2,
        softWrap: true,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: colors.onGold,
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  void _backToLogin() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Widget _content(BuildContext context) {
    final colors = context.colors;
    final canResend = _secondsRemaining == 0 && !_resending;
    final announcement = _secondsRemaining == _cooldownDuration
        ? 'Resend in 0:30.'
        : _secondsRemaining == 0
            ? 'Resend link is available.'
            : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: announcement != null,
          label: announcement,
          child: Semantics(
            button: true,
            enabled: canResend,
            label: 'Resend link',
            hint: canResend ? null : 'Available when the countdown ends.',
            onTap: canResend ? _resend : null,
            child: ExcludeSemantics(
              child: SecondaryButton(
                label: _secondsRemaining == 0 ? 'Resend link' : _countdownLabel,
                onPressed: canResend ? _resend : null,
                foregroundColor: canResend ? colors.brand : colors.textBody,
                loading: _resending,
                minHeight: 52,
                borderRadius: 18,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        InfoBanner(
          icon: AppIcons.info,
          message:
              "Didn't get it? Check your spam folder or try resending the link.",
          maxLines: 3,
          backgroundColor: colors.brandTint,
          iconColor: colors.brand,
          textColor: colors.brandTintText,
          borderRadius: 22,
        ),
        const SizedBox(height: 8),
        BackToLoginLink(onPressed: _backToLogin),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PasswordResetScaffold(
      icon: PasswordResetHeroIcon(
        icon: AppIcons.mail,
        backgroundColor: context.colors.surface,
        iconColor: context.colors.goldTintText,
      ),
      title: 'Check your email',
      subtitle: 'We sent a password reset link to',
      heroDetail: _emailPill(context),
      goldHero: true,
      onBack: _backToLogin,
      child: _content(context),
    );
  }
}
