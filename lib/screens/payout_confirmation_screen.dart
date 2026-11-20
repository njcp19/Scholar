import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';
import '../widgets/app_icons.dart';

/// Displays the database amount before the device biometric prompt.
/// This confirms allowance receipt only. Getting cash is the separate Cash Out feature.
class PayoutConfirmationScreen extends StatelessWidget {
  final AllowanceClaim claim;
  const PayoutConfirmationScreen({super.key, required this.claim});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final amount = 'PHP ${fmtPhp(claim.amount)}';

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        surfaceTintColor: Colors.transparent,
        leadingWidth: 70,
        leading: Padding(
          padding: const EdgeInsets.only(left: 26),
          child: Material(
            color: colors.surface,
            shape: CircleBorder(
              side: BorderSide(color: colors.borderSoft),
            ),
            child: IconButton(
              onPressed: () => Navigator.maybePop(context),
              tooltip: 'Back',
              constraints: const BoxConstraints.tightFor(
                width: 44,
                height: 44,
              ),
              padding: EdgeInsets.zero,
              icon: Icon(
                AppIcons.back,
                color: colors.textPrimary,
              ),
            ),
          ),
        ),
        title: const SizedBox(
          width: 180,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'Review Allowance Amount',
              maxLines: 1,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1E5AA8), Color(0xFF123F86)],
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: colors.cardShadow,
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .15),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      AppIcons.wallet,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'AMOUNT TO RECEIVE',
                    style: TextStyle(
                      color: Color(0xBFFFFFFF),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: Semantics(
                      label: 'Amount to receive, $amount',
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          amount,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .15),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(AppIcons.check, color: Colors.white, size: 15),
                          SizedBox(width: 6),
                          Text(
                            'From the payout record',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              radius: 22,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              borderColor: const Color(0xFFEEF1F6),
              child: Column(
                children: [
                  _PayoutDetailRow(
                    label: 'Payout event',
                    value: claim.batchTitle,
                  ),
                  const Divider(
                      height: 1, thickness: 1, color: Color(0xFFEEF1F6)),
                  _PayoutDetailRow(
                    label: 'Recipient',
                    value: claim.scholarName,
                  ),
                  const Divider(
                      height: 1, thickness: 1, color: Color(0xFFEEF1F6)),
                  _PayoutDetailRow(
                    label: 'Payout reference',
                    value: claim.id,
                    reference: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF2FE),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(AppIcons.info, color: Color(0xFF1E5AA8), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'The amount comes from the payout record, not from the scanned QR text. It cannot be edited here.',
                      style: TextStyle(
                        color: Color(0xFF1A2530),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF6E3),
                border: Border.all(color: const Color(0xFFF3D9A0)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(AppIcons.shieldCheck,
                      color: Color(0xFF4A3200), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Next: confirm using your device biometrics. If you cancel or verification fails, the payout will not be marked received.',
                      style: TextStyle(
                        color: Color(0xFF4A3200),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'This records allowance receipt in Scholar Wallet and adds it to your balance.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF6B7686),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Continue to Biometrics',
              icon: AppIcons.fingerprint,
              onPressed: () => Navigator.pop(context, true),
              minHeight: 56,
              borderRadius: 18,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF1E5AA8),
                minimumSize: const Size(64, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PayoutDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool reference;

  const _PayoutDetailRow({
    required this.label,
    required this.value,
    this.reference = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF6B7686),
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: reference ? 1 : 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF1A2530),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
