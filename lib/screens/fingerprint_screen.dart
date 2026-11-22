import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icons.dart';
import '../widgets/widgets.dart';

/// Binds the signed-in account to biometrics already enrolled by the device.
class FingerprintScreen extends StatefulWidget {
  /// When true the screen is a hard gate for a protected action.
  final bool required;

  const FingerprintScreen({super.key, this.required = false});

  @override
  State<FingerprintScreen> createState() => _FingerprintScreenState();
}

class _FingerprintScreenState extends State<FingerprintScreen> {
  bool _busy = false;
  bool _supported = true;
  bool _probing = true;
  List<String> _available = const [];

  @override
  void initState() {
    super.initState();
    _probe();
  }

  Future<void> _probe() async {
    final state = context.read<AppState>();
    final supported = await state.biometric.deviceSupportsBiometrics();
    final enrolled = await state.biometric.enrolledBiometrics();
    if (!mounted) return;
    setState(() {
      _supported = supported;
      _available = enrolled.map((type) => _label(type.name)).toList();
      _probing = false;
    });
  }

  String _label(String raw) {
    if (raw.contains('finger')) return 'Device biometrics';
    if (raw.contains('face')) return 'Face';
    if (raw.contains('iris')) return 'Iris';
    return 'Device biometric';
  }

  String _displayRegistrationError(String error) {
    if (error == 'Sign in again to register your fingerprint.') {
      return 'Sign in again to set up device biometrics.';
    }
    if (error ==
        'Fingerprint registration cancelled or failed. Add a fingerprint in '
            'your phone settings, then try again.') {
      return 'Device biometrics setup was cancelled or failed. Enable '
          'biometrics in your phone settings, then try again.';
    }
    return error;
  }

  Future<void> _register() async {
    setState(() => _busy = true);
    final state = context.read<AppState>();
    final error = await state.registerFingerprint();
    if (!mounted) return;
    setState(() => _busy = false);
    if (error == null) {
      showMsg(context, 'Device biometrics enabled successfully.');
      if (widget.required && Navigator.of(context).canPop()) {
        Navigator.pop(context, true);
      }
    } else {
      showMsg(context, _displayRegistrationError(error), error: true);
      _probe();
    }
  }

  Future<void> _remove() async {
    final ok = await ConfirmDialog.show(
      context,
      title: 'Remove device biometrics?',
      message: 'You will have to register again before you can receive an '
          'allowance payout.',
      confirmLabel: 'Remove',
      danger: true,
    );
    if (ok != true || !mounted) return;
    await context.read<AppState>().removeFingerprint();
    if (mounted) showMsg(context, 'Device biometrics removed.');
  }

  Widget _roundBackButton() {
    return Padding(
      padding: const EdgeInsets.only(left: 26),
      child: Material(
        color: context.colors.surface,
        shape: CircleBorder(
          side: BorderSide(color: context.colors.borderSoft),
        ),
        child: IconButton(
          onPressed: () => Navigator.maybePop(context),
          tooltip: 'Back',
          constraints: const BoxConstraints.tightFor(width: 44, height: 44),
          padding: EdgeInsets.zero,
          icon: Icon(AppIcons.back, color: context.colors.textPrimary),
        ),
      ),
    );
  }

