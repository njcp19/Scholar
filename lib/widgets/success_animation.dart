import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../theme/app_theme.dart';
import 'app_icons.dart';

class SuccessAnimation extends StatelessWidget {
  const SuccessAnimation({super.key});

  Widget _fallback(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: Center(
        child: Icon(
          AppIcons.checkCircle,
          size: 54,
          color: context.colors.brand,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return _fallback(context);

    return Lottie.asset(
      'assets/animations/success.json',
      width: 120,
      height: 120,
      fit: BoxFit.contain,
      repeat: false,
      errorBuilder: (context, error, stackTrace) => _fallback(context),
    );
  }
}
