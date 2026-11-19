import 'dart:async';

import 'package:flutter/foundation.dart';
import '../../domain/entities/patient_assessment.dart';
import '../../domain/entities/triage_result.dart';
import '../../domain/entities/assessment_record.dart';
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

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  PatientAssessment? _currentPatient;
  PatientAssessment? get currentPatient => _currentPatient;

  TriageResult? _currentResult;
  TriageResult? get currentResult => _currentResult;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  AssessmentRecord? _savedAssessment;
  AssessmentRecord? get savedAssessment => _savedAssessment;
  bool get isSaved => _savedAssessment != null;

  Future<void> evaluate(PatientAssessment patient) async {
    _isLoading = true;
    _isSaving = false;
    _errorMessage = null;
    _savedAssessment = null;
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
    if (_isSaving) return false;
    if (_savedAssessment != null) return true;
    if (_currentPatient == null || _currentResult == null) return false;
    final ownerId = currentOwnerId();
    if (ownerId == null) {
      _errorMessage = 'Inicie sesión para guardar esta evaluación.';
      notifyListeners();
      return false;
    }

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _savedAssessment = await _saveAssessment.execute(
        _currentPatient!,
        _currentResult!,
        ownerId: ownerId,
      );
      final savedCallback = onAssessmentSaved;
      if (savedCallback != null) unawaited(savedCallback());
      return true;
    } catch (e) {
      _errorMessage = 'Error al guardar en base local: $e';
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  void reset() {
    _isLoading = false;
    _isSaving = false;
    _currentPatient = null;
    _currentResult = null;
    _savedAssessment = null;
    _errorMessage = null;
    notifyListeners();
  }
}
