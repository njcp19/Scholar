import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../widgets/widgets.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icons.dart';

/// Fingerprint registration screen.
///
/// Registration is a REAL OS enrollment check: the app asks the device which
/// biometrics are enrolled, shows the OS prompt and only marks the scholar as
/// registered when the OS verifies the fingerprint. Until this is done the
/// payout QR cannot be redeemed.
class FingerprintScreen extends StatefulWidget {
  /// When true the screen is a hard gate: the scholar cannot receive an
  /// allowance without registering.
  final bool required;
  const FingerprintScreen({super.key, this.required = false});

  @override
  State<FingerprintScreen> createState() => _FingerprintScreenState();
}

class _FingerprintScreenState extends State<FingerprintScreen> {
  bool _busy = false;
  bool _supported = true;
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
      _available = enrolled.map((t) => _label(t.name)).toList();
    });
  }

  String _label(String raw) {
    if (raw.contains('finger')) return 'Fingerprint';
    if (raw.contains('face')) return 'Face';
    if (raw.contains('iris')) return 'Iris';
    return 'Device biometric';
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
      showMsg(context, error, error: true);
      _probe();
    }
  }

  Future<void> _remove() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove fingerprint?'),
        content: const Text(
            'You will have to register again before you can receive an '
            'allowance payout.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true) return;
    if (!mounted) return;
    await context.read<AppState>().removeFingerprint();
    if (mounted) showMsg(context, 'Fingerprint removed.');
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final registered = state.fingerprintRegistered;
    final enrolledAt = state.fingerprintEnrolledAt;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: Icon(
            AppIcons.back,
            color: context.colors.textPrimary,
          ),
        ),
        automaticallyImplyLeading: true,
        title: const Text('Device Biometrics'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 28),
            decoration: BoxDecoration(
              color: registered
                  ? context.colors.successBg
                  : context.colors.warningBg,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                Icon(
                  AppIcons.fingerprint,
                  size: 24,
                  color: registered
                      ? context.colors.textLabel
                      : context.colors.brand,
                ),
                const SizedBox(height: 10),
                Text(
                  registered ? 'Device biometrics enabled' : 'Not enabled yet',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: context.colors.textPrimary),
                ),
                if (registered && enrolledAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Registered on ${DateFormat('MMM d, y • h:mm a').format(enrolledAt.toLocal())}',
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textMuted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          const SectionLabel('HOW IT IS USED'),
          const SizedBox(height: 10),
          _bullet(
            context,
            '1. The admin releases your allowance and gives you a QR code.',
          ),
          _bullet(
            context,
            '2. You scan that QR code in the app.',
          ),
          _bullet(
            context,
            '3. Review the allowance amount, then use your device biometrics to confirm receipt.',
          ),
          _bullet(
            context,
            'The app uses biometrics already enrolled in phone settings. It does not capture or store fingerprints. Anyone with an enrolled biometric on this device may pass the device prompt.',
          ),
          const SizedBox(height: 18),
          if (!_supported)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.colors.dangerBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'This device reports no biometric hardware. Add a fingerprint '
                'in Android Settings > Security > Fingerprint first.',
                style: TextStyle(fontSize: 12, color: AppTheme.dangerRed),
              ),
            )
          else if (_available.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.colors.warningBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'No fingerprint is enrolled in this phone yet. Add one in '
                'Android Settings > Security > Fingerprint, then come back.',
                style: TextStyle(fontSize: 12, color: AppTheme.warningAmber),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.colors.successBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Available on this device: ${_available.join(', ')}',
                style:
                    const TextStyle(fontSize: 12, color: AppTheme.successGreen),
              ),
            ),
          const SizedBox(height: 22),
          if (!registered)
            ElevatedButton.icon(
              onPressed: _busy ? null : _register,
              icon: _busy
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Icon(
                      AppIcons.fingerprint,
                      color: context.colors.onHeader,
                      size: 20,
                    ),
              label: const Text('Register Fingerprint'),
            )
          else
            OutlinedButton.icon(
              onPressed: _busy ? null : _register,
              icon: Icon(
                AppIcons.refresh,
                color: context.colors.brand,
              ),
              label: const Text('Register Again'),
            ),
          if (registered) ...[
            const SizedBox(height: 10),
            TextButton(
              onPressed: _remove,
              style: TextButton.styleFrom(foregroundColor: AppTheme.dangerRed),
              child: const Text('Remove Fingerprint'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _bullet(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 5, right: 8),
              child: Icon(
                AppIcons.circle,
                size: 6,
                color: context.colors.hint,
              ),
            ),
            Expanded(
              child: Text(text,
                  style:
                      TextStyle(fontSize: 12, color: context.colors.textBody)),
            ),
          ],
        ),
      );
}
