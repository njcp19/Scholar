import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';
import '../widgets/app_icons.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _remember = true;
  bool _obscure = true;
  bool _busy = false;
  bool _bioBusy = false;
  bool _bioAvailable = false;
  bool _autoPrompted = false;

  static const _kRememberEmail = 'remember_email';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final state = context.read<AppState>();
    // FR-03 "Remember me": prefill the last used email.
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_kRememberEmail);
      if (saved != null && mounted) setState(() => _email.text = saved);
    } catch (_) {}

    // FR-26: biometric sign-in is offered only when it was enabled before.
    final creds = await state.biometric.savedCredentials();
    final supported = await state.biometric.deviceSupportsBiometrics();
    if (!mounted) return;
    setState(() => _bioAvailable = supported && creds != null);
    if (_bioAvailable && !_autoPrompted) {
      _autoPrompted = true;
      _bioLogin(); // show the biometric prompt right away
    }
  }

  Future<void> _login() async {
    if (_email.text.isEmpty || _password.text.isEmpty) {
      showMsg(context, 'Enter your email and password.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final state = context.read<AppState>();
      state.user =
          await state.auth.signIn(email: _email.text, password: _password.text);
      state.lastLoginPassword = _password.text;
      // FR-03 "Remember me": persist (or clear) the email.
      try {
        final prefs = await SharedPreferences.getInstance();
        if (_remember) {
          await prefs.setString(_kRememberEmail, _email.text.trim());
        } else {
          await prefs.remove(_kRememberEmail);
        }
      } catch (_) {}
      // AuthGate rebuilds automatically via authState stream.
    } catch (e) {
      if (mounted) {
        showMsg(context, context.read<AppState>().auth.friendlyError(e),
            error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// FR-26/FR-27: biometric prompt -> on success sign in with the on-device
  /// credentials; on failure/cancel the user simply uses the form above.
  Future<void> _bioLogin() async {
    final state = context.read<AppState>();
    final creds = await state.biometric.savedCredentials();
    if (!mounted) return;
    if (creds == null) {
      showMsg(context, 'Enable biometric login in Settings after signing in.',
          error: true);
      return;
    }
    setState(() => _bioBusy = true);
    final ok =
        await state.biometric.verify(reason: "Sign in to Scholar Wallet");
    if (!ok) {
      // FR-27 fallback: biometrics unavailable/failed -> password form stays.
      if (mounted) setState(() => _bioBusy = false);
      return;
    }
    try {
      state.user = await state.auth.signIn(email: creds.$1, password: creds.$2);
      state.lastLoginPassword = creds.$2;
    } catch (e) {
      if (mounted) {
        showMsg(
            context,
            'Saved credentials no longer work. '
            'Please sign in with your password.',
            error: true);
        await state.disableBiometric();
        setState(() => _bioAvailable = false);
      }
    } finally {
      if (mounted) setState(() => _bioBusy = false);
    }
  }

  Future<void> _forgot() async {
    if (_email.text.isEmpty) {
      showMsg(context, 'Type your email first.', error: true);
      return;
    }
    try {
      await context.read<AppState>().auth.sendPasswordReset(_email.text);
      if (mounted) showMsg(context, 'Password reset email sent.');
    } catch (e) {
      if (mounted) {
        showMsg(context, context.read<AppState>().auth.friendlyError(e),
            error: true);
      }
    }
  }

  TextStyle _fieldLabelStyle(BuildContext context) => TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: context.colors.textLabel,
      );

  InputDecoration _fieldDecoration(
    BuildContext context, {
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    final colors = context.colors;
    OutlineInputBorder border(Color color, {double width = 1}) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color, width: width),
        );

    return InputDecoration(
      filled: true,
      fillColor: colors.background,
      hintText: hint,
      hintStyle: TextStyle(fontSize: 14, color: colors.textBody),
      prefixIcon: Icon(icon, size: 20, color: colors.textBody),
      prefixIconConstraints: const BoxConstraints(minWidth: 48),
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: border(colors.borderSoft),
      enabledBorder: border(colors.borderSoft),
      focusedBorder: border(colors.brand, width: 2),
    );
  }

  Widget _field(BuildContext context, String label, Widget input) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: _fieldLabelStyle(context)),
          const SizedBox(height: 7),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: input,
          ),
        ],
      );

  Widget _heroPill(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: colors.onHeader.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.onHeader.withValues(alpha: .12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: colors.onHeader),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.onHeader,
            ),
          ),
        ],
      ),
    );
  }

  Widget _hero(BuildContext context, double height, double topInset) {
    final colors = context.colors;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(40),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [colors.header, colors.heroGradientEnd],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -72,
                right: -54,
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.onHeader.withValues(alpha: .08),
                  ),
                ),
              ),
              Positioned(
                bottom: -96,
                left: -76,
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.onHeader.withValues(alpha: .07),
                  ),
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, topInset + 12, 20, 12),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            color: colors.onHeader,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    colors.textPrimary.withValues(alpha: .12),
                                blurRadius: 18,
                                offset: const Offset(0, 7),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Image.asset(
                            'assets/images/logo.png',
                            width: 54,
                            height: 54,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              AppIcons.wallet,
                              size: 40,
                              color: colors.brand,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Scholar ',
                                  style: TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.w800,
                                    color: colors.onHeader,
                                  ),
                                ),
                                TextSpan(
                                  text: 'Wallet',
                                  style: TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.w800,
                                    color: colors.accentGold,
                                  ),
                                ),
                              ],
                            ),
                            maxLines: 1,
                            softWrap: false,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          'Simplifying financial allowances and expense tracking for your scholar life.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            color: colors.onHeader.withValues(alpha: .88),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _heroPill(
                              context,
                              icon: AppIcons.qrCode,
                              label: 'QR payouts',
                            ),
                            _heroPill(
                              context,
                              icon: AppIcons.fingerprint,
                              label: 'Biometrics secured',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _loginCard(BuildContext context) {
    final colors = context.colors;
    return AppCard(
      padding: const EdgeInsets.all(24),
      radius: 28,
      shadow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome back',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Log in to see your allowance.',
            style: TextStyle(fontSize: 14, color: colors.textBody),
          ),
          const SizedBox(height: 18),
          _field(
            context,
            'Email address',
            AppTextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              style: TextStyle(fontSize: 14, color: colors.textPrimary),
              decoration: _fieldDecoration(
                context,
                hint: 'you@example.com',
                icon: AppIcons.mail,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _field(
            context,
            'Password',
            AppTextField(
              controller: _password,
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _login(),
              style: TextStyle(fontSize: 14, color: colors.textPrimary),
              decoration: _fieldDecoration(
                context,
                hint: 'Password',
                icon: AppIcons.lock,
                suffix: IconButton(
                  tooltip: _obscure ? 'Show password' : 'Hide password',
                  icon: Icon(
                    _obscure ? AppIcons.eye : AppIcons.eyeOff,
                    size: 20,
                    color: colors.textBody,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: Checkbox(
                      value: _remember,
                      activeColor: colors.brand,
                      checkColor: colors.onHeader,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(7),
                      ),
                      side: BorderSide(color: colors.border),
                      onChanged: (value) =>
                          setState(() => _remember = value ?? true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Remember me',
                    style: TextStyle(fontSize: 13, color: colors.textBody),
                  ),
                ],
              ),
              InkWell(
                onTap: _forgot,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'Forgot password?',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: colors.brand,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: colors.brand.withValues(alpha: .22),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: PrimaryButton(
              label: 'Login',
              onPressed: _busy ? null : _login,
              loading: _busy,
              minHeight: 56,
              borderRadius: 18,
            ),
          ),
          if (_bioAvailable) ...[
            const SizedBox(height: 12),
            SecondaryButton(
              label: 'Login with biometrics',
              onPressed: _bioBusy ? null : _bioLogin,
              icon: AppIcons.fingerprint,
              iconColor: colors.brand,
              loading: _bioBusy,
              minHeight: 56,
              borderRadius: 18,
            ),
          ],
        ],
      ),
    );
  }

  Widget _signupPrompt(BuildContext context) {
    final colors = context.colors;
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          "Don't have an account? ",
          style: TextStyle(fontSize: 13, color: colors.textBody),
        ),
        InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SignupScreen()),
          ),
          child: Text(
            'Sign up',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: colors.brand,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: colors.header,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: colors.background,
        systemNavigationBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: colors.background,
        body: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final textScale = MediaQuery.textScalerOf(context).scale(1);
              final topInset = MediaQuery.paddingOf(context).top;
              final compact = constraints.maxWidth < 360;
              final contentHeight = math.max(
                constraints.maxHeight * .4,
                (compact ? 320.0 : 280.0) * textScale,
              );
              final heroHeight = contentHeight + topInset;
              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.only(
                  bottom: MediaQuery.paddingOf(context).bottom + 20,
                ),
                child: Column(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _hero(context, heroHeight, topInset),
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            20,
                            heroHeight - 40,
                            20,
                            0,
                          ),
                          child: _loginCard(context),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                      child: _signupPrompt(context),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
