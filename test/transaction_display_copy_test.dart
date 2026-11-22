import 'package:flutter_test/flutter_test.dart';
import 'package:scholar_wallet/widgets/widgets.dart';

void main() {
  test('transaction copy maps stored labels for display only', () {
    expect(
      displayWalletTransactionTitle('Cash-out to GCash'),
      'Withdraw Allowance to GCash',
    );
    expect(
      displayWalletTransactionDetails('Cash Out to linked account'),
      'Withdraw Allowance to linked account',
    );
    expect(
      displayWalletTransactionDetails('Simulated top-up'),
      'Funds allocated',
    );
    expect(
      displayWalletTransactionDetails('Scholarship allowance'),
      'Scholarship allowance',
    );
  });
}
