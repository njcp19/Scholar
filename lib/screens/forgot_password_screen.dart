import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icons.dart';
import '../widgets/password_reset_scaffold.dart';
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

  Widget _form(BuildContext context) {
    final colors = context.colors;
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: colors.border),
    );

    return AppCard(
      padding: const EdgeInsets.all(16),
      radius: 22,
      shadow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Email address',
            style: TextStyle(
              color: colors.textLabel,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          AppTextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            onSubmitted: (_) => _sendReset(),
            style: TextStyle(color: colors.textPrimary, fontSize: 16),
            decoration: InputDecoration(
              hintText: 'you@example.com',
              hintStyle: TextStyle(color: colors.hint),
              filled: true,
              fillColor: colors.surface,
              prefixIcon: Icon(AppIcons.mail, color: colors.brand, size: 22),
              prefixIconConstraints: const BoxConstraints(minWidth: 48),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: inputBorder,
              enabledBorder: inputBorder,
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: colors.brand, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: 'Send reset link',
            onPressed: _busy ? null : _sendReset,
            loading: _busy,
            minHeight: 56,
            borderRadius: 18,
            shadow: true,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return PasswordResetScaffold(
      icon: PasswordResetHeroIcon(
        icon: AppIcons.lock,
        backgroundColor: colors.avatarBackground,
        iconColor: colors.goldTintText,
      ),
      title: 'Forgot password?',
      subtitle:
          "No worries. Enter your email and we'll send you a link to reset it.",
      footer: BackToLoginLink(
        onPressed: () => Navigator.maybePop(context),
      ),
      child: _form(context),
    );
  }
}
