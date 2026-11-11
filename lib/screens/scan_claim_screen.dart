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
import 'fingerprint_screen.dart';
import 'payout_confirmation_screen.dart';
import 'payout_received_screen.dart';

/// Scholar: scan the QR code the ADMIN issued for this payout.
///
/// Flow: camera detects QR -> look up the claim -> confirm with fingerprint ->
/// server-side single-use redemption -> balance credited.
class ScanClaimScreen extends StatefulWidget {
  const ScanClaimScreen({super.key});

  @override
  State<ScanClaimScreen> createState() => _ScanClaimScreenState();
}

class _ScanClaimScreenState extends State<ScanClaimScreen>
    with SingleTickerProviderStateMixin {
  late final MobileScannerController _controller;
  late final AnimationController _scanLine;
  bool _handling = false;
  bool _cameraError = false;
  bool _cameraReady = false;
  bool _reduceMotion = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      formats: const [BarcodeFormat.qrCode],
    )..addListener(_onControllerChanged);
    _scanLine = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion || _handling) {
      _scanLine.stop();
    } else if (!_scanLine.isAnimating) {
      _scanLine.repeat(reverse: true);
    }
  }

  void _onControllerChanged() {
    if (!mounted) return;
    final scannerState = _controller.value;
    final cameraError = _cameraError || scannerState.error != null;
    final cameraReady = scannerState.isInitialized;
    if (cameraError != _cameraError || cameraReady != _cameraReady) {
      setState(() {
        _cameraError = cameraError;
        _cameraReady = cameraReady;
      });
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _scanLine.dispose();
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
    _scanLine.stop();
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
      final receivedAmount = await state.wallet
          .claimAllowance(token: token, scholarId: state.user!.id);
      // Receipt already succeeded: a refresh failure must not imply it failed.
      try {
        await state.refreshBalance();
      } catch (_) {
        // Receipt already succeeded; show the receipt screen even if refresh fails.
      }
      if (!mounted) return;
      leaving = true;
      await Navigator.pushReplacement<bool, bool>(
        context,
        MaterialPageRoute<bool>(
          builder: (_) => PayoutReceivedScreen(
            claim: preview,
            receivedAmount: receivedAmount,
          ),
        ),
        result: true,
      );
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
        if (!_reduceMotion) _scanLine.repeat(reverse: true);
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
    final code = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AppBottomSheet(
        title: 'Enter payout code',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(
              controller: controller,
              hintText: 'Paste the code printed under the QR',
              keyboardType: TextInputType.text,
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Continue',
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              minHeight: 56,
              borderRadius: 18,
            ),
          ],
        ),
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

  Future<void> _toggleTorch() async {
    try {
      await _controller.toggleTorch();
    } catch (_) {
      if (mounted) {
        showMsg(context, 'Could not change the camera light.', error: true);
      }
    }
  }

  Future<void> _openBiometricSetup() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FingerprintScreen()),
    );
  }

  Widget _statusPill(BuildContext context) {
    final label = _cameraError
        ? 'Camera unavailable'
        : _cameraReady
            ? 'Camera ready'
            : 'Starting camera';
    final color = _cameraError
        ? context.colors.danger
        : _cameraReady
            ? context.colors.success
            : context.colors.accentGold;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: context.colors.onHeader.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: context.colors.onHeader.withValues(alpha: .08),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 9),
          Text(
            label,
            style: TextStyle(
              color: context.colors.onHeader,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _scanFrame(BuildContext context, double frameSize) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: SizedBox.square(
        dimension: frameSize,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (!_cameraError)
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
              )
            else
              ColoredBox(
                color: context.colors.onHeader.withValues(alpha: .08),
              ),
            ColoredBox(
              color: context.colors.scanGradientStart.withValues(alpha: .28),
            ),
            if (!_cameraReady || _cameraError)
              Center(
                child: Icon(
                  _cameraError ? AppIcons.cameraOff : AppIcons.qrCode,
                  size: 88,
                  color: context.colors.onHeader.withValues(alpha: .38),
                ),
              ),
            if (!_reduceMotion)
              AnimatedBuilder(
                animation: _scanLine,
                builder: (context, child) => Positioned(
                  top: 20 + (frameSize - 40) * _scanLine.value,
                  left: 22,
                  right: 22,
                  child: child!,
                ),
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    color: context.colors.accentGold,
                    boxShadow: [
                      BoxShadow(
                        color: context.colors.accentGold.withValues(alpha: .8),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              )
            else
              Positioned(
                top: frameSize / 2,
                left: 22,
                right: 22,
                child: Container(
                  height: 2,
                  color: context.colors.accentGold.withValues(alpha: .8),
                ),
              ),
            IgnorePointer(
              child: CustomPaint(
                painter: _ScanFramePainter(color: context.colors.accentGold),
              ),
            ),
            if (_handling)
              ColoredBox(
                color: context.colors.scanGradientStart.withValues(alpha: .58),
                child: Center(
                  child: CircularProgressIndicator(
                    color: context.colors.accentGold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final screenSize = MediaQuery.sizeOf(context);
    final frameSize = (screenSize.width - 40).clamp(0.0, 260.0).toDouble();
    final buttonHeight = (MediaQuery.textScalerOf(context).scale(14) + 32)
        .clamp(56.0, 96.0)
        .toDouble();
    final torchAvailable =
        _cameraReady && _controller.value.torchState != TorchState.unavailable;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: context.colors.scanGradientStart,
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                context.colors.scanGradientStart,
                context.colors.heroGradientEnd,
              ],
            ),
          ),
          child: SafeArea(
            child: ContentWidth(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final contentWidth = constraints.maxWidth;
                  final frame = frameSize > contentWidth - 40
                      ? (contentWidth - 40).clamp(0.0, 260.0).toDouble()
                      : frameSize;
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: SizedBox(
                          height: 54,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Text(
                                'Scan QR',
                                style: TextStyle(
                                  color: context.colors.onHeader,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: _RoundScanBarButton(
                                  tooltip: 'Back',
                                  icon: AppIcons.back,
                                  onPressed: () => Navigator.maybePop(context),
                                ),
                              ),
                              if (torchAvailable)
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: _RoundScanBarButton(
                                    tooltip: _controller.value.torchState ==
                                            TorchState.on
                                        ? 'Turn flashlight off'
                                        : 'Turn flashlight on',
                                    icon: _controller.value.torchState ==
                                            TorchState.on
                                        ? AppIcons.flashlight
                                        : AppIcons.flashlightOff,
                                    onPressed: _toggleTorch,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                          child: Column(
                            children: [
                              Text(
                                'Scan your payout QR',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: context.colors.onHeader,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Hold your phone over the QR code your admin generated for you.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: context.colors.onHeader
                                      .withValues(alpha: .78),
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Center(child: _scanFrame(context, frame)),
                              const SizedBox(height: 18),
                              _statusPill(context),
                              if (_cameraError) ...[
                                const SizedBox(height: 14),
                                InfoBanner(
                                  icon: AppIcons.cameraOff,
                                  message:
                                      'Camera is not available on this device. Enter your payout code or choose a QR image below.',
                                  backgroundColor: context.colors.dangerBg,
                                  iconColor: context.colors.dangerText,
                                  textColor: context.colors.dangerText,
                                  maxLines: 4,
                                ),
                              ],
                              if (_message != null) ...[
                                const SizedBox(height: 12),
                                InfoBanner(
                                  icon: AppIcons.error,
                                  message: _message!,
                                  backgroundColor: context.colors.dangerBg,
                                  iconColor: context.colors.dangerText,
                                  textColor: context.colors.dangerText,
                                  maxLines: 4,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: constraints.maxHeight * .42,
                        ),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                          child: AppCard(
                            radius: 26,
                            shadow: true,
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Tooltip(
                                  message: state.fingerprintRegistered
                                      ? 'Device biometrics settings'
                                      : 'Set up device biometrics',
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(14),
                                    onTap: _openBiometricSetup,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 2,
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 52,
                                            height: 52,
                                            decoration: BoxDecoration(
                                              color: context.colors.goldTint,
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            alignment: Alignment.center,
                                            child: Icon(
                                              AppIcons.fingerprint,
                                              color: context.colors.warningText,
                                              size: 26,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Device biometrics confirm the payout',
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: context
                                                        .colors.textPrimary,
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                                const SizedBox(height: 3),
                                                Text(
                                                  "You'll be asked right after scanning",
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color:
                                                        context.colors.textBody,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: SecondaryButton(
                                        label: 'From gallery',
                                        icon: AppIcons.image,
                                        onPressed:
                                            _handling ? null : _pickFromGallery,
                                        minHeight: buttonHeight,
                                        borderRadius: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: PrimaryButton(
                                        label: 'Enter code',
                                        icon: AppIcons.keyboard,
                                        onPressed:
                                            _handling ? null : _manualEntry,
                                        minHeight: buttonHeight,
                                        borderRadius: 18,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundScanBarButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  const _RoundScanBarButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: context.colors.onHeader.withValues(alpha: .14),
        shape: const CircleBorder(),
        child: IconButton(
          onPressed: onPressed,
          constraints: const BoxConstraints.tightFor(width: 42, height: 42),
          padding: EdgeInsets.zero,
          color: context.colors.onHeader,
          icon: Icon(icon, size: 21),
        ),
      ),
    );
  }
}

class _ScanFramePainter extends CustomPainter {
  final Color color;

  const _ScanFramePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const arm = 28.0;
    const radius = 18.0;
    const inset = 2.0;
    final width = size.width - inset * 2;
    final height = size.height - inset * 2;
    final paint = Paint()
      ..color = color
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
  bool shouldRepaint(covariant _ScanFramePainter oldDelegate) =>
      oldDelegate.color != color;
}
