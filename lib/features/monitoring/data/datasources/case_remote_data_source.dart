import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/monitoring_case.dart';

abstract interface class CaseRemoteDataSource {
  Stream<MonitoringCaseChange> get changes;

  Future<List<MonitoringCase>> fetchCases({
    required MonitoringCaseStatus status,
    String? assignedTo,
    String? closedBy,
    required int offset,
    int limit = 50,
  });

  Future<int> fetchNewCasesCount();

  Future<void> startRealtime({
    required void Function(bool connected) onConnectionChanged,
  });

  Future<void> stopRealtime();
}

class SupabaseCaseRemoteDataSource implements CaseRemoteDataSource {
  static const _table = 'casos_monitoreo';
  static const _caseSelect =
      '*, assessments(patient_id, nombre_paciente, semanas_gestacion, edad_materna)';

  final SupabaseClient? client;
  final StreamController<MonitoringCaseChange> _changes =
      StreamController<MonitoringCaseChange>.broadcast();

  RealtimeChannel? _channel;

  SupabaseCaseRemoteDataSource({required this.client});

  @override
  Stream<MonitoringCaseChange> get changes => _changes.stream;

  @override
  Future<List<MonitoringCase>> fetchCases({
    required MonitoringCaseStatus status,
    String? assignedTo,
    String? closedBy,
    required int offset,
    int limit = 50,
  }) async {
    final query = _requireClient().from(_table).select(_caseSelect);
    final List<Map<String, dynamic>> rows;
    if (closedBy != null) {
      rows = await query
          .eq('estado', status.value)
          .eq('cerrado_por', closedBy)
          .order('cerrado_en', ascending: false)
          .range(offset, offset + limit - 1);
    } else if (assignedTo != null) {
      rows = await query
          .eq('estado', status.value)
          .eq('asignado_a', assignedTo)
          .order('prioridad', ascending: false)
          .order('creado_en', ascending: true)
          .range(offset, offset + limit - 1);
    } else {
      rows = await query
          .eq('estado', status.value)
          .order('prioridad', ascending: false)
          .order('creado_en', ascending: true)
          .range(offset, offset + limit - 1);
    }

    return rows.map(MonitoringCase.fromJson).toList(growable: false);
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

  SupabaseClient _requireClient() {
    final supabase = client;
    if (supabase == null) {
      throw StateError('Supabase no está disponible para consultar alertas.');
    }
    return supabase;
  }
}
