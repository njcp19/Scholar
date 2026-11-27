import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';

/// Thrown for expected, user-facing failures (unknown QR, already received...).
class WalletException implements Exception {
  final String message;
  WalletException(this.message);
  @override
  String toString() => message;
}

class ClaimNotPendingException extends WalletException {
  ClaimNotPendingException()
      : super("This payout is no longer waiting and can't be cancelled.");
}

class ProgramRosterScholar {
  final String id;
  final String fullName;
  final String scholarshipName;

  const ProgramRosterScholar({
    required this.id,
    required this.fullName,
    required this.scholarshipName,
  });

  factory ProgramRosterScholar.fromMap(Map<String, dynamic> map) =>
      ProgramRosterScholar(
        id: map['id'].toString(),
        fullName: (map['full_name'] ?? '').toString(),
        scholarshipName: (map['scholarship_name'] ?? '').toString(),
      );
}

class ProgramPayoutRecipient {
  final String scholarId;
  final String scholarName;
  final double amount;
  final String status;

  const ProgramPayoutRecipient({
    required this.scholarId,
    required this.scholarName,
    required this.amount,
    required this.status,
  });

  factory ProgramPayoutRecipient.fromMap(Map<String, dynamic> map) =>
      ProgramPayoutRecipient(
        scholarId: (map['scholar_id'] ?? '').toString(),
        scholarName: (map['scholar_name'] ?? '').toString(),
        amount: ((map['amount'] ?? 0) as num).toDouble(),
        status: (map['status'] ?? '').toString(),
      );
}

class ProgramPayoutResult {
  final String batchId;
  final String program;
  final String title;
  final double amountPerScholar;
  final int recipientCount;
  final String eventToken;
  final List<ProgramPayoutRecipient> recipients;

  const ProgramPayoutResult({
    required this.batchId,
    required this.program,
    required this.title,
    required this.amountPerScholar,
    required this.recipientCount,
    required this.eventToken,
    required this.recipients,
  });

  factory ProgramPayoutResult.fromMap(Map<String, dynamic> map) =>
      ProgramPayoutResult(
        batchId: (map['batch_id'] ?? '').toString(),
        program: (map['program'] ?? '').toString(),
        title: (map['title'] ?? '').toString(),
        amountPerScholar: ((map['amount_per_scholar'] ?? 0) as num).toDouble(),
        recipientCount: ((map['recipient_count'] ?? 0) as num).toInt(),
        eventToken: (map['event_token'] ?? '').toString(),
        recipients: ((map['recipients'] ?? const []) as List)
            .map((row) => ProgramPayoutRecipient.fromMap(
                Map<String, dynamic>.from(row as Map)))
            .toList(growable: false),
      );
}

/// ALL money movement lives here.
///
/// v2 rules (scholar wallet only):
///  * The admin sets ONE standard allowance amount. Every scholar receives
///    exactly that amount — there is no per-scholar amount anywhere.
///  * A payout batch creates one single-use QR claim per scholar.
///  * The scholar confirms receipt by scanning that QR; the claim flips to
///    `received`, the balance is credited and a ledger entry is written.
///  * Cash-out (v3) is a MOCKUP: the scholar links a GCash / Maya / bank
///    account and the app simulates the transfer (balance deducted, simulated
///    reference). No payment gateway is called and no real money moves.
class WalletService {
  final SupabaseClient _db = Supabase.instance.client;

  final Random _rng = Random.secure();

  /// 32-char URL-safe random token embedded in the QR image.
  String newToken() {
    const alphabet =
        'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';
    return List.generate(32, (_) => alphabet[_rng.nextInt(alphabet.length)])
        .join();
  }

  // ------------------------------------------------- allowance (admin-owned)
  Future<AllowanceSettings> getAllowanceSettings() async {
    try {
      final row = await _db
          .from('allowance_settings')
          .select()
          .eq('id', 1)
          .maybeSingle();
      if (row == null) return AllowanceSettings.fallback;
      return AllowanceSettings.fromMap(Map<String, dynamic>.from(row));
    } catch (_) {
      // Table not migrated yet / offline: fall back to the fixed default so
      // the UI never shows a broken screen.
      return AllowanceSettings.fallback;
    }
  }

