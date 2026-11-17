import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icons.dart';
import '../widgets/auth_hero_scaffold.dart';
import '../widgets/widgets.dart';
import 'check_email_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final String initialEmail;

  const ForgotPasswordScreen({
    super.key,
    required this.initialEmail,
  });

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final TextEditingController _email;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _sendReset() async {
    if (_busy) return;
    if (_email.text.isEmpty) {
      showMsg(context, 'Type your email first.', error: true);
      return;
    }

    setState(() => _busy = true);
    final auth = context.read<AppState>().auth;
    final email = _email.text;
    try {
      await auth.sendPasswordReset(email);
      if (!mounted) return;
      unawaited(
        Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => CheckEmailScreen(email: email.trim()),
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        showMsg(context, auth.friendlyError(error), error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _leading(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colors.cardShadow,
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(AppIcons.lock, color: colors.brand, size: 36),
    );
  }

  Widget _form(BuildContext context) {
    final colors = context.colors;
    OutlineInputBorder border(Color color, {double width = 1}) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: color, width: width),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Reset your password',
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter the email you registered with and we will send you a reset link.',
          style: TextStyle(
            color: colors.textBody,
            fontSize: 14.5,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'Email address',
          style: TextStyle(
            color: colors.textLabel,
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 54),
          child: AppTextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            onSubmitted: (_) => _sendReset(),
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 16,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: colors.surface,
              prefixIcon: Icon(
                AppIcons.mail,
                color: colors.brand,
                size: 22,
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 52),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              border: border(colors.border),
              enabledBorder: border(colors.border),
              focusedBorder: border(colors.brand, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 20),
        PrimaryButton(
          label: 'Send reset link',
          onPressed: _busy ? null : _sendReset,
          icon: AppIcons.send,
          loading: _busy,
          minHeight: 56,
          borderRadius: 18,
          shadow: true,
          iconSize: 22,
          iconSpacing: 10,
        ),
        const SizedBox(height: 14),
        InfoBanner(
          icon: AppIcons.info,
          message:
              'Check your spam folder if you do not see the email within a few minutes.',
          maxLines: 5,
          backgroundColor: colors.brandTint,
          iconColor: colors.brand,
          textColor: colors.brand,
          padding: const EdgeInsets.all(14),
          borderRadius: 18,
          fontSize: 14.5,
          textHeight: 1.45,
        ),
      ],
    );
  }

  Widget _footer(BuildContext context) {
    final colors = context.colors;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Center(
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Remembered it? ',
              style: TextStyle(
                color: colors.textBody,
                fontSize: 14.5,
              ),
            ),
            InkWell(
              onTap: () => Navigator.maybePop(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Back to Login',
                  style: TextStyle(
                    color: colors.brand,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthHeroScaffold(
      leading: _leading(context),
      title: 'Forgot password?',
      subtitle: 'No worries. We will email you a link to set a new one.',
      onBack: () => Navigator.maybePop(context),
      footer: _footer(context),
      child: _form(context),
    );
  }
}
