import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../theme/app_theme.dart';
import 'app_icons.dart';

class SuccessAnimation extends StatelessWidget {
  final double size;
  final IconData fallbackIcon;
  final Color? fallbackColor;

  const SuccessAnimation({
    super.key,
    this.size = 120,
    this.fallbackIcon = AppIcons.checkCircle,
    this.fallbackColor,
  });

  Widget _fallback(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Icon(
          fallbackIcon,
          size: size * .5,
          color: fallbackColor ?? context.colors.brand,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return _fallback(context);

    return Lottie.asset(
      'assets/animations/success.json',
      width: size,
      height: size,
      fit: BoxFit.contain,
      repeat: false,
      errorBuilder: (context, error, stackTrace) => _fallback(context),
    );
  }
}