  /// Sets the single, uniform allowance. Applies to every scholar at once.
  Future<void> setAllowanceAmount(double amount, {String? label}) async {
    if (amount <= 0) {
      throw WalletException('Allowance amount must be greater than zero.');
    }
    await _db.from('allowance_settings').upsert({
      'id': 1,
      'allowance_amount': amount,
      if (label != null && label.trim().isNotEmpty) 'label': label.trim(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  // ------------------------------------------------------------------ wallet
  Future<double> getBalance(String scholarId) async {
    final row = await _db
        .from('profiles')
        .select('balance')
        .eq('id', scholarId)
        .maybeSingle();
    if (row == null) return 0;
    return ((row['balance'] ?? 0) as num).toDouble();
  }

  Future<List<WalletTransaction>> getTransactions(String scholarId,
      {int limit = 50}) async {
    final rows = await _db
        .from('transactions')
        .select()
        .eq('scholar_id', scholarId)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .map((m) => WalletTransaction.fromMap(m as Map<String, dynamic>))
        .toList();
  }

  // -------------------------------------------------------- payout batches
  Future<List<ProgramRosterScholar>> listProgramRoster(String program) async {
    try {
      final rows = await _db.rpc(
        'list_program_roster',
        params: {'p_program': program},
      );
      if (rows is! List) {
        throw const FormatException('Invalid program roster response.');
      }
      return rows
          .map((row) => ProgramRosterScholar.fromMap(
              Map<String, dynamic>.from(row as Map)))
          .toList(growable: false);
    } on PostgrestException catch (error) {
      throw WalletException(
          WalletService.programPayoutErrorMessage(error.message));
    }
  }

  Future<List<ProgramRosterScholar>> listUnassignedScholars() async {
    try {
      final rows = await _db.rpc('list_unassigned_scholars');
      if (rows is! List) {
        throw const FormatException('Invalid unassigned scholars response.');
      }
      return rows
          .map((row) => ProgramRosterScholar.fromMap(
              Map<String, dynamic>.from(row as Map)))
          .toList(growable: false);
    } on PostgrestException catch (error) {
      throw WalletException(
          WalletService.programPayoutErrorMessage(error.message));
    }
  }

  Future<ProgramPayoutResult> issueProgramPayout({
    required String program,
    required String title,
    required List<String> recipients,
    required DateTime distributionDate,
  }) async {
    try {
      final result = await _db.rpc(
        'issue_program_payout',
        params: {
          'p_program': program,
          'p_title': title.trim(),
          'p_recipients': recipients,
          'p_distribution_date':
              '${distributionDate.year.toString().padLeft(4, '0')}-'
                  '${distributionDate.month.toString().padLeft(2, '0')}-'
                  '${distributionDate.day.toString().padLeft(2, '0')}',
        },
      );
      if (result is! Map) {
        throw const FormatException('Invalid program payout response.');
      }
      return ProgramPayoutResult.fromMap(Map<String, dynamic>.from(result));
    } on PostgrestException catch (error) {
      throw WalletException(
          WalletService.programPayoutErrorMessage(error.message));
    }
  }

  Future<String> getPayoutEventToken(String batchId) async {
    try {
      final result = await _db.rpc(
        'get_payout_event_token',
        params: {'p_batch_id': batchId},
      );
      if (result is! String || result.isEmpty) {
        throw const FormatException('Invalid payout event token response.');
      }
      return result;
    } on PostgrestException catch (error) {
      if (error.message.contains('EVENT_NOT_FOUND')) {
        throw WalletException('The payout event QR could not be found.');
      }
      throw WalletException(
          WalletService.programPayoutErrorMessage(error.message));
    }
  }

  Future<AllowanceClaim?> previewProgramPayout({
    required String batchId,
    required String scholarId,
  }) async {
    final row = await _db
        .from('allowance_claims')
        .select('*, profiles(full_name)')
        .eq('batch_id', batchId)
        .eq('scholar_id', scholarId)
        .maybeSingle();
    if (row == null) return null;
    return AllowanceClaim.fromMap(Map<String, dynamic>.from(row));
  }

  Future<double> claimProgramPayout({
    required String eventToken,
    required String scholarId,
  }) async {
    try {
      final result = await _db.rpc(
        'claim_event_allowance',
        params: {
          'p_event_token': eventToken,
          'p_scholar_id': scholarId,
        },
      );
      if (result is! num) {
        throw const FormatException('Invalid payout receipt response.');
      }
      return result.toDouble();
    } on PostgrestException catch (error) {
      throw WalletException(
          WalletService.programPayoutErrorMessage(error.message));
    }
  }

  static String programPayoutErrorMessage(String raw) {
    if (raw.contains('CLAIM_NOT_IN_ROSTER')) {
      return 'You are not on this payout list. Please check with the office.';
    }
    if (raw.contains('CLAIM_ALREADY_RECEIVED')) {
      return 'You already received this allowance.';
    }
    if (raw.contains('CLAIM_VOIDED')) {
      return 'This payout was cancelled.';
    }
    if (raw.contains('CLAIM_NOT_FOUND')) {
      return 'This QR code is not valid.';
    }
    if (raw.contains('PROGRAM_NOT_FOUND')) {
      return 'This scholarship program could not be found.';
    }
    if (raw.contains('PROGRAM_ALLOWANCE_NOT_SET')) {
      return 'Set an allowance for this program before issuing a payout.';
    }
    if (raw.contains('PROGRAM_BUDGET_EXCEEDED')) {
      return "This payout is over the program's remaining budget.";
    }
    if (raw.contains('INSUFFICIENT_FUNDS')) {
      return 'There are not enough funds available for this payout.';
    }
    if (raw.contains('FUNDING_ACCOUNT_REQUIRED')) {
      return 'Link a funding account before issuing a payout.';
    }
    if (raw.contains('SCHOLAR_NOT_IN_PROGRAM')) {
      return 'A selected scholar is not in this program. Refresh the roster and try again.';
    }
    if (raw.contains('SCHOLAR_NOT_VERIFIED')) {
      return 'A selected scholar is no longer active and verified. Refresh the roster and try again.';
    }
    if (raw.contains('RECIPIENTS_REQUIRED')) {
      return 'Select at least one scholar for the payout.';
    }
    if (raw.contains('INVALID_BUDGET')) {
      return 'Enter a valid budget greater than or equal to zero.';
    }
    if (raw.contains('ADMIN_REQUIRED')) {
      return 'Only an admin can perform this action.';
    }
    return 'Could not complete the program payout. Please try again.';
  }

  /// Claims that are still waiting for the scholar to scan their QR.
  Future<List<AllowanceClaim>> getPendingClaims(String scholarId) async {
    try {
      final rows = await _db
          .from('allowance_claims')
          .select()
          .eq('scholar_id', scholarId)
          .eq('status', 'issued')
          .order('issued_at', ascending: false);
      return (rows as List)
          .map((m) =>
              AllowanceClaim.fromMap(Map<String, dynamic>.from(m as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<AllowanceClaim>> getMyClaims(String scholarId,
      {int limit = 60}) async {
    try {
      final rows = await _db
          .from('allowance_claims')
          .select()
          .eq('scholar_id', scholarId)
          .order('issued_at', ascending: false)
          .limit(limit);
      return (rows as List)
          .map((m) =>
              AllowanceClaim.fromMap(Map<String, dynamic>.from(m as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<AllowanceClaim>> getClaimsForBatch(String batchId) async {
    final rows = await _db
        .from('allowance_claims')
        .select('*, profiles(full_name)')
        .eq('batch_id', batchId)
        .order('id');
    return (rows as List)
        .map((m) => AllowanceClaim.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();
  }

  /// Admin: every claim ever issued, newest first (status oversight).
  Future<List<AllowanceClaim>> getAllClaims({int limit = 200}) async {
    try {
      final rows = await _db
          .from('allowance_claims')
          .select('*, profiles(full_name)')
          .order('issued_at', ascending: false)
          .limit(limit);
      return (rows as List)
          .map((m) =>
              AllowanceClaim.fromMap(Map<String, dynamic>.from(m as Map)))
          .toList();
    } catch (_) {
      final rows = await _db
          .from('allowance_claims')
          .select()
          .order('issued_at', ascending: false)
          .limit(limit);
      return (rows as List)
          .map((m) =>
              AllowanceClaim.fromMap(Map<String, dynamic>.from(m as Map)))
          .toList();
    }
  }

  /// Admin: cancel a claim that was never scanned.
  Future<void> voidClaim(String claimId) async {
    final updated = await _db
        .from('allowance_claims')
        .update({'status': 'voided'})
        .eq('id', claimId)
        .eq('status', 'issued')
        .select('id');
    if (updated.isEmpty) throw ClaimNotPendingException();
  }

  /// Read the claim behind a scanned token without redeeming it, so the
  /// scholar can see the amount before confirming with a fingerprint.
  Future<AllowanceClaim?> previewClaim(String token) async {
    try {
      final row = await _db
          .from('allowance_claims')
          .select('*, profiles(full_name)')
          .eq('token', token)
          .maybeSingle();
      if (row == null) return null;
      return AllowanceClaim.fromMap(Map<String, dynamic>.from(row));
    } catch (_) {
      return null;
    }
  }

  /// Admin: how much money is reserved but not yet received (issued claims).
  Future<double> getReservedTotal(String scholarId) async {
    final claims = await getPendingClaims(scholarId);
    return claims.fold<double>(0, (sum, c) => sum + c.amount);
  }

  /// Scholar: confirm receipt of the payout encoded in [token].
  ///
  /// Validation is done server-side inside the `claim_allowance` RPC
  /// (single use, right scholar, not voided) so the balance can never be
  /// credited twice. The lookup below only exists to produce a clear message.
  Future<double> claimAllowance({
    required String token,
    required String scholarId,
  }) async {
    Map<String, dynamic>? row;
    try {
      row = await _db
          .from('allowance_claims')
          .select()
          .eq('token', token)
          .maybeSingle();
    } catch (_) {
      row = null;
    }

    if (row != null) {
      final claim = AllowanceClaim.fromMap(Map<String, dynamic>.from(row));
      if (claim.scholarId != scholarId) {
        throw WalletException(
            'This QR code was issued to another scholar (${claim.scholarName}).');
      }
      if (claim.status == ClaimStatus.received) {
        throw WalletException(
            'Already received on ${_fmt(claim.claimedAt)} — the QR is single use.');
      }
      if (claim.status == ClaimStatus.voided) {
        throw WalletException('This payout was cancelled by the admin.');
      }
    }

    try {
      final res = await _db.rpc('claim_allowance', params: {
        'p_token': token,
        'p_scholar_id': scholarId,
      });
      if (res is num) return res.toDouble();
      if (row != null) return ((row['amount'] ?? 0) as num).toDouble();
      return 0;
    } on PostgrestException catch (e) {
      throw WalletException(_friendlyRpc(e.message));
    } catch (e) {
      throw WalletException(
          'Could not confirm receipt. Check your connection and try again. ($e)');
    }
  }

  String _friendlyRpc(String raw) {
    if (raw.contains('SCHOLAR_NOT_VERIFIED')) {
      return 'Only active, admin-verified scholars can receive allowance.';
    }
    if (raw.contains('CLAIM_ALREADY_RECEIVED')) {
      return 'This payout was already confirmed — each QR can only be used once.';
    }
    if (raw.contains('CLAIM_NOT_FOUND')) {
      return 'This QR code is not a valid Scholar Wallet payout.';
    }
    if (raw.contains('CLAIM_WRONG_SCHOLAR')) {
      return 'This QR code belongs to another scholar.';
    }
    if (raw.contains('CLAIM_VOIDED')) {
      return 'This payout was cancelled by the admin.';
    }
    return 'Could not confirm receipt: $raw';
  }

  String _fmt(DateTime? d) {
    if (d == null) return 'an earlier date';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} '
        '${two(d.hour)}:${two(d.minute)}';
  }

  // ------------------------------------------------------------- cash-out
  static const double minCashout = 100;

  Future<List<LinkedAccount>> getLinkedAccounts(String scholarId) async {
    final rows = await _db
        .from('linked_accounts')
        .select()
        .eq('scholar_id', scholarId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((m) => LinkedAccount.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();
  }

  Future<void> linkAccount({
    required PayoutProvider provider,
    String bankName = '',
    required String accountName,
    required String accountNumber,
  }) async {
    try {
      await _db.rpc('link_account', params: {
        'p_provider': provider.name,
        'p_bank_name': bankName,
        'p_account_name': accountName,
        'p_account_number': accountNumber,
      });
    } on PostgrestException catch (e) {
      throw WalletException(_friendlyCashout(e.message));
    }
  }

  Future<void> unlinkAccount(int accountId) async {
    try {
      await _db.rpc('unlink_account', params: {'p_account_id': accountId});
    } on PostgrestException catch (e) {
      throw WalletException(_friendlyCashout(e.message));
    }
  }

  /// Simulated cash-out (mockup). Returns nothing; history shows the result.
  Future<void> requestWithdrawal(
      {required int accountId,
      required double amount,
      required String idempotencyKey}) async {
    try {
      await _db.rpc('request_withdrawal', params: {
        'p_account_id': accountId,
        'p_amount': amount,
        'p_idempotency_key': idempotencyKey,
      });
    } on PostgrestException catch (e) {
      throw WalletException(_friendlyCashout(e.message));
    }
  }

  Future<List<Withdrawal>> getMyWithdrawals(String scholarId,
      {int limit = 50}) async {
    final rows = await _db
        .from('withdrawals')
        .select()
        .eq('scholar_id', scholarId)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .map((m) => Withdrawal.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();
  }

  String _friendlyCashout(String raw) {
    const map = {
      'SCHOLAR_NOT_VERIFIED':
          'Only active, admin-verified scholars can cash out.',
      'BAD_MOBILE_NUMBER':
          'Enter an 11-digit mobile number that starts with 09.',
      'BAD_ACCOUNT_NAME': 'Enter the name registered on the account.',
      'BAD_BANK_NAME': 'Enter the bank name.',
      'BAD_ACCOUNT_NUMBER': 'Enter a valid bank account number.',
      'ACCOUNT_ALREADY_LINKED': 'This account is already linked.',
      'ACCOUNT_NOT_FOUND': 'That linked account no longer exists.',
      'BELOW_MINIMUM': 'The amount is below the minimum cash-out.',
      'BAD_AMOUNT': 'Use at most 2 decimal places.',
      'INSUFFICIENT_BALANCE': 'Not enough balance for this cash-out.',
      'INVALID_KEY':
          'This Cash Out request could not be verified. Please review it and try again.',
      'KEY_REUSED_WITH_DIFFERENT_REQUEST':
          'This request key is already associated with a different Cash Out. Check your Cash Out history before trying again.',
    };
    for (final e in map.entries) {
      if (raw.contains(e.key)) return e.value;
    }
    return 'Cash-out failed: $raw';
  }

  // ---------------------------------------------------------------- admin
  Future<FundingAccount?> getFundingAccount() async {
    try {
      final result = await _db.rpc('get_funding_account');
      if (result == null) return null;
      if (result is! Map) {
        throw const FormatException('Invalid funding account response.');
      }
      return FundingAccount.fromMap(Map<String, dynamic>.from(result));
    } on PostgrestException catch (e) {
      throw WalletException(_friendlyFundingError(
        e.message,
        fallback: 'Could not load the funding account. Try again.',
      ));
    }
  }

  Future<void> linkFundingAccount({
    required String bank,
    required String accountName,
    required String accountNumber,
  }) async {
    try {
      await _db.rpc('link_funding_account', params: {
        'p_bank': bank,
        'p_name': accountName,
        'p_number': accountNumber,
      });
    } on PostgrestException catch (e) {
      throw WalletException(_friendlyFundingError(
        e.message,
        fallback: 'Could not link the funding account. Try again.',
      ));
    }
  }

  Future<void> topUpFund(double amount) async {
    try {
      await _db.rpc('fund_topup', params: {'p_amount': amount});
    } on PostgrestException catch (e) {
      throw WalletException(_friendlyFundingError(
        e.message,
        fallback: 'Could not top up the fund. Try again.',
      ));
    }
  }

  Future<FundSummary> getFundSummary() async {
    try {
      final result = await _db.rpc('get_fund_summary');
      if (result is! Map) {
        throw const FormatException('Invalid fund summary response.');
      }
      return FundSummary.fromMap(Map<String, dynamic>.from(result));
    } on PostgrestException catch (e) {
      throw WalletException(_friendlyFundingError(
        e.message,
        fallback: 'Could not load the fund summary. Try again.',
      ));
    }
  }

  Future<List<FundEntry>> getFundActivity({int limit = 30}) async {
    try {
      final result =
          await _db.rpc('get_fund_activity', params: {'p_limit': limit});
      if (result is! List) {
        throw const FormatException('Invalid fund activity response.');
      }
      return result
          .map(
              (row) => FundEntry.fromMap(Map<String, dynamic>.from(row as Map)))
          .toList();
    } on PostgrestException catch (e) {
      throw WalletException(_friendlyFundingError(
        e.message,
        fallback: 'Could not load fund activity. Try again.',
      ));
    }
  }

  String _friendlyFundingError(String raw, {required String fallback}) {
    if (raw.contains('FUNDING_ACCOUNT_REQUIRED')) {
      return 'Link a funding account first.';
    }
    if (raw.contains('INSUFFICIENT_FUNDS')) {
      return 'Not enough funds for this payout. Top up the fund first.';
    }
    if (raw.contains('INVALID_ACCOUNT')) return 'Check the bank details.';
    if (raw.contains('INVALID_AMOUNT')) {
      return 'Enter a valid amount greater than zero.';
    }
    if (raw.contains('ADMIN_REQUIRED')) {
      return 'Only an admin can access funding data.';
    }
    return fallback;
  }

  Future<int> getActiveScholarCount() async {
    final rows = await _db
        .from('profiles')
        .select('id')
        .eq('role', 'scholar')
        .eq('is_active', true)
        .eq('verification_status', 'approved');
    return (rows as List).length;
  }

  Future<int> getPendingClaimCount() async {
    try {
      final rows = await _db
          .from('allowance_claims')
          .select('id')
          .eq('status', 'issued');
      return (rows as List).length;
    } catch (_) {
      return 0;
    }
  }

  Future<int> getReceivedClaimCount() async {
    try {
      final rows = await _db
          .from('allowance_claims')
          .select('id')
          .eq('status', 'received');
      return (rows as List).length;
    } catch (_) {
      return 0;
    }
  }

  Future<List<Scholar>> getScholars() async {
    final rows = await _db
        .from('profiles')
        .select()
        .eq('role', 'scholar')
        .order('full_name');
    return (rows as List)
        .map((m) => Scholar.fromMap(m as Map<String, dynamic>))
        .toList();
  }

  Future<void> setScholarActive(String id, bool active) =>
      _db.rpc('set_verified_scholar_active',
          params: {'p_scholar_id': id, 'p_active': active});

  /// Admin: permanently delete one scholar account and its records.
  Future<void> deleteScholar(String id) async {
    try {
      await _db.rpc('admin_delete_scholar', params: {'p_scholar_id': id});
    } on PostgrestException catch (e) {
      throw WalletException(_deleteError(e));
    }
  }

  /// Admin: delete all finished, inactive scholars (rejected or deactivated,
  /// zero balance). Pending registrations are never touched. Returns count.
  Future<int> deleteInactiveScholars() async {
    try {
      final n = await _db.rpc('admin_delete_inactive_scholars');
      return (n as num?)?.toInt() ?? 0;
    } on PostgrestException catch (e) {
      throw WalletException(_deleteError(e));
    }
  }

  String _deleteError(PostgrestException e) {
    final m = '${e.message} ${e.details}';
    if (m.contains('BALANCE_NOT_ZERO')) {
      return 'This scholar still has a balance. Settle it before deleting.';
    }
    if (m.contains('CANNOT_DELETE_ADMIN')) {
      return 'Admin accounts cannot be deleted.';
    }
    if (m.contains('ADMIN_REQUIRED'))
      return 'Only an admin can delete accounts.';
    if (m.contains('ACCOUNT_NOT_FOUND')) return 'Account no longer exists.';
    if (m.contains('HAS_LINKED_RECORDS')) {
      return 'Account has linked records and cannot be deleted.';
    }
    return 'Delete failed. Run the latest supabase_setup.sql first. (${e.message})';
  }

  Future<List<Map<String, dynamic>>> getDisbursements() async {
    final rows = await _db
        .from('disbursements')
        .select()
        .order('created_at', ascending: false)
        .limit(50);
    return (rows as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  /// Admin overview numbers for the dashboard.
  Future<Map<String, num>> getAllowanceSummary() async {
    final settings = await getAllowanceSettings();
    final pending = await getPendingClaimCount();
    final received = await getReceivedClaimCount();
    return {
      'amount': settings.allowanceAmount,
      'pending': pending,
      'received': received,
    };
  }
}
