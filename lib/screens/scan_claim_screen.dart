import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../services/qr_service.dart';
import '../services/wallet_service.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';
import '../widgets/app_icons.dart';
import '../widgets/success_animation.dart';
import 'fingerprint_screen.dart';
import 'payout_confirmation_screen.dart';

/// Scholar: scan the QR code the ADMIN issued for this payout.
///
/// Flow: camera detects QR -> look up the claim -> confirm with fingerprint ->
/// server-side single-use redemption -> balance credited.
class ScanClaimScreen extends StatefulWidget {
  const ScanClaimScreen({super.key});

  @override
  State<ScanClaimScreen> createState() => _ScanClaimScreenState();
}

class _ScanClaimScreenState extends State<ScanClaimScreen> {
  late final MobileScannerController _controller;
  bool _handling = false;
  bool _cameraError = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      formats: const [BarcodeFormat.qrCode],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling) return;
    final raw = capture.barcodes
        .map((b) => b.rawValue)
        .firstWhere((v) => v != null && v.isNotEmpty, orElse: () => null);
    if (raw == null) return;
    final payload = ClaimQrPayload.tryParse(raw);
    if (payload == null) {
      setState(() => _message =
          'Not a payout QR. Attendance/event QR codes cannot release allowance.');
      return;
    }
    await _handleToken(payload.token);
  }

  Future<void> _handleToken(String token) async {
    if (_handling) return;
    setState(() {
      _handling = true;
      _message = null;
    });
    var leaving = false;
    final state = context.read<AppState>();
    try {
      // Pause camera detections while another route, dialog or OS prompt is open.
      try {
        await _controller.stop();
      } catch (_) {}
      await state.refreshProfile();
      if (!mounted) return;
      if (state.user?.canReceiveAllowance != true) {
        throw WalletException(
            'Only active, admin-verified scholars can receive allowance.');
      }
      final preview = await state.wallet.previewClaim(token);
      if (!mounted) return;
      if (preview == null) {
        throw WalletException('This is not a valid payout QR.');
      }
      if (preview.scholarId != state.user!.id) {
        throw WalletException(
            'This payout QR does not belong to your account.');
      }
      if (!preview.isPending) {
        throw WalletException(preview.isReceived
            ? 'Already received — each payout QR can only be used once.'
            : 'This payout was cancelled by the administrator.');
      }
      // Amount is reviewed BEFORE either biometric setup or confirmation.
      final confirmed = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => PayoutConfirmationScreen(claim: preview),
          ));
      if (!mounted || confirmed != true) return;
      if (!state.fingerprintRegistered) {
        await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => const FingerprintScreen(required: true),
            ));
        if (!mounted || !state.fingerprintRegistered) return;
      }
      final verified = await state.verifyFingerprint(
          'Confirm allowance receipt: PHP ${fmtPhp(preview.amount)}');
      if (!mounted) return;
      if (!verified) {
        throw WalletException(
            'Biometrics not verified. Allowance receipt was not recorded.');
      }
      final amount = await state.wallet
          .claimAllowance(token: token, scholarId: state.user!.id);
      // Receipt already succeeded: a refresh failure must not imply it failed.
      var balanceUpdated = true;
      try {
        await state.refreshBalance();
      } catch (_) {
        balanceUpdated = false;
      }
      if (!mounted) return;
      await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
                icon: const SuccessAnimation(),
                title: const Text('Allowance received'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('PHP ${fmtPhp(amount)}',
                      style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.successGreen)),
                  const SizedBox(height: 6),
                  Text(balanceUpdated
                      ? 'New balance: PHP ${fmtPhp(state.balance)}'
                      : 'Receipt saved. Refresh your wallet to see the new balance.'),
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Done'))
                ],
              ));
      if (mounted) {
        leaving = true;
        Navigator.pop(context, true);
      }
    } on WalletException catch (e) {
      if (mounted) showMsg(context, e.message, error: true);
    } catch (_) {
      if (mounted) {
        showMsg(context,
            'Could not finish. Refresh My Payouts to check receipt status before trying again.',
            error: true);
      }
    } finally {
      if (mounted && !leaving) {
        setState(() => _handling = false);
        if (!_cameraError) {
          try {
            await _controller.start();
          } catch (_) {}
        }
      }
    }
  }

  /// Pick a saved/screenshotted Payout QR image from the gallery and read it.
  Future<void> _pickFromGallery() async {
    if (_handling) return;
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) return;
    try {
      final capture = await _controller.analyzeImage(picked.path);
      if (!mounted) return;
      if (capture == null || capture.barcodes.isEmpty) {
        setState(() => _message = 'No QR code found in that image.');
        return;
      }
      await _onDetect(capture);
    } catch (_) {
      if (mounted) {
        setState(
            () => _message = 'Could not read that image. Try another one.');
      }
    }
  }

  Future<void> _manualEntry() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter payout code'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
              hintText: 'Paste the code printed under the QR'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Continue')),
        ],
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    controller.dispose();
    if (!mounted || code == null || code.isEmpty) return;
    final parsed = ClaimQrPayload.tryParse(code);
    if (parsed == null) {
      showMsg(context,
          'Invalid payout code. Event or attendance QR codes are not supported here.',
          error: true);
      return;
    }
    await _handleToken(parsed.token);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final frameSize =
        (MediaQuery.sizeOf(context).width - 48).clamp(0.0, 260.0).toDouble();

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: Material(
            color: Colors.black.withValues(alpha: .35),
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: 'Back',
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.maybePop(context),
              icon: Icon(
                AppIcons.back,
                color: context.colors.onHeader,
              ),
            ),
          ),
        ),
        title: const Text(
          'Scan Allowance QR',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_cameraError)
            Center(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 88, 24, 190),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.colors.borderSoft),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        AppIcons.cameraOff,
                        color: context.colors.brand,
                        size: 24,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Camera is not available on this device.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.colors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Enter your payout code or choose a QR image below.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.colors.textBody,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else ...[
            MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
              errorBuilder: (context, error, child) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && !_cameraError) {
                    setState(() => _cameraError = true);
                  }
                });
                return const SizedBox.shrink();
              },
            ),
            const Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _ScanAreaOverlayPainter(),
                ),
              ),
            ),
            Center(
              child: IgnorePointer(
                child: CustomPaint(
                  size: Size.square(frameSize),
                  painter: const _ScanFramePainter(),
                ),
              ),
            ),
            if (_handling)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
          ],
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(
                  top: BorderSide(color: context.colors.borderSoft),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Point the camera at the admin's QR code",
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.colors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_message != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _message!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppTheme.warningAmber,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _ScanActionButton(
                              icon: AppIcons.keyboard,
                              label: 'Code',
                              onPressed: _manualEntry,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ScanActionButton(
                              icon: AppIcons.image,
                              label: 'Gallery',
                              onPressed: _pickFromGallery,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _FingerprintAction(
                              registered: state.fingerprintRegistered,
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const FingerprintScreen(),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _ScanActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: context.colors.background,
          foregroundColor: context.colors.textPrimary,
          side: BorderSide(color: context.colors.borderSoft),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: context.colors.brand),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FingerprintAction extends StatelessWidget {
  final bool registered;
  final VoidCallback onPressed;

  const _FingerprintAction({
    required this.registered,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        registered ? context.colors.textLabel : context.colors.textPrimary;
    return SizedBox(
      height: 52,
      child: Material(
        color:
            registered ? context.colors.successBg : context.colors.background,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  AppIcons.fingerprint,
                  size: 18,
                  color: registered
                      ? context.colors.textLabel
                      : context.colors.brand,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    registered ? 'Verified' : 'Register',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScanAreaOverlayPainter extends CustomPainter {
  const _ScanAreaOverlayPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final frameSize = (size.width - 48).clamp(0.0, 260.0);
    final frame = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: frameSize,
      height: frameSize,
    );
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(
        RRect.fromRectAndRadius(frame, const Radius.circular(18)),
      );
    canvas.drawPath(
      path,
      Paint()..color = Colors.black.withValues(alpha: .55),
    );
  }

  @override
  bool shouldRepaint(covariant _ScanAreaOverlayPainter oldDelegate) => false;
}

class _ScanFramePainter extends CustomPainter {
  const _ScanFramePainter();

  @override
  void paint(Canvas canvas, Size size) {
    const arm = 28.0;
    const radius = 18.0;
    const inset = 2.0;
    final width = size.width - inset * 2;
    final height = size.height - inset * 2;
    final paint = Paint()
      ..color = AppTheme.accentGold
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.save();
    canvas.translate(inset, inset);
    final segments = <Path>[
      Path()
        ..moveTo(0, arm)
        ..lineTo(0, radius)
        ..quadraticBezierTo(0, 0, radius, 0)
        ..lineTo(arm, 0),
      Path()
        ..moveTo(width - arm, 0)
        ..lineTo(width - radius, 0)
        ..quadraticBezierTo(width, 0, width, radius)
        ..lineTo(width, arm),
      Path()
        ..moveTo(0, height - arm)
        ..lineTo(0, height - radius)
        ..quadraticBezierTo(
          0,
          height,
          radius,
          height,
        )
        ..lineTo(arm, height),
      Path()
        ..moveTo(width - arm, height)
        ..lineTo(width - radius, height)
        ..quadraticBezierTo(
          width,
          height,
          width,
          height - radius,
        )
        ..lineTo(width, height - arm),
    ];
    for (final segment in segments) {
      canvas.drawPath(segment, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ScanFramePainter oldDelegate) => false;
}
