import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import 'app_icons.dart';

class AnimatedLogo extends StatelessWidget {
  final double size;

  const AnimatedLogo({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final image = Semantics(
      image: true,
      label: 'Scholar Wallet logo',
      child: Image.asset(
        'assets/images/logo.png',
        width: size,
        height: size * .62,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Container(
          width: 74,
          height: 74,
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue,
            borderRadius: BorderRadius.circular(18),
          ),
          alignment: Alignment.center,
          child: Icon(
            AppIcons.school,
            color: context.colors.onHeader,
            size: 38,
          ),
        ),
      ),
    );

    final animatedImage = reduceMotion
        ? image
        : Animate(
            delay: const Duration(milliseconds: 700),
            onPlay: (controller) => controller.repeat(reverse: true),
            effects: const [
              MoveEffect(
                begin: Offset(0, -2),
                end: Offset(0, 2),
                duration: Duration(milliseconds: 1500),
                curve: Curves.easeInOut,
              ),
            ],
            child: Animate(
              onPlay: (controller) => controller.repeat(),
              effects: [
                ShimmerEffect(
                  delay: const Duration(seconds: 3),
                  duration: const Duration(milliseconds: 800),
                  color: context.colors.surface.withValues(alpha: .3),
                ),
              ],
              child: image
                  .animate()
                  .fadeIn(
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOut,
                  )
                  .scale(
                    begin: const Offset(.85, .85),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOut,
                  ),
            ),
          );

    const title = Column(
      children: [
        Text(
          'Scholar',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: AppTheme.primaryBlue,
          ),
        ),
        Text(
          'Wallet',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: AppTheme.accentGold,
          ),
        ),
      ],
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (reduceMotion) image else animatedImage,
        const SizedBox(height: 18),
        if (reduceMotion)
          title
        else
          title
              .animate()
              .fadeIn(
                delay: const Duration(milliseconds: 950),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOut,
              )
              .slideY(
                begin: .12,
                end: 0,
                delay: const Duration(milliseconds: 950),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOut,
              ),
      ],
    );
  }
}
