import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class FacilityRemoteDataSource {
  Future<List<Map<String, dynamic>>> fetchFacilities({
    required DateTime? updatedAfter,
    required int offset,
    required int limit,
  });
}

class SupabaseFacilityRemoteDataSource implements FacilityRemoteDataSource {
  final SupabaseClient? client;

  const SupabaseFacilityRemoteDataSource({required this.client});

  @override
  Future<List<Map<String, dynamic>>> fetchFacilities({
    required DateTime? updatedAfter,
    required int offset,
    required int limit,
  }) async {
    final supabase = client;
    if (supabase == null) {
      throw StateError('Supabase no está inicializado.');
    }

    var query = supabase.from('health_facilities').select();
    if (updatedAfter != null) {
      query = query.gt('updated_at', updatedAfter.toUtc().toIso8601String());
    }
    final rows = await query
        .order('updated_at', ascending: true)
        .order('id', ascending: true)
        .range(offset, offset + limit - 1);
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }
}
