import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icons.dart';
import '../widgets/success_animation.dart';
import '../widgets/widgets.dart';
import 'history_screen.dart';

class PayoutReceivedScreen extends StatefulWidget {
  final AllowanceClaim claim;
  final double receivedAmount;

  const PayoutReceivedScreen({
    super.key,
    required this.claim,
    required this.receivedAmount,
  });

  @override
  State<PayoutReceivedScreen> createState() => _PayoutReceivedScreenState();
}

class _PayoutReceivedScreenState extends State<PayoutReceivedScreen> {
  bool _allowPop = false;
  bool _returningHome = false;

  void _backToHome() {
    if (_returningHome || !mounted) return;
    _returningHome = true;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    });
  }

  void _viewTransactions() {
    Navigator.pushAndRemoveUntil<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => const HistoryScreen()),
      (route) => route.isFirst,
    );
  }

  Widget _detailRow(
    BuildContext context, {
    required String label,
    required Widget value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: TextStyle(
                color: context.colors.textBody,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: value,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailText(BuildContext context, String text) {
    return Text(
      text,
      textAlign: TextAlign.right,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: context.colors.textPrimary,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _detailsCard(BuildContext context) {
    final claimedAt = widget.claim.claimedAt;
    final friendlyDate = claimedAt == null
        ? null
        : DateFormat('MMM d, yyyy · h:mm a').format(claimedAt.toLocal());

    return AppCard(
      radius: 26,
      shadow: true,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _detailRow(
            context,
            label: 'Payout',
            value: _detailText(context, widget.claim.batchTitle),
          ),
          if (friendlyDate != null) ...[
            Divider(height: 1, color: context.colors.borderSoft),
            _detailRow(
              context,
              label: 'Date',
              value: _detailText(context, friendlyDate),
            ),
          ],
          Divider(height: 1, color: context.colors.borderSoft),
          _detailRow(
            context,
            label: 'Scholar',
            value: _detailText(context, widget.claim.scholarName),
          ),
          Divider(height: 1, color: context.colors.borderSoft),
          _detailRow(
            context,
            label: 'Status',
            value: StatusChip(
              'Received',
              color: context.colors.successText,
              bg: context.colors.successBg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _hero(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        bottom: Radius.circular(38),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 32, 20, 72),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              context.colors.header,
              context.colors.heroGradientEnd,
            ],
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: -110,
              right: -52,
              child:
                  _circle(context.colors.onHeader.withValues(alpha: .12), 240),
            ),
            Positioned(
              bottom: -132,
              left: -106,
              child:
                  _circle(context.colors.onHeader.withValues(alpha: .1), 250),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 132,
                  height: 132,
                  decoration: BoxDecoration(
                    color: context.colors.success.withValues(alpha: .18),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Container(
                    width: 108,
                    height: 108,
                    decoration: BoxDecoration(
                      color: context.colors.success,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: SuccessAnimation(
                      size: 96,
                      fallbackIcon: AppIcons.check,
                      fallbackColor: context.colors.onHeader,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Payout received',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.colors.onHeader,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text.rich(
                      TextSpan(
                        style: TextStyle(
                          color: context.colors.onHeader,
                          fontWeight: FontWeight.w800,
                        ),
                        children: [
                          const TextSpan(
                            text: 'PHP ',
                            style: TextStyle(fontSize: 22),
                          ),
                          TextSpan(
                            text: fmtPhp(widget.receivedAmount),
                            style: const TextStyle(fontSize: 44),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.onHeader.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: context.colors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Text(
                        'Verified by QR and device biometrics',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.colors.onHeader,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomActions() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PrimaryButton(
              label: 'Back to Home',
              onPressed: _backToHome,
              minHeight: 56,
              borderRadius: 18,
            ),
            const SizedBox(height: 12),
            SecondaryButton(
              label: 'View transactions',
              onPressed: _viewTransactions,
              minHeight: 56,
              borderRadius: 18,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _backToHome();
      },
      child: Scaffold(
        backgroundColor: context.colors.background,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    children: [
                      _hero(context),
                      Transform.translate(
                        offset: const Offset(0, -42),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _detailsCard(context),
                        ),
                      ),
                      Transform.translate(
                        offset: const Offset(0, -42),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          child: InfoBanner(
                            icon: AppIcons.creditCard,
                            message:
                                'Added to your balance. You can cash out (demo) to a linked account anytime.',
                            maxLines: 3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _bottomActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _circle(Color color, double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}
