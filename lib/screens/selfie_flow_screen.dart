import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../widgets/app_icons.dart';
import '../widgets/widgets.dart';
import '../services/selfie_service.dart';

String selfieFriendlyErrorMessage(Object error) {
  if (error is PlatformException) {
    final code = error.code.toLowerCase();
    if (code.contains('camera') &&
        (code.contains('denied') || code.contains('permission'))) {
      return 'Camera permission is needed to take your selfie. You can allow it in Settings.';
    }
  }

  final details = error.toString().toUpperCase();
  if (details.contains('SELFIE_ALREADY_SUBMITTED')) {
    return 'Your selfie was already submitted.';
  }
  if (details.contains('SCHOLAR_NOT_ELIGIBLE')) {
    return "This account can't submit a selfie right now.";
  }
  if (details.contains('BAD_PATH') || details.contains('FILE_MISSING')) {
    return "The upload didn't finish. Please try again.";
  }
  if (details.contains('SELFIE_REQUIRED')) {
    return 'A selfie is required before approval.';
  }
  if (details.contains('NO_SELFIE_YET')) {
    return 'This scholar has not submitted a selfie yet.';
  }
  return 'Something went wrong. Please try again.';
}

class SelfieIntroScreen extends StatefulWidget {
  final Future<void> Function() onSubmitted;

  const SelfieIntroScreen({super.key, required this.onSubmitted});

  @override
  State<SelfieIntroScreen> createState() => _SelfieIntroScreenState();
}

class _SelfieIntroScreenState extends State<SelfieIntroScreen> {
  final _service = SelfieService();
  bool _openingCamera = false;

