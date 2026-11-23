import 'dart:async';

import 'package:flutter/foundation.dart';
import '../../../triage/data/datasources/assessment_remote_datasource.dart';
import '../../../triage/data/models/assessment_model.dart';
import '../../../triage/domain/entities/assessment_record.dart';
import '../../../triage/domain/entities/patient_assessment.dart';
import '../../../triage/domain/usecases/delete_assessment_usecase.dart';
import '../../../triage/domain/usecases/evaluate_maternal_risk_usecase.dart';
import '../../../triage/domain/usecases/get_assessment_history_usecase.dart';
import '../../../triage/domain/usecases/get_unsynced_count_usecase.dart';
import '../../../triage/domain/usecases/update_assessment_usecase.dart';

class HistoryProvider extends ChangeNotifier {
  final GetAssessmentHistoryUseCase _getAssessmentHistory;
  final GetUnsyncedCountUseCase _getUnsyncedCount;
  final String? Function() currentOwnerId;
  final EvaluateMaternalRiskUseCase? evaluateMaternalRisk;
  final UpdateAssessmentUseCase? updateAssessment;
  final DeleteAssessmentUseCase? deleteAssessment;
  final AssessmentRemoteDataSource? remoteDataSource;
  final Future<void> Function()? onHistoryMutated;

  HistoryProvider({
    required this._getAssessmentHistory,
    required this._getUnsyncedCount,
    required this.currentOwnerId,
    this.evaluateMaternalRisk,
    this.updateAssessment,
    this.deleteAssessment,
    this.remoteDataSource,
    this.onHistoryMutated,
  });

  List<AssessmentRecord> _history = [];
  List<AssessmentRecord> get history => _history;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  String? _riskFilter;
  String? get riskFilter => _riskFilter;

  bool _onlyPending = false;
  bool get onlyPending => _onlyPending;

  bool get hasActiveFilters =>
      _searchQuery.trim().isNotEmpty || _riskFilter != null || _onlyPending;

  List<AssessmentRecord> get filteredHistory {
    final query = _searchQuery.trim().toLowerCase();
    return _history.where((record) {
      if (_onlyPending && record.isSynced) return false;
      if (_riskFilter != null) {
        final label = record.result.riskLabel.toLowerCase();
        final matches = switch (_riskFilter) {
          'Alto' => record.result.hasImmediateEmergency || label.contains('alto'),
          'Medio' =>
            !record.result.hasImmediateEmergency &&
                (label.contains('medio') || label.contains('moderado')),
          'Bajo' =>
            !record.result.hasImmediateEmergency && label.contains('bajo'),
          _ => true,
        };
        if (!matches) return false;
      }
      if (query.isNotEmpty) {
        final patientId = record.patient.patientId.toLowerCase();
        final patientName = (record.patient.nombrePaciente ?? '').toLowerCase();
        final municipality = record.patient.municipio.toLowerCase();
        final owner = (record.ownerId ?? '').toLowerCase();
        final normalizedQueryCode = query.replaceAll(RegExp(r'[-\s]'), '');
        final rawCode = (record.consultationCode ?? '')
            .replaceAll(RegExp(r'[-\s]'), '')
            .toLowerCase();
        final matchesCode =
            normalizedQueryCode.isNotEmpty &&
            rawCode.contains(normalizedQueryCode);
        if (!patientId.contains(query) &&
            !patientName.contains(query) &&
            !municipality.contains(query) &&
            !owner.contains(query) &&
            !matchesCode) {
          return false;
        }
      }
      return true;
    }).toList(growable: false);
  }

  int _unsyncedCount = 0;
  int get unsyncedCount => _unsyncedCount;

