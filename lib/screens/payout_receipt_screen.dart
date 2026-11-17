import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icons.dart';
import '../widgets/widgets.dart';

class PayoutReceiptScreen extends StatelessWidget {
  final AllowanceClaim claim;

  PayoutReceiptScreen({
    super.key,
    required this.claim,
  }) : assert(claim.status == ClaimStatus.received);

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppState>().user;
    final currentName = user?.fullName.trim();
    final scholarName = currentName != null && currentName.isNotEmpty
        ? currentName
        : claim.scholarName.trim();
    final studentNumber = user?.studentNumber?.trim();
    final receivedAt = claim.claimedAt?.toLocal();
    final receivedDate = receivedAt == null
        ? null
        : DateFormat('MMM d, yyyy · h:mm a').format(receivedAt);
    final details = <Widget>[
      if (scholarName.isNotEmpty)
        _detailRow(
          context,
          label: 'Scholar',
          value: _detailText(context, scholarName),
        ),
      if (studentNumber != null && studentNumber.isNotEmpty)
        _detailRow(
          context,
          label: 'Student ID',
          value: _detailText(context, studentNumber),
        ),
      if (claim.batchTitle.trim().isNotEmpty)
        _detailRow(
          context,
          label: 'Payout Event',
          value: _detailText(context, claim.batchTitle),
        ),
      _detailRow(
        context,
        label: 'Received on',
        value: _detailText(context, receivedDate ?? 'Not available'),
      ),
      _detailRow(
        context,
        label: 'Verified with',
        value: _detailText(context, 'Device biometrics'),
      ),
      _detailRow(
        context,
        label: 'Status',
        value: Align(
          alignment: Alignment.centerRight,
          child: StatusChip(
            'RECEIVED',
            color: context.colors.successText,
            bg: context.colors.successBg,
            borderRadius: 10,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            fontSize: 11,
            letterSpacing: .3,
          ),
        ),
      ),
    ];

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: context.colors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leadingWidth: 62,
        leading: Padding(
          padding: const EdgeInsets.only(left: 14),
          child: Material(
            color: context.colors.surface,
            shape: CircleBorder(
              side: BorderSide(color: context.colors.borderSoft),
            ),
            child: IconButton(
              onPressed: () => Navigator.maybePop(context),
              tooltip: 'Back',
              constraints: const BoxConstraints.tightFor(
                width: 42,
                height: 42,
              ),
              padding: EdgeInsets.zero,
              icon: Icon(
                AppIcons.back,
                color: context.colors.textPrimary,
                size: 21,
              ),
            ),
          ),
        ),
        title: Text(
          'Receipt',
          style: TextStyle(
            color: context.colors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            _hero(context, receivedDate),
            const SizedBox(height: 16),
            AppCard(
              radius: 24,
              shadow: true,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var index = 0; index < details.length; index++) ...[
                    if (index > 0)
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: context.colors.borderSoft,
                      ),
                    details[index],
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'This receipt confirms the payout was released to your Scholar Wallet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.colors.textBody,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hero(BuildContext context, String? receivedDate) {
    final mutedHeroText = context.colors.onHeader.withValues(alpha: .84);
    return AppCard(
      radius: 28,
      shadow: true,
      clipBehavior: Clip.hardEdge,
      borderColor: Colors.transparent,
      borderWidth: 0,
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 22),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [context.colors.header, context.colors.receiptHeroEnd],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -116,
            right: -100,
            child: _circle(context.colors.onHeader.withValues(alpha: .12), 230),
          ),
          Positioned(
            bottom: -132,
            left: -104,
            child: _circle(context.colors.onHeader.withValues(alpha: .1), 250),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: context.colors.onHeader.withValues(alpha: .18),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: context.colors.success,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    AppIcons.check,
                    color: context.colors.onHeader,
                    size: 36,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Payout received',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: mutedHeroText,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
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
                          style: TextStyle(fontSize: 16),
                        ),
                        TextSpan(
                          text: fmtPhp(claim.amount),
                          style: const TextStyle(
                            fontSize: 38,
                            letterSpacing: -1,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    softWrap: false,
                  ),
                ),
              ),
              if (receivedDate != null) ...[
                const SizedBox(height: 8),
                Text(
                  receivedDate,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: mutedHeroText,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailRow(
    BuildContext context, {
    required String label,
    required Widget value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                color: context.colors.textBody,
                fontSize: 13.5,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
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
      style: TextStyle(
        color: context.colors.textPrimary,
        fontSize: 13.5,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _circle(Color color, double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}
