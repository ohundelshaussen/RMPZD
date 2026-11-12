import 'dart:async';

import 'package:flutter/foundation.dart';
import '../../domain/entities/patient_assessment.dart';
import '../../domain/entities/triage_result.dart';
import '../../domain/usecases/evaluate_maternal_risk_usecase.dart';
import '../../domain/usecases/save_assessment_usecase.dart';

class TriageProvider extends ChangeNotifier {
  final EvaluateMaternalRiskUseCase _evaluateMaternalRisk;
  final SaveAssessmentUseCase _saveAssessment;
  final String? Function() currentOwnerId;
  final Future<void> Function()? onAssessmentSaved;

  TriageProvider({
    required this._evaluateMaternalRisk,
    required this._saveAssessment,
    required this.currentOwnerId,
    this.onAssessmentSaved,
  });

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  PatientAssessment? _currentPatient;
  PatientAssessment? get currentPatient => _currentPatient;

  TriageResult? _currentResult;
  TriageResult? get currentResult => _currentResult;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> evaluate(PatientAssessment patient) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentPatient = patient;
      _currentResult = await _evaluateMaternalRisk.execute(patient);
    } catch (e) {
      _errorMessage = 'Error al evaluar paciente: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> saveCurrentAssessment() async {
    if (_currentPatient == null || _currentResult == null) return false;
    final ownerId = currentOwnerId();
    if (ownerId == null) {
      _errorMessage = 'Inicie sesión para guardar esta evaluación.';
      notifyListeners();
      return false;
    }

    try {
      await _saveAssessment.execute(
        _currentPatient!,
        _currentResult!,
        ownerId: ownerId,
      );
      final savedCallback = onAssessmentSaved;
      if (savedCallback != null) unawaited(savedCallback());
      return true;
    } catch (e) {
      _errorMessage = 'Error al guardar en base local: $e';
      notifyListeners();
      return false;
    }
  }
}
