import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../../core/network/connectivity_service.dart';
import '../../domain/entities/remote_assessment.dart';
import '../../domain/repositories/admin_records_repository.dart';
import '../../domain/usecases/get_admin_assessments_usecase.dart';

class AdminRecordsProvider extends ChangeNotifier {
  static const int pageSize = 30;

  final GetAdminAssessmentsUseCase getAssessments;
  final ConnectivityService connectivityService;

  AdminRecordsProvider({
    required this.getAssessments,
    required this.connectivityService,
  });

  final List<RemoteAssessment> _records = [];
  List<RemoteAssessment> get records => List.unmodifiable(_records);

  AdminAssessmentFilters _filters = const AdminAssessmentFilters();
  AdminAssessmentFilters get filters => _filters;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _isOffline = false;
  bool get isOffline => _isOffline;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _hasMore = true;
  bool get hasMore => _hasMore;

  Set<String> get riskLevels => _records
      .map((record) => record.riskLevel)
      .whereType<String>()
      .toSet();

  Set<String> get departments => _records
      .map((record) => record.department)
      .whereType<String>()
      .toSet();

  Map<String, String> get doctors {
    final result = <String, String>{};
    for (final record in _records) {
      final id = record.doctorId;
      final name = record.doctorName;
      if (id != null && name != null) result[id] = name;
    }
    return result;
  }

  Future<void> loadInitial() async {
    _records.clear();
    _hasMore = true;
    await _loadPage(resetError: true);
  }

  Future<void> loadMore() async {
    if (!_hasMore || _isLoading || _errorMessage != null) return;
    await _loadPage();
  }

  Future<void> retry() => loadInitial();

  Future<void> setFilters(AdminAssessmentFilters filters) async {
    _filters = filters;
    await loadInitial();
  }

  Future<void> _loadPage({bool resetError = false}) async {
    if (_isLoading) return;
    _isLoading = true;
    if (resetError) {
      _errorMessage = null;
      _isOffline = false;
    }
    notifyListeners();

    try {
      if (!await connectivityService.hasInternet()) {
        _isOffline = true;
        _errorMessage = 'Sin conexión a internet. Conéctate y vuelve a intentar.';
        return;
      }
      final page = await getAssessments.execute(
        offset: _records.length,
        limit: pageSize,
        filters: _filters,
      );
      _records.addAll(page);
      _hasMore = page.length == pageSize;
      _errorMessage = null;
      _isOffline = false;
    } catch (error) {
      _isOffline = error is SocketException || error is TimeoutException;
      _errorMessage = _isOffline
          ? 'Sin conexión a internet. Conéctate y vuelve a intentar.'
          : 'No se pudieron cargar los registros: $error';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
