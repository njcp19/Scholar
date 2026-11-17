import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icons.dart';
import '../widgets/auth_hero_scaffold.dart';
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
  static const _cooldownDuration = 45;
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

  String get _maskedEmail {
    final atIndex = widget.email.lastIndexOf('@');
    if (atIndex <= 0 || atIndex == widget.email.length - 1) {
      return widget.email;
    }

    final localPart = widget.email.substring(0, atIndex);
    final visiblePart = localPart.substring(
      0,
      localPart.length < 2 ? localPart.length : 2,
    );
    return '$visiblePart****${widget.email.substring(atIndex)}';
  }

  String get _countdownLabel {
    final minutes = (_secondsRemaining ~/ 60).toString();
    final seconds = (_secondsRemaining % 60).toString().padLeft(2, '0');
    return 'Resend link in $minutes:$seconds';
  }

  Widget _leading(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.onHeader.withValues(alpha: .2),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.success,
        ),
        alignment: Alignment.center,
        child: Icon(
          AppIcons.check,
          color: colors.onHeader,
          size: 30,
        ),
      ),
    );
  }

  Widget _emailChip(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.brandTint,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(
              AppIcons.mailCheck,
              color: colors.brand,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Link sent to',
                  style: TextStyle(
                    color: colors.textBody,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _maskedEmail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _step(BuildContext context, int number, String text) {
    final colors = context.colors;
    final active = number == 1;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? colors.brand : colors.brandTint,
          ),
          alignment: Alignment.center,
          child: Text(
            '$number',
            style: TextStyle(
              color: active ? colors.onHeader : colors.brand,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 15.5,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  void _backToLogin() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Widget _content(BuildContext context) {
    final colors = context.colors;
    final canResend = _secondsRemaining == 0 && !_resending;
    final announcement = _secondsRemaining == _cooldownDuration
        ? 'Resend link in 0:45.'
        : _secondsRemaining == 0
            ? 'Resend link is available.'
            : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _emailChip(context),
        const SizedBox(height: 18),
        Text(
          'If this email is registered, you will get a link to set a new password. The link expires after a short time.',
          style: TextStyle(
            color: colors.textBody,
            fontSize: 14.5,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 18),
        _step(context, 1, 'Open the email from Scholar Wallet'),
        const SizedBox(height: 14),
        _step(context, 2, 'Tap the link and choose a new password'),
        const SizedBox(height: 14),
        _step(context, 3, 'Come back and log in'),
        const SizedBox(height: 22),
        PrimaryButton(
          label: 'Back to Login',
          onPressed: _backToLogin,
          minHeight: 56,
          borderRadius: 18,
          shadow: true,
        ),
        const SizedBox(height: 10),
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
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthHeroScaffold(
      leading: _leading(context),
      title: 'Check your email',
      subtitle: 'We sent instructions to reset your password.',
      onBack: () => Navigator.maybePop(context),
      child: _content(context),
    );
  }
}
