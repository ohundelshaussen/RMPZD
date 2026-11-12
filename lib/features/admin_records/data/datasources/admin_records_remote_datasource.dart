import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/repositories/admin_records_repository.dart';

abstract interface class AdminRecordsRemoteDataSource {
  Future<List<Map<String, dynamic>>> fetchAssessments({
    required int offset,
    required int limit,
    required AdminAssessmentFilters filters,
  });
}

class SupabaseAdminRecordsRemoteDataSource
    implements AdminRecordsRemoteDataSource {
  final SupabaseClient? client;

  const SupabaseAdminRecordsRemoteDataSource({required this.client});

  @override
  Future<List<Map<String, dynamic>>> fetchAssessments({
    required int offset,
    required int limit,
    required AdminAssessmentFilters filters,
  }) async {
    final supabase = client;
    if (supabase == null) {
      throw StateError('Supabase no está inicializado.');
    }

    var query = supabase
        .from('assessments')
        .select('*, profiles!created_by(full_name, email)');
    if (filters.doctorId != null) {
      query = query.eq('created_by', filters.doctorId!);
    }
    if (filters.riskLevel != null) {
      query = query.eq('nivel_riesgo_predicho', filters.riskLevel!);
    }
    if (filters.department != null) {
      query = query.eq('departamento', filters.department!);
    }
    if (filters.fromDate != null) {
      query = query.gte(
        'fecha_evaluacion',
        DateTime(
          filters.fromDate!.year,
          filters.fromDate!.month,
          filters.fromDate!.day,
        ).toUtc().toIso8601String(),
      );
    }
    if (filters.toDate != null) {
      final exclusiveEnd = DateTime(
        filters.toDate!.year,
        filters.toDate!.month,
        filters.toDate!.day,
      ).add(const Duration(days: 1));
      query = query.lt(
        'fecha_evaluacion',
        exclusiveEnd.toUtc().toIso8601String(),
      );
    }

    final rows = await query
        .order('fecha_evaluacion', ascending: false)
        .range(offset, offset + limit - 1);
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }
}
