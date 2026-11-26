import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/entities/doctor_monitoring_case.dart';
import '../../domain/usecases/get_doctor_monitoring_cases_usecase.dart';
import '../../domain/usecases/refer_assessment_to_monitor_usecase.dart';

class DoctorReferralProvider extends ChangeNotifier {
  final GetDoctorMonitoringCasesUseCase getMonitoringCases;
  final ReferAssessmentToMonitorUseCase referAssessment;
  final Future<bool> Function() checkInternet;
  final Stream<bool> connectionChanges;

  final Map<String, DoctorMonitoringCase> _casesByAssessment = {};
  final Set<String> _checkedAssessmentIds = {};
  final Set<String> _loadingAssessmentIds = {};
  StreamSubscription<bool>? _connectionSubscription;

  bool _hasInternet = false;
  bool get hasInternet => _hasInternet;

  String? _remittingAssessmentId;
  String? get remittingAssessmentId => _remittingAssessmentId;

  String? _statusErrorMessage;
  String? get statusErrorMessage => _statusErrorMessage;

  DoctorReferralProvider({
    required this.getMonitoringCases,
    required this.referAssessment,
    required this.checkInternet,
    required this.connectionChanges,
  }) {
    _connectionSubscription = connectionChanges.listen(
      _setInternetStatus,
      onError: (Object _) => _setInternetStatus(false),
    );
    unawaited(refreshInternetStatus());
  }

  DoctorMonitoringCase? caseFor(String assessmentId) =>
      _casesByAssessment[assessmentId];

  bool isStatusLoading(String assessmentId) =>
      _loadingAssessmentIds.contains(assessmentId);

  bool hasCheckedStatus(String assessmentId) =>
      _checkedAssessmentIds.contains(assessmentId);

  bool isRemitting(String assessmentId) =>
      _remittingAssessmentId == assessmentId;

  Future<void> refreshInternetStatus() async {
    try {
      _setInternetStatus(await checkInternet());
    } on Object {
      _setInternetStatus(false);
    }
  }

  Future<void> loadStatuses(
    Iterable<String> assessmentIds, {
    bool force = false,
  }) async {
    final requestedIds = assessmentIds
        .where((id) => id.trim().isNotEmpty)
        .toSet();
    if (force) _checkedAssessmentIds.removeAll(requestedIds);
    final ids = requestedIds
        .where(
          (id) =>
              !_checkedAssessmentIds.contains(id) &&
              !_loadingAssessmentIds.contains(id),
        )
        .toList(growable: false);
    if (ids.isEmpty) return;

    _loadingAssessmentIds.addAll(ids);
    notifyListeners();
    try {
      final cases = await getMonitoringCases.execute(ids);
      _casesByAssessment.addAll(cases);
      for (final id in ids) {
        if (!cases.containsKey(id)) _casesByAssessment.remove(id);
      }
      _checkedAssessmentIds.addAll(ids);
      _statusErrorMessage = null;
    } on Object {
      _statusErrorMessage = 'No se pudo consultar el estado de remisión.';
    } finally {
      _loadingAssessmentIds.removeAll(ids);
      notifyListeners();
    }
  }

  Future<DoctorReferralResult> submitReferral({
    required String assessmentId,
    required String motive,
  }) async {
    if (!hasInternet) {
      throw StateError('Requiere conexión a internet.');
    }
    if (_remittingAssessmentId != null) {
      throw StateError('Ya hay una remisión en curso.');
    }
    _remittingAssessmentId = assessmentId;
    notifyListeners();
    try {
      final result = await referAssessment.execute(
        assessmentId: assessmentId,
        motive: motive,
      );
      if (result.ok || result.motive == 'ya_remitido') {
        final state = result.state ?? (result.ok ? 'nuevo' : null);
        if (state != null) {
          _casesByAssessment[assessmentId] = DoctorMonitoringCase(
            state: state,
            result: state == 'cerrado'
                ? _casesByAssessment[assessmentId]?.result
                : null,
            closedAt: state == 'cerrado'
                ? _casesByAssessment[assessmentId]?.closedAt
                : null,
          );
          _checkedAssessmentIds.add(assessmentId);
        }
      }
      return result;
    } finally {
      _remittingAssessmentId = null;
      notifyListeners();
    }
  }

  static String messageFor(DoctorReferralResult result) {
    if (result.ok && result.reopened) {
      return 'El caso estaba cerrado y se reabrió';
    }
    if (result.ok) return 'Paciente remitida al monitor';
    return switch (result.motive) {
      'ya_remitido' => switch (result.state) {
        'nuevo' => 'Ya está remitida y en espera',
        'en_gestion' => 'Ya está remitida y en gestión por un monitor',
        _ => 'La evaluación ya está remitida al monitor',
      },
      'no_autorizado' => 'No tiene permiso para remitir esta evaluación',
      'no_encontrado' =>
        'La evaluación no está en el servidor; sincronícela primero',
      'nota_larga' => 'El motivo no puede superar 500 caracteres',
      _ => 'No se pudo remitir la evaluación; intente de nuevo',
    };
  }

  static String closedResultLabel(String? result) => switch (result) {
    'atendida' => 'atendida',
    'remitida' => 'remitida',
    'no_contactable' => 'no contactable',
    'rechaza_atencion' => 'rechazó la atención',
    'falsa_alarma' => 'falsa alarma',
    'otro' => 'otro',
    _ => result ?? 'sin resultado',
  };

  void _setInternetStatus(bool connected) {
    if (_hasInternet == connected) return;
    _hasInternet = connected;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_connectionSubscription?.cancel());
    super.dispose();
  }
}
