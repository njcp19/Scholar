import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/widgets.dart';

class ProgramPayoutQrScreen extends StatelessWidget {
  final String batchId;
  final String programName;
  final String title;
  final double amountPerScholar;
  final List<String> recipientNames;
  final String eventToken;

  const ProgramPayoutQrScreen({
    super.key,
    required this.batchId,
    required this.programName,
    required this.title,
    required this.amountPerScholar,
    required this.recipientNames,
    required this.eventToken,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (context.watch<AppState>().user?.role != UserRole.admin) {
      return Scaffold(
        backgroundColor: colors.background,
        body:
            const Center(child: Text('This page is available to admins only.')),
      );
    }

    final eventQr = AllowanceClaim(
      id: batchId,
      batchId: batchId,
      batchTitle: title,
      scholarId: '',
      scholarName: programName,
      amount: amountPerScholar,
      token: eventToken,
    );

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        leadingWidth: 70,
        leading: Padding(
          padding: const EdgeInsets.only(left: 26),
          child: IconButton(
            onPressed: () => Navigator.maybePop(context),
            style: IconButton.styleFrom(
              fixedSize: const Size(42, 42),
              padding: EdgeInsets.zero,
              backgroundColor: colors.surface,
              foregroundColor: colors.textPrimary,
              shape: const CircleBorder(),
              side: BorderSide(color: colors.borderSoft),
            ),
            icon: const Icon(AppIcons.back, size: 20),
          ),
        ),
        title: Text(
          'Payout event QR',
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
        backgroundColor: colors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          AppCard(
            radius: 22,
            shadow: true,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  programName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.textBody,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'PHP ${fmtPhp(amountPerScholar)} per scholar · '
                  '${recipientNames.length} recipients',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.brand,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: ClaimQrPanel(
                    claim: eventQr,
                    size: 210,
                    showToken: false,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'One event QR for this payout. Each listed scholar can scan it once.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.textBody,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            radius: 22,
            shadow: true,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionLabel(
                  'RECIPIENTS · ${recipientNames.length}',
                  labelColor: colors.textBody,
                  fontSize: 11.5,
                  letterSpacing: 1.1,
                ),
                const SizedBox(height: 8),
                for (final name in recipientNames)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Text(
                      name,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
