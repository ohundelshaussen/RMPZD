import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/repositories/admin_records_repository.dart';

abstract interface class AdminRecordsRemoteDataSource {
  Future<List<Map<String, dynamic>>> fetchAssessments({
    required int offset,
    required int limit,
    required AdminAssessmentFilters filters,
  });

  Future<Map<String, dynamic>> updateAssessment({
    required String id,
    required Map<String, dynamic> updates,
  });

  Future<void> deleteAssessment({required String id});
}

class SupabaseAdminRecordsRemoteDataSource
    implements AdminRecordsRemoteDataSource {
  static final _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  final SupabaseClient? client;

  const SupabaseAdminRecordsRemoteDataSource({required this.client});

  @visibleForTesting
  static String? buildSearchOrFilter(String? rawSearch) {
    final trimmed = rawSearch?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    final sanitized = trimmed.replaceAll(RegExp(r'[,()*]'), ' ').trim();
    if (sanitized.isEmpty) return null;

    final clauses = <String>[
      'patient_id.ilike.%$sanitized%',
      'nombre_paciente.ilike.%$sanitized%',
    ];
    if (_uuidRegex.hasMatch(sanitized)) {
      clauses.add('created_by.eq.$sanitized');
    } else {
      final normalizedCode = sanitized.replaceAll(RegExp(r'[-\s]'), '');
      if (normalizedCode.isNotEmpty) {
        clauses.add('codigo_consulta.ilike.%$normalizedCode%');
      }
    }
    return clauses.join(',');
  }

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

    final searchOrFilter = buildSearchOrFilter(filters.searchQuery);
    if (searchOrFilter != null) {
      query = query.or(searchOrFilter);
    }

    final rows = await query
        .order('fecha_evaluacion', ascending: false)
        .range(offset, offset + limit - 1);
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  @override
  Future<Map<String, dynamic>> updateAssessment({
    required String id,
    required Map<String, dynamic> updates,
  }) async {
    final supabase = client;
    if (supabase == null) {
      throw StateError('Supabase no está inicializado.');
    }

    final mutableUpdates = Map<String, dynamic>.from(updates)
      ..remove('id')
      ..remove('created_by')
      ..remove('codigo_consulta');
    try {
      final row = await supabase
          .from('assessments')
          .update(mutableUpdates)
          .eq('id', id)
          .select('*, profiles!created_by(full_name, email)')
          .maybeSingle();
      if (row == null) {
        throw const AdminPermissionException(
          'El servidor no autorizó actualizar este registro (política RLS o registro inexistente).',
        );
      }
      return Map<String, dynamic>.from(row);
    } on PostgrestException catch (error) {
      if (error.code == '42501') {
        throw const AdminPermissionException(
          'El servidor no autoriza editar registros desde el cliente (política RLS).',
        );
      }
      rethrow;
    }
  }

  @override
  Future<void> deleteAssessment({required String id}) async {
    final supabase = client;
    if (supabase == null) {
      throw StateError('Supabase no está inicializado.');
    }

    try {
      final rows = await supabase
          .from('assessments')
          .delete()
          .eq('id', id)
          .select('id');
      if (rows.isEmpty) {
        throw const AdminPermissionException(
          'El servidor no autorizó eliminar este registro (política RLS o registro inexistente).',
        );
      }
    } on PostgrestException catch (error) {
      if (error.code == '42501') {
        throw const AdminPermissionException(
          'El servidor no autoriza eliminar registros desde el cliente (política RLS).',
        );
      }
      rethrow;
    }
  }
}
