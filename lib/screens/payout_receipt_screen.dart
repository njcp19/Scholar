import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icons.dart';
import '../widgets/receipt_layout.dart';
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
        leadingWidth: 70,
        leading: Padding(
          padding: const EdgeInsets.only(left: 26),
          child: Material(
            color: context.colors.surface,
            shape: CircleBorder(
              side: BorderSide(color: context.colors.borderSoft),
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
            fontSize: 17,
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
              radius: 22,
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

  Widget _hero(BuildContext context, String? receivedDate) => ReceiptHeroCard(
        heading: 'Payout received',
        amount: claim.amount,
        dateLabel: receivedDate,
      );

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
}
