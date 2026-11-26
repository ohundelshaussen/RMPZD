import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/monitoring_case.dart';

abstract interface class CaseRemoteDataSource {
  Stream<MonitoringCaseChange> get changes;

  Future<void> takeCase(String caseId);

  Future<void> releaseCase(String caseId);

  Future<void> registerEvent({
    required String caseId,
    required String type,
    String? note,
    String? centerId,
  });

  Future<void> closeCase({
    required String caseId,
    required String result,
    String? note,
  });

  Future<List<MonitoringCase>> fetchCases({
    required MonitoringCaseStatus status,
    String? assignedTo,
    String? closedBy,
    required int offset,
    int limit = 50,
  });

  Future<MonitoringCase?> fetchCaseById(String caseId);

  Future<int> fetchNewCasesCount();

  Future<void> startRealtime({
    required void Function(bool connected) onConnectionChanged,
  });

  Future<void> stopRealtime();
}

abstract interface class CaseRpcClient {
  Future<Object?> call(String function, {required Map<String, dynamic> params});
}

class SupabaseCaseRpcClient implements CaseRpcClient {
  final SupabaseClient client;

  const SupabaseCaseRpcClient(this.client);

  @override
  Future<Object?> call(
    String function, {
    required Map<String, dynamic> params,
  }) => client.rpc(function, params: params);
}

class MonitoringActionException implements Exception {
  final String motivo;
  final String message;

  const MonitoringActionException(this.motivo, this.message);

  @override
  String toString() => message;
}

class SupabaseCaseRemoteDataSource implements CaseRemoteDataSource {
  static const _table = 'casos_monitoreo';
  static const _caseSelect =
      'id, assessment_id, estado, prioridad, asignado_a, creado_en, municipio, '
      'departamento, nivel_riesgo, descripcion_alerta, cerrado_en, cerrado_por, '
      'resultado, origen, remitido_por, motivo_remision, '
      'assessments(patient_id, nombre_paciente, semanas_gestacion, edad_materna), '
      'profiles!casos_monitoreo_remitido_por_fkey(full_name)';

  final SupabaseClient? client;
  final CaseRpcClient? rpcClient;
  final StreamController<MonitoringCaseChange> _changes =
      StreamController<MonitoringCaseChange>.broadcast();

  RealtimeChannel? _channel;

  SupabaseCaseRemoteDataSource({required this.client, this.rpcClient});

  @override
  Stream<MonitoringCaseChange> get changes => _changes.stream;

  @override
  Future<void> takeCase(String caseId) =>
      _runAction('tomar_caso', {'p_caso_id': caseId});

  @override
  Future<void> releaseCase(String caseId) =>
      _runAction('liberar_caso', {'p_caso_id': caseId});

  @override
  Future<void> registerEvent({
    required String caseId,
    required String type,
    String? note,
    String? centerId,
  }) => _runAction('registrar_evento_caso', {
    'p_caso_id': caseId,
    'p_tipo': type,
    'p_nota': note,
    'p_centro_id': centerId,
  });

  @override
  Future<void> closeCase({
    required String caseId,
    required String result,
    String? note,
  }) => _runAction('cerrar_caso', {
    'p_caso_id': caseId,
    'p_resultado': result,
    'p_nota': note,
  });

  @override
  Future<List<MonitoringCase>> fetchCases({
    required MonitoringCaseStatus status,
    String? assignedTo,
    String? closedBy,
    required int offset,
    int limit = 50,
  }) async {
    if (closedBy != null) {
      final rows = await _requireClient()
          .from(_table)
          .select(_caseSelect)
          .eq('estado', status.value)
          .eq('cerrado_por', closedBy)
          .order('cerrado_en', ascending: false)
          .range(offset, offset + limit - 1);
      return rows.map(MonitoringCase.fromJson).toList(growable: false);
    }

    final priorities = MonitoringPriority.values;
    final counts = await Future.wait(
      priorities.map(
        (priority) => _fetchPriorityCount(
          status: status,
          priority: priority,
          assignedTo: assignedTo,
        ),
      ),
    );
    var remainingOffset = offset;
    var remainingLimit = limit;
    final rows = <Map<String, dynamic>>[];
    for (
      var index = 0;
      index < priorities.length && remainingLimit > 0;
      index++
    ) {
      final count = counts[index];
      if (remainingOffset >= count) {
        remainingOffset -= count;
        continue;
      }
      final start = remainingOffset;
      final available = count - start;
      final take = available < remainingLimit ? available : remainingLimit;
      var query = _requireClient()
          .from(_table)
          .select(_caseSelect)
          .eq('estado', status.value)
          .eq('prioridad', priorities[index].value);
      if (assignedTo != null) {
        query = query.eq('asignado_a', assignedTo);
      }
      rows.addAll(
        await query
            .order('creado_en', ascending: true)
            .range(start, start + take - 1),
      );
      remainingLimit -= take;
      remainingOffset = 0;
    }

    return rows.map(MonitoringCase.fromJson).toList(growable: false);
  }

