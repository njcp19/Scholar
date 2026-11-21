import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/receipt_layout.dart';

class CashoutReceiptScreen extends StatelessWidget {
  final Withdrawal withdrawal;

  const CashoutReceiptScreen({
    super.key,
    required this.withdrawal,
  });

  String? get _maskedAccount {
    final account = withdrawal.accountNumber.trim().replaceAll(
          RegExp(r'\s+'),
          '',
        );
    if (account.isEmpty) return null;
    final lastFour =
        account.length <= 4 ? account : account.substring(account.length - 4);
    return '•••• $lastFour';
  }

  String get _statusLabel => withdrawal.status == WithdrawalStatus.completed
      ? 'COMPLETED'
      : withdrawal.status.label;

  Color _statusColor(BuildContext context) => switch (withdrawal.status) {
        WithdrawalStatus.completed => context.colors.successText,
        WithdrawalStatus.pending ||
        WithdrawalStatus.processing =>
          context.colors.warningText,
        WithdrawalStatus.failed ||
        WithdrawalStatus.cancelled =>
          context.colors.dangerText,
      };

  Color _statusBackground(BuildContext context) => switch (withdrawal.status) {
        WithdrawalStatus.completed => context.colors.successBg,
        WithdrawalStatus.pending ||
        WithdrawalStatus.processing =>
          context.colors.warningBg,
        WithdrawalStatus.failed ||
        WithdrawalStatus.cancelled =>
          context.colors.dangerBg,
      };

  @override
  Widget build(BuildContext context) {
    final dateTime = withdrawal.processedAt ?? withdrawal.createdAt;
    return ReceiptLayout(
      heading: withdrawal.status == WithdrawalStatus.completed
          ? 'Cash Out completed'
          : 'Cash Out status',
      amount: withdrawal.amount,
      dateTime: dateTime,
      shareSubject: 'Cash Out receipt',
      rows: [
        ReceiptDetailRow(
          label: 'Sent to',
          value: withdrawal.providerLabel,
        ),
        ReceiptDetailRow(
          label: 'Account name',
          value: withdrawal.accountName,
        ),
        ReceiptDetailRow(
          label: 'Account',
          value: _maskedAccount,
        ),
        ReceiptDetailRow(
          label: 'Reference',
          value: withdrawal.reference,
        ),
        ReceiptDetailRow(
          label: 'Date',
          value: DateFormat('MMM d, yyyy · h:mm a').format(dateTime),
        ),
        ReceiptDetailRow(
          label: 'Status',
          statusLabel: _statusLabel,
          statusColor: _statusColor(context),
          statusBackgroundColor: _statusBackground(context),
        ),
      ],
      footer:
          'This receipt confirms your Cash Out was recorded in Scholar Wallet.',
    );
  }
}