  Future<void> _takeSelfie() async {
    setState(() => _openingCamera = true);
    try {
      final photo = await _service.pick();
      if (!mounted || photo == null) return;
      final submitted = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => SelfieReviewScreen(photo: File(photo.path)),
        ),
      );
      if (submitted != true || !mounted) return;
      try {
        await widget.onSubmitted();
      } catch (_) {
        if (mounted) {
          showMsg(context, 'Something went wrong. Please try again.',
              error: true);
        }
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        showMsg(context, selfieFriendlyErrorMessage(error), error: true);
      }
    } finally {
      if (mounted) setState(() => _openingCamera = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: _SelfieWizardAppBar(onBack: () => Navigator.pop(context)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            const _SelfieProgress(),
            const SizedBox(height: 28),
            Text(
              'Take a selfie',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 30,
                fontWeight: FontWeight.w800,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'One selfie helps the administrator confirm that you are the student who registered.',
              style: TextStyle(
                color: colors.textBody,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            const _SelfieGuideCard(),
            const SizedBox(height: 12),
            const Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SelfieTip(
                  label: 'Good lighting',
                  icon: AppIcons.sun,
                  iconColor: Color(0xFFF0A020),
                ),
                _SelfieTip(
                  label: 'No mask or sunglasses',
                  icon: AppIcons.cancel,
                  iconColor: Color(0xFF1E5AA8),
                ),
                _SelfieTip(
                  label: 'Face the camera',
                  icon: AppIcons.userCheck,
                  iconColor: Color(0xFF1FB886),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AppCard(
              radius: 18,
              padding: const EdgeInsets.all(16),
              backgroundColor: colors.brandTint,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(AppIcons.shieldCheck, color: colors.brand, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Used to verify your registration and shown as your profile picture. Only you and an administrator can see it.',
                      style: TextStyle(
                        color: colors.brandTintText,
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Take selfie',
              icon: Icons.camera_alt_outlined,
              minHeight: 56,
              borderRadius: 18,
              shadow: true,
              loading: _openingCamera,
              onPressed: _openingCamera ? null : _takeSelfie,
            ),
            const SizedBox(height: 12),
            Text(
              'You can submit your selfie once. An administrator can ask for a new one if needed.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textBody,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SelfieReviewScreen extends StatefulWidget {
  final File photo;

  const SelfieReviewScreen({super.key, required this.photo});

  @override
  State<SelfieReviewScreen> createState() => _SelfieReviewScreenState();
}

class _SelfieReviewScreenState extends State<SelfieReviewScreen> {
  final _service = SelfieService();
  late File _photo = widget.photo;
  bool _submitting = false;
  bool _retaking = false;

  Future<void> _retake() async {
    setState(() => _retaking = true);
    try {
      final photo = await _service.pick();
      if (mounted && photo != null) {
        setState(() => _photo = File(photo.path));
      }
    } catch (error) {
      if (mounted) {
        showMsg(context, selfieFriendlyErrorMessage(error), error: true);
      }
    } finally {
      if (mounted) setState(() => _retaking = false);
    }
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await _service.upload(_photo);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        showMsg(context, selfieFriendlyErrorMessage(error), error: true);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: _SelfieWizardAppBar(onBack: () => Navigator.pop(context)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            const _SelfieProgress(),
            const SizedBox(height: 28),
            Text(
              'Review your selfie',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 30,
                fontWeight: FontWeight.w800,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check that your face is clear and fully visible.',
              style: TextStyle(
                color: colors.textBody,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            AppCard(
              radius: 24,
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: SizedBox(
                      width: double.infinity,
                      height: 280,
                      child: Image.file(
                        _photo,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => ColoredBox(
                          color: colors.brandTint,
                          child: Icon(
                            AppIcons.user,
                            color: colors.brand.withValues(alpha: .48),
                            size: 72,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Preview of your selfie',
                    style: TextStyle(
                      color: colors.textBody,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              radius: 20,
              padding: const EdgeInsets.all(14),
              backgroundColor: colors.warningBg,
              borderColor: colors.warningBorder,
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colors.avatarTint,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      AppIcons.warning,
                      color: colors.warningText,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Used to verify your registration and shown as your profile picture. Only you and an administrator can see it. You can submit your selfie once. If it is not clear, retake it now.',
                      style: TextStyle(
                        color: colors.goldTintText,
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Submit selfie',
              icon: AppIcons.check,
              minHeight: 56,
              borderRadius: 18,
              shadow: true,
              loading: _submitting,
              onPressed: _submitting || _retaking ? null : _submit,
            ),
            const SizedBox(height: 10),
            SecondaryButton(
              label: 'Retake',
              icon: Icons.camera_alt_outlined,
              foregroundColor: colors.brand,
              iconColor: colors.brand,
              minHeight: 52,
              borderRadius: 18,
              loading: _retaking,
              onPressed: _submitting || _retaking ? null : _retake,
            ),
          ],
        ),
      ),
    );
  }
}

class SelfiePlaceholder extends StatelessWidget {
  const SelfiePlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: colors.brandTint,
        border: Border.all(color: colors.brand.withValues(alpha: .4), width: 2),
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: Icon(
        AppIcons.user,
        color: colors.brand.withValues(alpha: .5),
        size: 38,
      ),
    );
  }
}

class SelfieFullScreenViewer extends StatelessWidget {
  final String signedUrl;

  const SelfieFullScreenViewer({super.key, required this.signedUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          tooltip: 'Close',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(AppIcons.close),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: .8,
          maxScale: 4,
          child: Image.network(
            signedUrl,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Text(
              'Could not load this selfie.',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelfieWizardAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final VoidCallback onBack;

  const _SelfieWizardAppBar({required this.onBack});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppBar(
      backgroundColor: colors.background,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      leadingWidth: 70,
      leading: Padding(
        padding: const EdgeInsets.only(left: 20),
        child: IconButton(
          onPressed: onBack,
          tooltip: 'Back',
          style: IconButton.styleFrom(
            fixedSize: const Size.square(44),
            padding: EdgeInsets.zero,
            backgroundColor: colors.surface,
            side: BorderSide(color: colors.borderSoft),
            shape: const CircleBorder(),
          ),
          icon: Icon(AppIcons.back, color: colors.brand),
        ),
      ),
      title: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: 'Scholar ',
              style: TextStyle(
                color: colors.brand,
                fontWeight: FontWeight.w800,
              ),
            ),
            TextSpan(
              text: 'Wallet',
              style: TextStyle(
                color: colors.accentGold,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        style: const TextStyle(fontSize: 18),
      ),
      actions: const [SizedBox(width: 70)],
    );
  }
}

class _SelfieProgress extends StatelessWidget {
  const _SelfieProgress();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Step 3 of 3',
                style: TextStyle(
                  color: colors.textLabel,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              'Verify it’s you',
              style: TextStyle(
                color: colors.brand,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(
            3,
            (index) => Expanded(
              child: Container(
                height: 6,
                margin: EdgeInsets.only(right: index == 2 ? 0 : 6),
                decoration: BoxDecoration(
                  color: colors.brand,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SelfieGuideCard extends StatelessWidget {
  const _SelfieGuideCard();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppCard(
      radius: 24,
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1.28,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: ColoredBox(
                color: colors.brandTint,
                child: LayoutBuilder(
                  builder: (context, constraints) => Stack(
                    fit: StackFit.expand,
                    children: [
                      Positioned(
                        top: constraints.maxHeight * .27,
                        left: (constraints.maxWidth - 80) / 2,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: const BoxDecoration(
                            color: Color(0xFF9BB5D3),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: -24,
                        left: (constraints.maxWidth - 170) / 2,
                        child: Container(
                          width: 170,
                          height: constraints.maxHeight * .62,
                          decoration: const BoxDecoration(
                            color: Color(0xFF9BB5D3),
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(100),
                            ),
                          ),
                        ),
                      ),
                      CustomPaint(painter: _OvalGuidePainter(colors.brand)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Center your face inside the oval',
            style: TextStyle(
              color: colors.textBody,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _OvalGuidePainter extends CustomPainter {
  final Color color;

  const _OvalGuidePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final center = Offset(size.width / 2, size.height / 2);
    final radiusX = size.width * .27;
    final radiusY = size.height * .43;
    const segmentCount = 44;
    for (var index = 0; index < segmentCount; index += 2) {
      final start = index * 2 * 3.141592653589793 / segmentCount;
      final end = (index + 1) * 2 * 3.141592653589793 / segmentCount;
      canvas.drawArc(
        Rect.fromCenter(
          center: center,
          width: radiusX * 2,
          height: radiusY * 2,
        ),
        start,
        end - start,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _OvalGuidePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _SelfieTip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color iconColor;

  const _SelfieTip({
    required this.label,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.borderSoft),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: iconColor),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.textLabel,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
