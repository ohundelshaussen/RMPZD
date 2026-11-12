import 'package:flutter/foundation.dart';
import '../../../triage/domain/entities/assessment_record.dart';
import '../../../triage/domain/usecases/get_assessment_history_usecase.dart';
import '../../../triage/domain/usecases/get_unsynced_count_usecase.dart';

class HistoryProvider extends ChangeNotifier {
  final GetAssessmentHistoryUseCase _getAssessmentHistory;
  final GetUnsyncedCountUseCase _getUnsyncedCount;
  final String? Function() currentOwnerId;

  HistoryProvider({
    required this._getAssessmentHistory,
    required this._getUnsyncedCount,
    required this.currentOwnerId,
  });

  List<AssessmentRecord> _history = [];
  List<AssessmentRecord> get history => _history;

  int _unsyncedCount = 0;
  int get unsyncedCount => _unsyncedCount;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

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
}
