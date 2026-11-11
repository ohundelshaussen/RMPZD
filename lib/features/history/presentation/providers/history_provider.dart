import 'package:flutter/foundation.dart';
import '../../../triage/domain/entities/assessment_record.dart';
import '../../../triage/domain/usecases/get_assessment_history_usecase.dart';
import '../../../triage/domain/usecases/get_unsynced_count_usecase.dart';

class HistoryProvider extends ChangeNotifier {
  final GetAssessmentHistoryUseCase _getAssessmentHistory;
  final GetUnsyncedCountUseCase _getUnsyncedCount;

  HistoryProvider({
    required this._getAssessmentHistory,
    required this._getUnsyncedCount,
  });

  List<AssessmentRecord> _history = [];
  List<AssessmentRecord> get history => _history;

  int _unsyncedCount = 0;
  int get unsyncedCount => _unsyncedCount;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> loadHistory() async {
    try {
      _history = await _getAssessmentHistory.execute();
      _unsyncedCount = await _getUnsyncedCount.execute();
      _errorMessage = null;
      notifyListeners();
    } catch (error) {
      _errorMessage = 'Error al cargar historial: $error';
      notifyListeners();
    }
  }
}
