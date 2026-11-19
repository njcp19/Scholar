import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'app_icons.dart';
import 'widgets.dart';

class PasswordResetScaffold extends StatelessWidget {
  final Widget icon;
  final String title;
  final String subtitle;
  final Widget? heroDetail;
  final Widget child;
  final Widget? footer;
  final VoidCallback? onBack;
  final bool goldHero;

  const PasswordResetScaffold({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
    this.heroDetail,
    this.footer,
    this.onBack,
    this.goldHero = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = goldHero ? colors.onGold : colors.onHeader;
    final gradient = goldHero
        ? [colors.balanceHeroStart, colors.balanceHeroEnd]
        : [colors.authHeroStart, colors.authHeroEnd];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: colors.background,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: colors.background,
        systemNavigationBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: colors.canvas,
        body: SafeArea(
          child: Column(
            children: [
              _header(context),
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
                  child: ContentWidth(
                    maxWidth: 560,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: gradient,
                              ),
                            ),
                            child: Stack(
                              clipBehavior: Clip.hardEdge,
                              children: [
                                Positioned(
                                  top: -72,
                                  right: -72,
                                  child: _circle(
                                    190,
                                    colors.onHeader.withValues(alpha: .16),
                                  ),
                                ),
                                Positioned(
                                  bottom: -110,
                                  left: -110,
                                  child: _circle(
                                    220,
                                    colors.onHeader.withValues(alpha: .10),
                                  ),
                                ),
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(22, 30, 22, 26),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        icon,
                                        const SizedBox(height: 20),
                                        SizedBox(
                                          width: double.infinity,
                                          child: Text(
                                            title,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: foreground,
                                              fontSize: 26,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: -.5,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(
                                              maxWidth: 280),
                                          child: SizedBox(
                                            width: double.infinity,
                                            child: Text(
                                              subtitle,
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: foreground,
                                                fontSize: 14,
                                                height: 1.5,
                                              ),
                                            ),
                                          ),
                                        ),
                                        if (heroDetail != null) ...[
                                          const SizedBox(height: 14),
                                          SizedBox(
                                            width: double.infinity,
                                            child: Center(child: heroDetail!),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        child,
                        if (footer != null) ...[
                          const SizedBox(height: 16),
                          footer!,
                        ],
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

  Widget _header(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(26, 16, 16, 8),
          child: Row(
            children: [
              Material(
                color: colors.surface,
                shape: CircleBorder(
                  side: BorderSide(color: colors.borderSoft),
                ),
                child: IconButton(
                  onPressed: onBack ?? () => Navigator.maybePop(context),
                  tooltip: 'Back to login',
                  constraints:
                      const BoxConstraints.tightFor(width: 44, height: 44),
                  padding: EdgeInsets.zero,
                  icon: Icon(AppIcons.back, color: colors.brand),
                ),
              ),
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'Scholar ',
                            style: TextStyle(
                              color: colors.brand,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          TextSpan(
                            text: 'Wallet',
                            style: TextStyle(
                              color: colors.accentGold,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 44),
            ],
          ),
        ),
      ),
    );
  }

  Widget _circle(double diameter, Color color) => Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

class PasswordResetHeroIcon extends StatelessWidget {
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;

  const PasswordResetHeroIcon({
    super.key,
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.onHeader.withValues(alpha: .18),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: backgroundColor,
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: iconColor, size: 30),
      ),
    );
  }
}

class BackToLoginLink extends StatelessWidget {
  final VoidCallback onPressed;

  const BackToLoginLink({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      height: 48,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(AppIcons.back, color: colors.brand, size: 20),
        label: Text(
          'Back to login',
          style: TextStyle(
            color: colors.brand,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