  Widget _hero({
    required bool registered,
    required DateTime? enrolledAt,
    required bool isAdmin,
  }) {
    final start = registered
        ? context.colors.successText
        : context.colors.balanceHeroStart;
    final end =
        registered ? context.colors.success : context.colors.balanceHeroEnd;
    final textColor =
        registered ? context.colors.onGold : context.colors.balanceHeroText;
    final titleColor = registered ? Colors.white : textColor;
    final messageColor =
        registered ? Colors.white.withValues(alpha: .85) : textColor;
    final message = registered
        ? enrolledAt == null
            ? 'Enabled on this device'
            : 'Enabled ${DateFormat('MMM d, yyyy · h:mm a').format(enrolledAt.toLocal())}'
        : isAdmin
            ? 'It’s required before you can disburse or cancel a payout.'
            : 'It’s required before you can receive an allowance.';

    const heroRadius = BorderRadius.all(Radius.circular(28));
    return ClipRRect(
      borderRadius: heroRadius,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [start, end],
          ),
        ),
        child: CardDecorShapes(
          key: const ValueKey('biometric-hero-shapes'),
          color: Colors.white,
          borderRadius: heroRadius,
          circleSize: 115,
          blobSize: 125,
          circleOpacity: .12,
          blobOpacity: .12,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: registered
                        ? Colors.white.withValues(alpha: .16)
                        : textColor.withValues(alpha: .16),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: textColor.withValues(alpha: .12),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      registered ? AppIcons.checkCircle : AppIcons.fingerprint,
                      color: registered
                          ? context.colors.successText
                          : context.colors.onGold,
                      size: 34,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  registered
                      ? 'Device biometrics enabled'
                      : 'Set up device biometrics',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: messageColor,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepsCard() {
    const steps = [
      (
        title: 'Confirm with device biometrics',
        subtitle: 'Use biometrics already enabled on your phone',
      ),
      (
        title: 'Confirm on your device',
        subtitle: 'Your phone checks it, we never see it',
      ),
      (
        title: 'Receive your allowance',
        subtitle: 'Scan the QR and confirm each payout',
      ),
    ];

    return AppCard(
      radius: 22,
      shadow: true,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          for (var index = 0; index < steps.length; index++) ...[
            if (index > 0) Divider(height: 1, color: context.colors.borderSoft),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: index == 0
                          ? context.colors.brand
                          : context.colors.brandTint,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: index == 0
                            ? context.colors.onHeader
                            : context.colors.brand,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          steps[index].title,
                          style: TextStyle(
                            color: context.colors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          steps[index].subtitle,
                          style: TextStyle(
                            color: context.colors.textBody,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusInfo() {
    if (_probing) {
      return AppCard(
        radius: 22,
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: context.colors.brand,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Checking device biometrics…',
              style: TextStyle(color: context.colors.textBody),
            ),
          ],
        ),
      );
    }
    if (!_supported) {
      return InfoBanner(
        icon: AppIcons.error,
        message:
            'This device reports no biometric hardware. Enable biometrics in your device settings, then try again.',
        maxLines: 5,
        backgroundColor: context.colors.dangerBg,
        iconColor: context.colors.dangerText,
        textColor: context.colors.dangerText,
      );
    }
    if (_available.isEmpty) {
      return InfoBanner(
        icon: AppIcons.warning,
        message:
            'No biometrics are enrolled on this device yet. Add one in your device settings, then come back.',
        maxLines: 5,
        backgroundColor: context.colors.warningBg,
        iconColor: context.colors.warningText,
        textColor: context.colors.warningText,
      );
    }

    return AppCard(
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Available on this device:',
            style: TextStyle(
              color: context.colors.textBody,
              fontSize: 13,
            ),
          ),
          for (final type in _available)
            StatusChip(
              type,
              color: context.colors.brand,
              bg: context.colors.brandTint,
            ),
        ],
      ),
    );
  }

  Widget _bottomActions({required bool registered, required bool canRegister}) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!registered)
              PrimaryButton(
                label: 'Set up now',
                icon: AppIcons.fingerprint,
                loading: _busy,
                onPressed: canRegister && !_busy ? _register : null,
                minHeight: 56,
                borderRadius: 18,
                disabledBackgroundColor: context.colors.borderSoft,
                disabledForegroundColor: context.colors.textBody,
              )
            else ...[
              SecondaryButton(
                label: 'Enable again',
                icon: AppIcons.fingerprint,
                loading: _busy,
                onPressed: canRegister && !_busy ? _register : null,
                minHeight: 52,
                borderRadius: 18,
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: _busy ? null : _remove,
                style: TextButton.styleFrom(
                  foregroundColor: context.colors.dangerText,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Remove device biometrics'),
              ),
            ],
            if (!widget.required && !registered) ...[
              const SizedBox(height: 2),
              TextButton(
                onPressed: _busy ? null : () => Navigator.maybePop(context),
                style: TextButton.styleFrom(
                  foregroundColor: context.colors.textBody,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Not now'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final registered = state.fingerprintRegistered;
    final enrolledAt = state.fingerprintEnrolledAt;
    final isAdmin = state.user?.role == UserRole.admin;
    final canRegister = _supported && _available.isNotEmpty;

    return Scaffold(
      backgroundColor: context.colors.background,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        leadingWidth: 70,
        leading: _roundBackButton(),
        centerTitle: true,
        title: Text(
          'Device biometrics',
          style: TextStyle(
            color: context.colors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: context.colors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: ScrollConfiguration(
        behavior: const _FingerprintScrollBehavior(),
        child: ListView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            _hero(
              registered: registered,
              enrolledAt: enrolledAt,
              isAdmin: isAdmin,
            ),
            const SizedBox(height: 22),
            const SectionLabel('HOW IT WORKS'),
            const SizedBox(height: 10),
            _stepsCard(),
            const SizedBox(height: 20),
            _statusInfo(),
            const SizedBox(height: 16),
            Text(
              'Scholar Wallet uses biometrics already enrolled on your device. It does not capture or store biometric data.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.colors.textBody,
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _bottomActions(
        registered: registered,
        canRegister: canRegister,
      ),
    );
  }
}

class _FingerprintScrollBehavior extends MaterialScrollBehavior {
  const _FingerprintScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) =>
      child;
}
