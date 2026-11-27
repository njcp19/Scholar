import 'package:flutter_test/flutter_test.dart';
import 'package:scholar_wallet/models/models.dart';
import 'package:scholar_wallet/screens/scan_claim_screen.dart';
import 'package:scholar_wallet/services/wallet_service.dart';

void main() {
  test('event preview without a scholar claim reports not on the payout list',
      () async {
    final wallet = _MockWalletService();

    await expectLater(
      loadScannedPayoutPreview(
        wallet: wallet,
        token: 'event-token',
        scholarId: 'scholar-1',
        eventBatchId: 'batch-1',
      ),
      throwsA(
        isA<WalletException>().having(
          (error) => error.message,
          'message',
          'You are not on this payout list. Please check with the office.',
        ),
      ),
    );

    expect(wallet.requestedBatchId, 'batch-1');
    expect(wallet.requestedScholarId, 'scholar-1');
  });

  test('maps event payout error codes to scholar-facing messages', () {
    expect(
      WalletService.programPayoutErrorMessage('CLAIM_NOT_IN_ROSTER'),
      'You are not on this payout list. Please check with the office.',
    );
    expect(
      WalletService.programPayoutErrorMessage('CLAIM_ALREADY_RECEIVED'),
      'You already received this allowance.',
    );
    expect(
      WalletService.programPayoutErrorMessage('CLAIM_VOIDED'),
      'This payout was cancelled.',
    );
    expect(
      WalletService.programPayoutErrorMessage('CLAIM_NOT_FOUND'),
      'This QR code is not valid.',
    );
    expect(
      WalletService.programPayoutErrorMessage('SCHOLAR_NOT_VERIFIED'),
      'A selected scholar is no longer active and verified. Refresh the roster and try again.',
    );
  });
}

class _MockWalletService implements WalletService {
  String? requestedBatchId;
  String? requestedScholarId;

  @override
  Future<AllowanceClaim?> previewProgramPayout({
    required String batchId,
    required String scholarId,
  }) async {
    requestedBatchId = batchId;
    requestedScholarId = scholarId;
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
