import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/doctor_monitoring_case.dart';

abstract interface class DoctorMonitoringRemoteDataSource {
  Future<Map<String, DoctorMonitoringCase>> fetchCaseStatuses(
    List<String> assessmentIds,
  );

  Future<DoctorReferralResult> referAssessment(
    String assessmentId,
    String motive,
  );
}

class SupabaseDoctorMonitoringRemoteDataSource
    implements DoctorMonitoringRemoteDataSource {
  final SupabaseClient? client;

  const SupabaseDoctorMonitoringRemoteDataSource({required this.client});

  @override
  Future<Map<String, DoctorMonitoringCase>> fetchCaseStatuses(
    List<String> assessmentIds,
  ) async {
    if (assessmentIds.isEmpty) return {};
    final rows = await _requireClient()
        .from('casos_monitoreo')
        .select('assessment_id, estado, resultado, creado_en, cerrado_en')
        .inFilter('assessment_id', assessmentIds)
        .order('creado_en', ascending: false);
    final statuses = <String, DoctorMonitoringCase>{};
    for (final row in rows) {
      final assessmentId = row['assessment_id'];
      final state = row['estado'];
      if (assessmentId is! String || state is! String) continue;
      statuses.putIfAbsent(
        assessmentId,
        () => DoctorMonitoringCase(
          state: state,
          result: row['resultado'] is String
              ? row['resultado'] as String
              : null,
          closedAt: DateTime.tryParse(row['cerrado_en'] as String? ?? ''),
        ),
      );
    }
    return statuses;
  }

  @override
  Future<DoctorReferralResult> referAssessment(
    String assessmentId,
    String motive,
  ) async {
    final response = await _requireClient().rpc(
      'remitir_registro',
      params: {'p_assessment_id': assessmentId, 'p_motivo': motive},
    );
    final result = _responseMap(response);
    final ok = result['ok'];
    if (ok is! bool) {
      throw StateError('La respuesta de remitir_registro no es válida.');
    }
    return DoctorReferralResult(
      ok: ok,
      motive: result['motivo'] is String ? result['motivo'] as String : null,
      reopened: result['reabierto'] == true,
      state: result['estado'] is String ? result['estado'] as String : null,
    );
  }

  Map<String, dynamic> _responseMap(Object? response) {
    if (response is Map) return Map<String, dynamic>.from(response);
    if (response is List && response.isNotEmpty && response.first is Map) {
      return Map<String, dynamic>.from(response.first as Map);
    }
    throw StateError('La respuesta de remitir_registro no es válida.');
  }

  SupabaseClient _requireClient() {
    final supabase = client;
    if (supabase == null) {
      throw StateError('Supabase no está inicializado.');
    }
    return supabase;
  }
}
