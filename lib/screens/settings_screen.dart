import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icons.dart';
import '../widgets/widgets.dart';
import 'admin/admin_dashboard_screen.dart';
import 'admin/claims_monitor_screen.dart';
import 'admin/manage_scholars_screen.dart';
import 'claims_screen.dart';
import 'fingerprint_screen.dart';
import 'history_screen.dart';
import 'home_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _kRememberEmail = 'remember_email';

  Future<String?> _askPassword() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm password'),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Enter your password'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<bool> _enableBiometricLogin() async {
    final state = context.read<AppState>();
    if (!state.fingerprintRegistered) {
      showMsg(context, 'Enable device biometrics first.', error: true);
      return false;
    }
    final password = await _askPassword();
    if (password == null || password.isEmpty) return false;
    try {
      await state.auth.signIn(email: state.user!.email, password: password);
      await state.enableBiometric(state.user!.email, password);
      if (mounted) showMsg(context, 'Biometric login enabled.');
      return true;
    } catch (_) {
      if (mounted) showMsg(context, 'Incorrect password.', error: true);
      return false;
    }
  }

  Color _verificationColor(BuildContext context, VerificationStatus status) {
    return switch (status) {
      VerificationStatus.approved => context.colors.successText,
      VerificationStatus.rejected => context.colors.dangerText,
      VerificationStatus.underReview => context.colors.brand,
      VerificationStatus.pending ||
      VerificationStatus.needsInfo =>
        context.colors.warningText,
    };
  }

  Color _verificationBackground(
    BuildContext context,
    VerificationStatus status,
  ) {
    return switch (status) {
      VerificationStatus.approved => context.colors.successBg,
      VerificationStatus.rejected => context.colors.dangerBg,
      VerificationStatus.underReview => context.colors.brandTint,
      VerificationStatus.pending ||
      VerificationStatus.needsInfo =>
        context.colors.warningBg,
    };
  }

  Future<void> _openScreen(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _navigate(int index, bool isAdmin) async {
    if (isAdmin) {
      switch (index) {
        case 0:
          await _openScreen(const AdminDashboardScreen());
        case 1:
          await _openScreen(const ClaimsMonitorScreen());
        case 2:
          await _openScreen(const ManageScholarsScreen());
      }
    } else {
      switch (index) {
        case 0:
          await _openScreen(const HomeScreen());
        case 1:
          await _openScreen(const HistoryScreen());
        case 2:
          await _openScreen(const ClaimsScreen());
      }
    }
  }

  Widget _rolePill({
    required String label,
    required Color color,
    required Color background,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileHero({
    required AppUser? user,
    required bool isAdmin,
  }) {
    final foreground =
        isAdmin ? context.colors.onHeader : context.colors.balanceHeroText;
    final gradient = isAdmin
        ? [context.colors.header, context.colors.heroGradientEnd]
        : [context.colors.balanceHeroStart, context.colors.balanceHeroEnd];

    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -116,
              right: -42,
              child: _circle(foreground.withValues(alpha: .12), 230),
            ),
            Positioned(
              bottom: -132,
              right: -112,
              child: _circle(foreground.withValues(alpha: .1), 250),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: foreground.withValues(alpha: .2),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: context.colors.avatarBackground,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: foreground.withValues(alpha: .65),
                            width: 3,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            user?.initials ?? '?',
                            style: TextStyle(
                              color: context.colors.onGold,
                              fontSize: 25,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.fullName ?? 'Scholar',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: foreground,
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user?.email ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: foreground,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: isAdmin
                      ? [
                          _heroChip('Administrator account', foreground),
                        ]
                      : [
                          if (user?.studentNumber?.isNotEmpty == true)
                            _heroChip('ID: ${user!.studentNumber}', foreground),
                          _heroChip('Scholar account', foreground),
                        ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _circle(Color color, double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );

  Widget _heroChip(String label, Color foreground) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 250),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: foreground.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _iconTile(IconData icon, Color tint, Color foreground) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: foreground, size: 23),
    );
  }

  Widget _securityCard({
    required AppState state,
    required bool isAdmin,
  }) {
    final enabled = state.fingerprintRegistered;
    final biometricLabel =
        enabled ? 'Device biometrics enabled' : 'Enable device biometrics';
    final biometricSubtitle = enabled
        ? isAdmin
            ? 'Used to confirm disbursing and cancelling payouts'
            : 'Used to confirm allowance payouts'
        : 'Required before you can receive an allowance';

    return AppCard(
      radius: 22,
      shadow: true,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          InkWell(
            onTap: () => _openScreen(const FingerprintScreen()),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                children: [
                  _iconTile(
                    AppIcons.fingerprint,
                    enabled
                        ? context.colors.successBg
                        : context.colors.warningBg,
                    enabled
                        ? context.colors.successText
                        : context.colors.warningText,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          biometricLabel,
                          style: TextStyle(
                            color: context.colors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          biometricSubtitle,
                          style: TextStyle(
                            color: context.colors.textBody,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (enabled)
                    StatusChip(
                      'Active',
                      color: context.colors.successText,
                      bg: context.colors.successBg,
                    )
                  else
                    SizedBox(
                      width: 74,
                      child: PrimaryButton(
                        label: 'Set up',
                        onPressed: () => _openScreen(const FingerprintScreen()),
                        minHeight: 40,
                        borderRadius: 14,
                      ),
                    ),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: context.colors.borderSoft),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                _iconTile(
                  AppIcons.lock,
                  context.colors.brandTint,
                  context.colors.brand,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Biometric login',
                        style: TextStyle(
                          color: context.colors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Sign in with your fingerprint',
                        style: TextStyle(
                          color: context.colors.textBody,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: state.biometricEnabled,
                  onChanged: (enabled) async {
                    if (enabled) {
                      final ok = await _enableBiometricLogin();
                      if (!ok && mounted) setState(() {});
                    } else {
                      await state.disableBiometric();
                      if (!mounted) return;
                      showMsg(context, 'Biometric login turned off.');
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _preferencesCard(AppState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appearanceLabel = isDark ? 'Dark mode' : 'Light mode';

    return AppCard(
      radius: 22,
      shadow: true,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                _iconTile(
                  isDark ? AppIcons.moon : AppIcons.sun,
                  context.colors.brandTint,
                  context.colors.brand,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Appearance',
                        style: TextStyle(
                          color: context.colors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        appearanceLabel,
                        style: TextStyle(
                          color: context.colors.textBody,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                _themeSegment(state, isDark),
              ],
            ),
          ),
          Divider(height: 1, color: context.colors.borderSoft),
          InkWell(
            onTap: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove(_kRememberEmail);
              if (mounted) showMsg(context, 'Saved email cleared.');
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                children: [
                  _iconTile(
                    AppIcons.mail,
                    context.colors.brandTint,
                    context.colors.brand,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Forget saved email',
                          style: TextStyle(
                            color: context.colors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Clears the email prefilled on the login screen',
                          style: TextStyle(
                            color: context.colors.textBody,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    AppIcons.chevronRight,
                    color: context.colors.textBody,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _themeSegment(AppState state, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.colors.borderSoft,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _themeButton(
            icon: AppIcons.sun,
            selected: !isDark,
            tooltip: 'Light mode',
            onTap: () => state.setThemeMode(ThemeMode.light),
          ),
          _themeButton(
            icon: AppIcons.moon,
            selected: isDark,
            tooltip: 'Dark mode',
            onTap: () => state.setThemeMode(ThemeMode.dark),
          ),
        ],
      ),
    );
  }

  Widget _themeButton({
    required IconData icon,
    required bool selected,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: selected ? context.colors.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              icon,
              size: 20,
              color: selected ? context.colors.brand : context.colors.textBody,
            ),
          ),
        ),
      ),
    );
  }

  Widget _navigation(bool isAdmin) {
    final items = isAdmin
        ? const [
            HomeNavigationItem(
              label: 'Home',
              icon: AppIcons.homeOutline,
              activeIcon: AppIcons.home,
            ),
            HomeNavigationItem(label: 'Payouts', icon: AppIcons.payouts),
            HomeNavigationItem(label: 'Scholars', icon: AppIcons.users),
            HomeNavigationItem(label: 'Profile', icon: AppIcons.user),
          ]
        : const [
            HomeNavigationItem(
              label: 'Home',
              icon: AppIcons.homeOutline,
              activeIcon: AppIcons.home,
            ),
            HomeNavigationItem(label: 'Transactions', icon: AppIcons.chart),
            HomeNavigationItem(label: 'My Payouts', icon: AppIcons.payouts),
            HomeNavigationItem(label: 'Profile', icon: AppIcons.user),
          ];

    return ScholarBottomNavigation(
      currentIndex: 3,
      height: 76,
      selectedIconPill: true,
      scaleHeightForText: true,
      items: items,
      onTap: (index) => _navigate(index, isAdmin),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final user = state.user;
    final isAdmin = user?.role == UserRole.admin;
    final verificationStatus =
        user?.verificationStatus ?? VerificationStatus.pending;
    final isVerifiedScholar = verificationStatus == VerificationStatus.approved;
    final roleLabel = isAdmin
        ? 'Administrator'
        : isVerifiedScholar
            ? 'Verified scholar'
            : verificationStatus.label;
    final roleColor = isAdmin
        ? context.colors.brand
        : _verificationColor(context, verificationStatus);
    final roleBackground = isAdmin
        ? context.colors.brandTint
        : _verificationBackground(context, verificationStatus);

    return Scaffold(
      backgroundColor: context.colors.background,
      body: Column(
        children: [
          Expanded(
            child: SafeArea(
              bottom: false,
              child: ScrollConfiguration(
                behavior: const _ProfileScrollBehavior(),
                child: ListView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Profile',
                            style: TextStyle(
                              color: context.colors.textPrimary,
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Flexible(
                          child: _rolePill(
                            label: roleLabel,
                            color: roleColor,
                            background: roleBackground,
                            icon: isAdmin
                                ? AppIcons.shieldCheck
                                : isVerifiedScholar
                                    ? AppIcons.check
                                    : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _profileHero(user: user, isAdmin: isAdmin),
                    const SizedBox(height: 24),
                    const SectionLabel('SECURITY'),
                    const SizedBox(height: 10),
                    _securityCard(state: state, isAdmin: isAdmin),
                    const SizedBox(height: 24),
                    const SectionLabel('PREFERENCES'),
                    const SizedBox(height: 10),
                    _preferencesCard(state),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 56,
                      child: OutlinedButton.icon(
                        onPressed: () => confirmLogout(context),
                        icon: Icon(AppIcons.logout,
                            color: context.colors.dangerText),
                        label: Text(
                          'Sign out',
                          style: TextStyle(
                            color: context.colors.dangerText,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: context.colors.danger),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Scholar Wallet v2.0.0',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: context.colors.textBody,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _navigation(isAdmin),
    );
  }
}

class _ProfileScrollBehavior extends MaterialScrollBehavior {
  const _ProfileScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) =>
      child;
}
