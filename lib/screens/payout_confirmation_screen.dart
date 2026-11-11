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
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: Icon(
              AppIcons.back,
              color: context.colors.textPrimary,
            ),
          ),
          title: const Text('Review Allowance Amount'),
        ),
        body: SafeArea(
            child: ListView(padding: const EdgeInsets.all(24), children: [
          Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: context.colors.brandTint,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Icon(
                AppIcons.wallet,
                color: context.colors.brand,
                size: 24,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('AMOUNT TO RECEIVE', textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text('PHP ${fmtPhp(claim.amount)}',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .headlineLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Payout event: ${claim.batchTitle}'),
                        Text('Recipient: ${claim.scholarName}'),
                        Text('Claim reference: ${claim.id}'),
                        const SizedBox(height: 8),
                        const Text(
                            'The amount comes from the payout record, not from the scanned QR text. It cannot be edited here.'),
                      ]))),
          const SizedBox(height: 20),
          const Text(
              'Next: confirm using your device biometrics. If you cancel or verification fails, the payout will not be marked received.'),
          const SizedBox(height: 12),
          const Text(
              'This records allowance receipt in Scholar Wallet and adds it to your balance. You can try the demo Cash Out afterwards (simulation only).'),
          const SizedBox(height: 28),
          FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: Icon(
                AppIcons.fingerprint,
                color: context.colors.onHeader,
                size: 18,
              ),
              label: const Text('Continue to Biometrics')),
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
        ])),
      );
}
