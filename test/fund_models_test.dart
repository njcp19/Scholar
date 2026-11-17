import 'package:flutter_test/flutter_test.dart';
import 'package:scholar_wallet/models/models.dart';

void main() {
  test('funding account maps only the stored last four digits', () {
    final account = FundingAccount.fromMap({
      'bank_name': 'Sample Bank',
      'account_name': 'Alex Scholar',
      'account_last4': '6789',
      'linked_at': '2026-11-17T06:00:00Z',
    });

    expect(account.bankName, 'Sample Bank');
    expect(account.accountName, 'Alex Scholar');
    expect(account.last4, '6789');
    expect(account.linkedAt, DateTime.parse('2026-11-17T06:00:00Z').toLocal());
  });

  test('fund summary parses numeric JSON values', () {
    final summary = FundSummary.fromMap({
      'available': 5000,
      'reserved': 1200.5,
      'disbursed': 3800,
    });

    expect(summary.available, 5000);
    expect(summary.reserved, 1200.5);
    expect(summary.disbursed, 3800);
  });

  test('fund entries parse each supported kind and nullable fields', () {
    for (final kind in FundEntryKind.values) {
      final entry = FundEntry.fromMap({
        'id': 42,
        'kind': kind.name,
        'amount': 1000,
        'batch_id': null,
        'note': null,
        'created_at': '2026-11-17T06:00:00Z',
      });

      expect(entry.id, 42);
      expect(entry.kind, kind);
      expect(entry.amount, 1000);
      expect(entry.batchId, isNull);
      expect(entry.note, isNull);
      expect(
        entry.createdAt,
        DateTime.parse('2026-11-17T06:00:00Z').toLocal(),
      );
    }
  });

  test('fund entries reject unknown kinds', () {
    expect(
      () => FundEntry.fromMap({
        'id': 42,
        'kind': 'unknown',
        'amount': 1000,
        'created_at': '2026-11-17T06:00:00Z',
      }),
      throwsFormatException,
    );
  });
}
