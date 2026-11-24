import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class AssessmentRemoteDataSource {
  Future<void> upsertBatch(List<Map<String, dynamic>> payload);
  Future<Map<String, dynamic>> regenerateConsultationCode(String uuid);
  Future<List<Map<String, dynamic>>> fetchOwnAssessments(
    String ownerId, {
    String? updatedAfter,
    int offset = 0,
    int limit = 200,
  });

  bool isNetworkFailure(Object error);

  bool isClientFailure(Object error);
}

class SupabaseAssessmentRemoteDataSource implements AssessmentRemoteDataSource {
  final SupabaseClient? client;

  const SupabaseAssessmentRemoteDataSource({required this.client});

  @override
  Future<void> upsertBatch(List<Map<String, dynamic>> payload) async {
    final supabase = client;
    if (supabase == null) {
      throw StateError('Supabase no está inicializado.');
    }
    await supabase
        .from('assessments')
        .upsert(payload, onConflict: 'id', ignoreDuplicates: true);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchOwnAssessments(
    String ownerId, {
    String? updatedAfter,
    int offset = 0,
    int limit = 200,
  }) async {
    final supabase = client;
    if (supabase == null) {
      throw StateError('Supabase no está inicializado.');
    }
    const columns =
        'id, created_by, patient_id, municipio, departamento, etnia, zona, '
        'edad_materna, semanas_gestacion, numero_controles, distancia_km, '
        'tiempo_traslado_horas, hemoglobina, presion_sistolica, '
        'presion_diastolica, imc, antecedente_preeclampsia, '
        'antecedente_diabetes, parto_institucional_previo, afiliacion_sgsss, '
        'fecha_evaluacion, nivel_riesgo_predicho, probabilidad_riesgo_alto, '
        'alerta_clinica_inmediata, descripcion_alerta, '
        'probabilidad_desenlace_adverso, nombre_paciente, direccion_paciente, '
        'latitud, longitud, precision_gps_m, ubicacion_capturada_at, '
        'consentimiento_datos, consentimiento_at, created_at, updated_at';
    var query = supabase
        .from('assessments')
        .select(columns)
        .eq('created_by', ownerId);
    if (updatedAfter != null) {
      query = query.gt('updated_at', updatedAfter);
    }
    final rows = await query
        .order('updated_at')
        .order('id')
        .range(offset, offset + limit - 1);
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  @override
  Future<Map<String, dynamic>> regenerateConsultationCode(String uuid) async {
    final supabase = client;
    if (supabase == null) {
      throw StateError('Supabase no está inicializado.');
    }
    final response = await supabase.rpc(
      'regenerar_codigo_consulta',
      params: {'p_assessment_id': uuid},
    );
    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }
    if (response is List && response.isNotEmpty && response.first is Map) {
      return Map<String, dynamic>.from(response.first as Map);
    }
    return {'ok': false, 'motivo': 'error'};
  }

  @override
  bool isNetworkFailure(Object error) {
    if (error is SocketException || error is TimeoutException) return true;
    final message = error.toString().toLowerCase();
    return message.contains('socketexception') ||
        message.contains('failed host lookup') ||
        message.contains('network is unreachable') ||
        message.contains('connection refused') ||
        message.contains('connection reset') ||
        message.contains('timed out') ||
        message.contains('clientexception');
  }

  @override
  bool isClientFailure(Object error) {
    if (error is! PostgrestException) return false;
    final code = error.code ?? '';
    return code.startsWith('22') ||
        code.startsWith('23') ||
        code.startsWith('28') ||
        code.startsWith('42') ||
        code.startsWith('PGRST');
  }
}
