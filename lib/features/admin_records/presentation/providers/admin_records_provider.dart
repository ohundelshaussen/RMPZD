import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../../core/constants/colombia_locations.dart';
import '../../../../core/constants/form_options.dart';
import '../../../../core/network/connectivity_service.dart';
import '../../domain/entities/remote_assessment.dart';
import '../../domain/repositories/admin_records_repository.dart';
import '../../domain/usecases/get_admin_assessments_usecase.dart';

class AdminRecordsProvider extends ChangeNotifier {
  static const int pageSize = 30;
  static const Set<String> _baseRiskLevels = {
    'Bajo Riesgo',
    'Riesgo Moderado',
    'Alto Riesgo Obstétrico',
  };

  final GetAdminAssessmentsUseCase getAssessments;
  final ConnectivityService connectivityService;

  AdminRecordsProvider({
    required this.getAssessments,
    required this.connectivityService,
  });

  final List<RemoteAssessment> _records = [];
  List<RemoteAssessment> get records => List.unmodifiable(_records);

  final Set<String> _knownRiskLevels = {..._baseRiskLevels};
  final Set<String> _knownDepartments = {...colombiaDepartments};
  final Set<String> _knownMunicipalities = {
    for (final list in municipalitiesByDepartment.values) ...list,
  };
  final Set<String> _knownEthnicities = {...ethnicities};
  final Map<String, String> _knownDoctors = {};

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

  Set<String> get riskLevels => {
    ..._knownRiskLevels,
    for (final record in _records) ?record.riskLevel,
    ?_filters.riskLevel,
  };

  Set<String> get departments => {
    ..._knownDepartments,
    for (final record in _records) ?record.department,
    ?_filters.department,
  };

  Set<String> get municipalities => {
    ..._knownMunicipalities,
    for (final record in _records) ?record.municipality,
  };

  Set<String> get ethnicGroups => {..._knownEthnicities};

  Map<String, String> get doctors {
    final result = <String, String>{..._knownDoctors};
    for (final record in _records) {
      final id = record.doctorId;
      final name = record.doctorName;
      if (id != null && name != null) result[id] = name;
    }
    if (_filters.doctorId case final selectedId?) {
      result.putIfAbsent(selectedId, () => selectedId);
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
      for (final record in page) {
        if (record.riskLevel case final risk? when risk.trim().isNotEmpty) {
          _knownRiskLevels.add(risk);
        }
        if (record.department case final dept? when dept.trim().isNotEmpty) {
          _knownDepartments.add(dept);
        }
        if (record.municipality case final muni? when muni.trim().isNotEmpty) {
          _knownMunicipalities.add(muni);
        }
        final id = record.doctorId;
        final name = record.doctorName;
        if (id != null && name != null) {
          _knownDoctors[id] = name;
        }
      }
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
