import 'package:supabase_flutter/supabase_flutter.dart';

class ScholarshipProgramBudget {
  final String programName;
  final double? programBudget;
  final double budgetUsed;
  final double? budgetRemaining;

  const ScholarshipProgramBudget({
    required this.programName,
    required this.programBudget,
    required this.budgetUsed,
    required this.budgetRemaining,
  });

  factory ScholarshipProgramBudget.fromMap(Map<String, dynamic> map) =>
      ScholarshipProgramBudget(
        programName: map['program_name'] as String,
        programBudget: _numberOrNull(map['program_budget']),
        budgetUsed: _numberOrNull(map['budget_used']) ?? 0,
        budgetRemaining: _numberOrNull(map['budget_remaining']),
      );
}

double? _numberOrNull(Object? value) =>
    value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '');

class ScholarshipCatalogException implements Exception {
  final String message;

  const ScholarshipCatalogException(this.message);

  @override
  String toString() => message;
}

class ScholarshipCatalogItem {
  final int id;
  final String name;
  final bool isActive;
  final String? description;
  final double? allowanceAmount;
  final String? payoutFrequency;
  final int? supportFromYear;
  final int? supportToYear;
  final int? slots;
  final int slotsTaken;

  const ScholarshipCatalogItem({
    required this.id,
    required this.name,
    required this.isActive,
    this.description,
    this.allowanceAmount,
    this.payoutFrequency,
    this.supportFromYear,
    this.supportToYear,
    this.slots,
    this.slotsTaken = 0,
  });

  factory ScholarshipCatalogItem.fromMap(Map<String, dynamic> map) {
    final allowanceAmount = map['allowance_amount'];
    final supportFromYear = map['support_from_year'];
    final supportToYear = map['support_to_year'];
    final slots = map['slots'];
    final slotsTaken = map['slots_taken'];
    return ScholarshipCatalogItem(
      id: (map['id'] as num).toInt(),
      name: map['name'] as String,
      isActive: map['is_active'] as bool,
      description:
          map['description'] is String ? map['description'] as String : null,
      allowanceAmount: allowanceAmount is num
          ? allowanceAmount.toDouble()
          : double.tryParse(allowanceAmount?.toString() ?? ''),
      payoutFrequency: map['payout_frequency'] is String
          ? map['payout_frequency'] as String
          : null,
      supportFromYear: supportFromYear is num
          ? supportFromYear.toInt()
          : int.tryParse(supportFromYear?.toString() ?? ''),
      supportToYear: supportToYear is num
          ? supportToYear.toInt()
          : int.tryParse(supportToYear?.toString() ?? ''),
      slots:
          slots is num ? slots.toInt() : int.tryParse(slots?.toString() ?? ''),
      slotsTaken: slotsTaken is num
          ? slotsTaken.toInt()
          : int.tryParse(slotsTaken?.toString() ?? '') ?? 0,
    );
  }
}

class ScholarshipCatalogService {
  final SupabaseClient _client;

  ScholarshipCatalogService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  Future<List<ScholarshipCatalogItem>> list({
    required bool includeInactive,
  }) async {
    final rows = await _client.rpc(
      'list_scholarship_catalog',
      params: {'p_include_inactive': includeInactive},
    );
    return (rows as List<dynamic>)
        .map(
          (row) => ScholarshipCatalogItem.fromMap(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList(growable: false);
  }

  Future<void> add({required String name}) async {
    await _client.rpc(
      'add_scholarship_program',
      params: {'p_name': name},
    );
  }

  Future<void> rename({
    required int id,
    required String name,
  }) async {
    await _client.rpc(
      'rename_scholarship_program',
      params: {'p_id': id, 'p_name': name},
    );
  }

  Future<void> setActive({
    required int id,
    required bool active,
  }) async {
    await _client.rpc(
      'set_scholarship_program_active',
      params: {'p_id': id, 'p_active': active},
    );
  }

  Future<void> setDetails({
    required int id,
    String? description,
    double? allowanceAmount,
    String? payoutFrequency,
    int? supportFromYear,
    int? supportToYear,
    int? slots,
  }) async {
    await _client.rpc(
      'set_scholarship_program_details',
      params: {
        'p_id': id,
        'p_description': description,
        'p_allowance_amount': allowanceAmount,
        'p_payout_frequency': payoutFrequency,
        'p_support_from_year': supportFromYear,
        'p_support_to_year': supportToYear,
        'p_slots': slots,
      },
    );
  }

  Future<List<ScholarshipProgramBudget>> getProgramBudgets() async {
    try {
      final rows = await _client.rpc('get_program_budgets');
      if (rows is! List) {
        throw const FormatException('Invalid program budgets response.');
      }
      return rows
          .map((row) => ScholarshipProgramBudget.fromMap(
              Map<String, dynamic>.from(row as Map)))
          .toList(growable: false);
    } on PostgrestException catch (error) {
      throw ScholarshipCatalogException(_programError(error.message));
    }
  }

  Future<void> setProgramBudget({
    required String program,
    required double? budget,
  }) async {
    try {
      await _client.rpc(
        'set_program_budget',
        params: {'p_program': program, 'p_budget': budget},
      );
    } on PostgrestException catch (error) {
      throw ScholarshipCatalogException(_programError(error.message));
    }
  }

  String _programError(String raw) {
    if (raw.contains('ADMIN_REQUIRED')) {
      return 'Only an admin can manage program budgets.';
    }
    if (raw.contains('INVALID_BUDGET')) {
      return 'Enter a valid budget greater than or equal to zero.';
    }
    if (raw.contains('NOT_FOUND') || raw.contains('PROGRAM_NOT_FOUND')) {
      return 'This scholarship program could not be found.';
    }
    return 'Could not load or save program budgets. Please try again.';
  }
}
