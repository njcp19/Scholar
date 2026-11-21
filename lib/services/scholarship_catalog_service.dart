import 'package:supabase_flutter/supabase_flutter.dart';

class ScholarshipCatalogItem {
  final int id;
  final String name;
  final bool isActive;

  const ScholarshipCatalogItem({
    required this.id,
    required this.name,
    required this.isActive,
  });

  factory ScholarshipCatalogItem.fromMap(Map<String, dynamic> map) {
    return ScholarshipCatalogItem(
      id: (map['id'] as num).toInt(),
      name: map['name'] as String,
      isActive: map['is_active'] as bool,
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
}
