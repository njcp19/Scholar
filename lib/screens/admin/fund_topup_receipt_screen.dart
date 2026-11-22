import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/app_theme.dart';
import '../../widgets/receipt_layout.dart';
import '../../widgets/widgets.dart';

class FundTopUpReceiptData {
  final double amount;
  final String fundingAccountLast4;
  final DateTime dateTime;
  final String? entryNumber;
  final double? newAvailableFund;

  const FundTopUpReceiptData({
    required this.amount,
    required this.fundingAccountLast4,
    required this.dateTime,
    this.entryNumber,
    this.newAvailableFund,
  });
}

class FundTopUpReceiptScreen extends StatelessWidget {
  final FundTopUpReceiptData data;

  const FundTopUpReceiptScreen({
    super.key,
    required this.data,
  });

  String? get _entryNumber {
    final value = data.entryNumber?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  @override
  Widget build(BuildContext context) {
    return ReceiptLayout(
      heading: 'Funds allocated',
      amount: data.amount,
      dateTime: data.dateTime,
      shareSubject: 'Allocate Funds receipt',
      rows: [
        const ReceiptDetailRow(label: 'Type', value: 'Allocate Funds'),
        ReceiptDetailRow(
          label: 'Funding account',
          value: '•••• ${data.fundingAccountLast4}',
        ),
        ReceiptDetailRow(
          label: 'Date',
          value: DateFormat('MMM d, yyyy · h:mm a').format(data.dateTime),
        ),
        if (_entryNumber != null)
          ReceiptDetailRow(
            label: 'Entry number',
            value: '#$_entryNumber',
          ),
        if (data.newAvailableFund != null)
          ReceiptDetailRow(
            label: 'New available fund',
            value: 'PHP ${fmtPhp(data.newAvailableFund!)}',
          ),
        ReceiptDetailRow(
          label: 'Status',
          statusLabel: 'COMPLETED',
          statusColor: context.colors.successText,
          statusBackgroundColor: context.colors.successBg,
        ),
      ],
      footer: 'This receipt confirms the funds were added to the payout fund.',
    );
  }
}
