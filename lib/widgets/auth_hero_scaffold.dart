import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'app_icons.dart';
import 'widgets.dart';

class AuthHeroScaffold extends StatelessWidget {
  final Widget leading;
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? footer;
  final VoidCallback? onBack;

  const AuthHeroScaffold({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.child,
    this.footer,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topInset = MediaQuery.paddingOf(context).top;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final heroHeight = 290.0 + topInset + (textScale - 1).clamp(0.0, 1.3) * 480;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: colors.authHeroStart,
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
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.only(
              bottom: MediaQuery.paddingOf(context).bottom + 24,
            ),
            child: ContentWidth(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: SizedBox(
                      height: heroHeight,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(40),
                        ),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                colors.authHeroStart,
                                colors.authHeroEnd,
                              ],
                            ),
                          ),
                          child: Stack(
                            children: [
                              Positioned(
                                top: -64,
                                right: -72,
                                child: _circle(
                                  200,
                                  colors.onHeader.withValues(alpha: .14),
                                ),
                              ),
                              Positioned(
                                bottom: -82,
                                left: -82,
                                child: _circle(
                                  180,
                                  colors.onHeader.withValues(alpha: .14),
                                ),
                              ),
                              Positioned(
                                top: topInset + 24,
                                left: 20,
                                child: Material(
                                  color: colors.onHeader.withValues(alpha: .2),
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    onTap: onBack ??
                                        () => Navigator.maybePop(context),
                                    customBorder: const CircleBorder(),
                                    child: SizedBox(
                                      width: 42,
                                      height: 42,
                                      child: Icon(
                                        AppIcons.back,
                                        color: colors.onHeader,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned.fill(
                                child: Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    24,
                                    topInset + 40,
                                    24,
                                    16,
                                  ),
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        leading,
                                        const SizedBox(height: 16),
                                        Text(
                                          title,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: colors.onHeader,
                                            fontSize: 28,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 300,
                                          ),
                                          child: Text(
                                            subtitle,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: colors.onHeader
                                                  .withValues(alpha: .9),
                                              fontSize: 15,
                                              height: 1.4,
                                            ),
                                          ),
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
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(height: heroHeight - 28),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: AppCard(
                          padding: const EdgeInsets.all(24),
                          radius: 32,
                          shadow: true,
                          borderColor:
                              isDark ? colors.border : colors.borderSoft,
                          child: child,
                        ),
                      ),
                      if (footer != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 28, 20, 4),
                          child: footer!,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _circle(double diameter, Color color) => Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      );
}