  bool _isMutating = false;
  bool get isMutating => _isMutating;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    notifyListeners();
  }

  void setRiskFilter(String? risk) {
    if (_riskFilter == risk) return;
    _riskFilter = risk;
    notifyListeners();
  }

  void setOnlyPending(bool value) {
    if (_onlyPending == value) return;
    _onlyPending = value;
    notifyListeners();
  }

  void clearFilters() {
    if (!hasActiveFilters) return;
    _searchQuery = '';
    _riskFilter = null;
    _onlyPending = false;
    notifyListeners();
  }

  Future<void> loadHistory() async {
    try {
      final ownerId = currentOwnerId();
      if (ownerId == null) {
        _history = [];
        _unsyncedCount = 0;
        notifyListeners();
        return;
      }
      _history = await _getAssessmentHistory.execute(ownerId: ownerId);
      _unsyncedCount = await _getUnsyncedCount.execute(ownerId: ownerId);
      _errorMessage = null;
      notifyListeners();
    } catch (error) {
      _errorMessage = 'Error al cargar historial: $error';
      notifyListeners();
    }
  }

  Future<({bool success, String message})> editRecord(
    AssessmentRecord record,
    PatientAssessment updatedPatient,
  ) async {
    final evaluator = evaluateMaternalRisk;
    final updater = updateAssessment;
    if (evaluator == null || updater == null) {
      return (
        success: false,
        message: 'La edición de evaluaciones no está configurada.',
      );
    }

    _isMutating = true;
    notifyListeners();
    try {
      final newResult = await evaluator.execute(updatedPatient);
      if (record.isSynced) {
        final remote = remoteDataSource;
        if (remote == null) {
          return (
            success: false,
            message:
                'No hay conexión configurada para actualizar un registro ya sincronizado.',
          );
        }
        final consentAt = updatedPatient.consentimientoDatos
            ? (record.consentimientoAt ?? DateTime.now().toUtc())
            : null;
        final remoteCandidate = AssessmentModel(
          record: AssessmentRecord(
            patient: updatedPatient,
            result: newResult,
            idLocal: record.idLocal,
            uuid: record.uuid,
            ownerId: record.ownerId,
            syncStatus: SyncStatus.synced,
            consultationCode: record.consultationCode,
            consentimientoAt: consentAt,
            fechaGuardado: record.fechaGuardado,
          ),
        );
        final updatedRemotely = await remote.updateAssessment(
          record.uuid,
          remoteCandidate.toRemoteJson(),
        );
        if (!updatedRemotely) {
          return (
            success: false,
            message:
                'El servidor no permitió editar un registro ya sincronizado (política RLS).',
          );
        }
      }

      await updater.execute(record, updatedPatient, newResult);
      await loadHistory();
      final callback = onHistoryMutated;
      if (callback != null) await callback();
      return (
        success: true,
        message: record.isSynced
            ? 'Evaluación actualizada en el dispositivo y en la nube.'
            : 'Evaluación local actualizada y re-evaluada correctamente.',
      );
    } catch (error) {
      final remote = remoteDataSource;
      if (remote != null && remote.isNetworkFailure(error)) {
        return (
          success: false,
          message:
              'Sin conexión a internet para actualizar un registro sincronizado.',
        );
      }
      return (success: false, message: 'No se pudo actualizar: $error');
    } finally {
      _isMutating = false;
      notifyListeners();
    }
  }

  Future<({bool success, String message})> removeRecord(
    AssessmentRecord record, {
    required bool deleteFromCloud,
  }) async {
    final remover = deleteAssessment;
    if (remover == null) {
      return (
        success: false,
        message: 'La eliminación de evaluaciones no está configurada.',
      );
    }

    _isMutating = true;
    notifyListeners();
    try {
      if (record.isSynced && deleteFromCloud) {
        final remote = remoteDataSource;
        if (remote == null) {
          return (
            success: false,
            message: 'No hay cliente remoto disponible para borrar de la nube.',
          );
        }
        final deletedRemotely = await remote.deleteAssessment(record.uuid);
        if (!deletedRemotely) {
          return (
            success: false,
            message:
                'El servidor no autoriza eliminar registros sincronizados (política RLS). Puede eliminar solo la copia local.',
          );
        }
      }

      await remover.execute(uuid: record.uuid);
      await loadHistory();
      final callback = onHistoryMutated;
      if (callback != null) await callback();
      return (
        success: true,
        message: (record.isSynced && deleteFromCloud)
            ? 'Evaluación eliminada del dispositivo y de la nube.'
            : 'Evaluación eliminada de este dispositivo.',
      );
    } catch (error) {
      final remote = remoteDataSource;
      if (remote != null && remote.isNetworkFailure(error)) {
        return (
          success: false,
          message:
              'Sin conexión para eliminar en la nube. Intente de nuevo o elimine solo la copia local.',
        );
      }
      return (success: false, message: 'No se pudo eliminar: $error');
    } finally {
      _isMutating = false;
      notifyListeners();
    }
  }
}