  Future<int> _fetchPriorityCount({
    required MonitoringCaseStatus status,
    required MonitoringPriority priority,
    String? assignedTo,
  }) async {
    var query = _requireClient()
        .from(_table)
        .select('id')
        .eq('estado', status.value)
        .eq('prioridad', priority.value);
    if (assignedTo != null) {
      query = query.eq('asignado_a', assignedTo);
    }
    return (await query.count(CountOption.exact)).count;
  }

  @override
  Future<int> fetchNewCasesCount() async {
    final response = await _requireClient()
        .from(_table)
        .select('id')
        .eq('estado', MonitoringCaseStatus.nuevo.value)
        .count(CountOption.exact);
    return response.count;
  }

  @override
  Future<MonitoringCase?> fetchCaseById(String caseId) async {
    final row = await _requireClient()
        .from(_table)
        .select(_caseSelect)
        .eq('id', caseId)
        .maybeSingle();
    return row == null
        ? null
        : MonitoringCase.fromJson(Map<String, dynamic>.from(row));
  }

  @override
  Future<void> startRealtime({
    required void Function(bool connected) onConnectionChanged,
  }) async {
    if (_channel != null) return;
    final channel = _requireClient()
        .channel('public:$_table')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: _table,
          callback: _handleRealtimeChange,
        );
    _channel = channel;
    channel.subscribe((status, _) {
      onConnectionChanged(status == RealtimeSubscribeStatus.subscribed);
    });
  }

  void _handleRealtimeChange(PostgresChangePayload payload) {
    final isDelete = payload.eventType == PostgresChangeEvent.delete;
    final record = isDelete ? payload.oldRecord : payload.newRecord;
    final caseId = record['id'];
    if (caseId is! String || caseId.isEmpty) return;
    _changes.add(
      MonitoringCaseChange(
        type: switch (payload.eventType) {
          PostgresChangeEvent.insert => MonitoringChangeType.insert,
          PostgresChangeEvent.update => MonitoringChangeType.update,
          PostgresChangeEvent.delete => MonitoringChangeType.delete,
          _ => MonitoringChangeType.update,
        },
        caseId: caseId,
        current: isDelete ? null : MonitoringCase.fromJson(record),
        previousState: payload.eventType == PostgresChangeEvent.update
            ? payload.oldRecord['estado'] as String?
            : null,
      ),
    );
  }

  @override
  Future<void> stopRealtime() async {
    final channel = _channel;
    if (channel == null) return;
    _channel = null;
    await _requireClient().removeChannel(channel);
  }

  Future<void> _runAction(String function, Map<String, dynamic> params) async {
    final rpc = rpcClient ?? SupabaseCaseRpcClient(_requireClient());
    final response = await rpc.call(function, params: params);
    if (response is! Map) {
      throw StateError('La respuesta de $function no tiene un formato válido.');
    }
    final result = Map<String, dynamic>.from(response);
    if (result['ok'] == true) return;
    if (result['ok'] != false) {
      throw StateError('La respuesta de $function no tiene un formato válido.');
    }

    final reason = result['motivo'];
    final motive = reason is String ? reason : '';
    throw MonitoringActionException(motive, _messageForMotive(motive));
  }

  static String _messageForMotive(String motive) => switch (motive) {
    'ya_tomado' => 'Otro monitor ya tomó este caso',
    'estado_invalido' => 'El caso cambió de estado; actualice la lista',
    'no_autorizado' => 'No tiene permiso para esta acción',
    'no_encontrado' => 'No se encontró el caso; actualice la lista',
    'nota_larga' => 'La nota supera 1000 caracteres',
    'nota_vacia' => 'La nota no puede estar vacía',
    'tipo_invalido' => 'El tipo de evento no es válido',
    'centro_requerido' => 'Seleccione un centro para registrar la remisión',
    'resultado_invalido' => 'El resultado del cierre no es válido',
    _ =>
      'No se pudo completar la acción; actualice la lista e intente de nuevo',
  };

  SupabaseClient _requireClient() {
    final supabase = client;
    if (supabase == null) {
      throw StateError('Supabase no está disponible para consultar alertas.');
    }
    return supabase;
  }
}
