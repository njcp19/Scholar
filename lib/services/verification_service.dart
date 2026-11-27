import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

/// Verifies an existing scholarship beneficiary, not an application for funding.
class VerificationService {
  final SupabaseClient _db = Supabase.instance.client;

  Future<List<AppUser>> registrations() async {
    final rows = await _db
        .from('profiles')
        .select()
        .eq('role', 'scholar')
        .order('created_at', ascending: false);
    return rows.map((r) => AppUser.fromMap(r)).toList();
  }

  Future<List<Map<String, dynamic>>> history(String scholarId) async {
    final rows = await _db
        .from('registration_reviews')
        .select()
        .eq('scholar_id', scholarId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> review(
      AppUser registration, VerificationStatus decision, String notes) async {
    if (decision == VerificationStatus.pending) {
      throw ArgumentError('Select a review decision.');
    }
    if ((decision == VerificationStatus.rejected ||
            decision == VerificationStatus.needsInfo) &&
        notes.trim().isEmpty) {
      throw ArgumentError('Explain the reason or information required.');
    }
    final trimmedNotes = notes.trim();
    await _db.rpc('review_registration', params: {
      'p_scholar_id': registration.id,
      'p_expected_status': registration.verificationStatus.databaseValue,
      'p_decision': decision.databaseValue,
      'p_notes': trimmedNotes.isEmpty ? null : trimmedNotes,
      'p_roster_checked': decision == VerificationStatus.approved,
    });
  }

  Future<void> resubmit(
      {required bool declaredScholar,
      required String scholarshipName,
      required String? studentNumber,
      required String? university,
      required String? program,
      required String? yearLevel}) async {
    try {
      await _db.rpc('resubmit_registration', params: {
        'p_declared_scholar': declaredScholar,
        'p_scholarship_name': scholarshipName.trim(),
        'p_scholarship_reference': null,
        'p_student_number': studentNumber?.trim(),
        'p_university': university?.trim(),
        'p_program': program?.trim(),
        'p_year_level': yearLevel?.trim(),
      });
    } on PostgrestException catch (error) {
      final friendlyMessage = switch (error.message) {
        final message when message.contains('INVALID_FIELD') =>
          'Check your student number, university, program, and year level. '
              'Fields must not be blank or exceed their allowed length.',
        final message when message.contains('SCHOLARSHIP_NAME_REQUIRED') =>
          'Enter the name of your existing scholarship and try again.',
        final message when message.contains('DECLARATION_REQUIRED') =>
          'Choose whether you are already a scholar and try again.',
        final message when message.contains('INFORMATION_NOT_REQUESTED') =>
          'Your registration is no longer waiting for information. '
              'Refresh your verification status and try again.',
        _ => null,
      };
      if (friendlyMessage != null) {
        throw VerificationServiceException(friendlyMessage);
      }
      rethrow;
    }
  }
}

class VerificationServiceException implements Exception {
  final String message;

  const VerificationServiceException(this.message);
}
