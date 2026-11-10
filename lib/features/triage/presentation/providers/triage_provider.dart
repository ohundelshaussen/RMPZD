import 'package:flutter/foundation.dart';
import '../../domain/entities/patient_assessment.dart';
import '../../domain/entities/triage_result.dart';
import '../../domain/repositories/assessment_repository.dart';
import '../../data/repositories/assessment_repository_impl.dart';

class TriageProvider extends ChangeNotifier {
  final AssessmentRepository _repository;

  TriageProvider({AssessmentRepository? repository})
      : _repository = repository ?? AssessmentRepositoryImpl();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  PatientAssessment? _currentPatient;
  PatientAssessment? get currentPatient => _currentPatient;

  TriageResult? _currentResult;
  TriageResult? get currentResult => _currentResult;

  List<Map<String, dynamic>> _history = [];
  List<Map<String, dynamic>> get history => _history;

  int _unsyncedCount = 0;
  int get unsyncedCount => _unsyncedCount;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> evaluate(PatientAssessment patient) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentPatient = patient;
      _currentResult = await _repository.evaluateRisk(patient);
    } catch (e) {
      _errorMessage = 'Error al evaluar paciente: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> saveCurrentAssessment() async {
    if (_currentPatient == null || _currentResult == null) return false;

    try {
      await _repository.saveAssessment(_currentPatient!, _currentResult!);
      await loadHistory();
      return true;
    } catch (e) {
      _errorMessage = 'Error al guardar en base local: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> loadHistory() async {
    try {
      _history = await _repository.getHistory();
      _unsyncedCount = await _repository.getUnsyncedCount();
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error al cargar historial: $e';
      notifyListeners();
    }
  }
}
