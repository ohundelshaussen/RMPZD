import 'package:flutter/foundation.dart';

import '../../domain/entities/health_facility.dart';
import '../../domain/usecases/get_facility_catalog_status_usecase.dart';
import '../../domain/usecases/get_nearest_facilities_usecase.dart';
import '../../domain/usecases/sync_facilities_usecase.dart';

enum FacilitySyncState { loading, idle, syncing, error }

class FacilityProvider extends ChangeNotifier {
  static const catalogUnavailableMessage =
      'Catálogo de centros no disponible; conéctese a internet para descargarlo';

  final SyncFacilitiesUseCase syncFacilities;
  final GetFacilityCatalogStatusUseCase getCatalogStatus;
  final GetNearestFacilitiesUseCase getNearestFacilities;

  FacilitySyncState _state = FacilitySyncState.loading;
  FacilitySyncState get state => _state;
  bool get isSyncing => _state == FacilitySyncState.syncing;

  int _availableCount = 0;
  int get availableCount => _availableCount;

  DateTime? _lastUpdatedAt;
  DateTime? get lastUpdatedAt => _lastUpdatedAt;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  FacilityProvider({
    required this.syncFacilities,
    required this.getCatalogStatus,
    required this.getNearestFacilities,
  });

  Future<void> refreshCatalogStatus() async {
    try {
      final status = await getCatalogStatus.execute();
      _availableCount = status.availableCount;
      _lastUpdatedAt = status.lastUpdatedAt;
      _errorMessage = null;
      if (_state == FacilitySyncState.loading) {
        _state = FacilitySyncState.idle;
      }
    } on Object {
      _errorMessage = 'No se pudo consultar el catálogo de centros.';
      if (_state != FacilitySyncState.syncing) {
        _state = FacilitySyncState.error;
      }
    }
    notifyListeners();
  }

  Future<void> sync() async {
    if (isSyncing) return;
    _state = FacilitySyncState.syncing;
    _errorMessage = null;
    notifyListeners();

    try {
      await syncFacilities.execute();
      final status = await getCatalogStatus.execute();
      _availableCount = status.availableCount;
      _lastUpdatedAt = status.lastUpdatedAt;
      _state = FacilitySyncState.idle;
    } on Object {
      _errorMessage = 'No se pudo actualizar el catálogo de centros.';
      _state = FacilitySyncState.error;
    }
    notifyListeners();
  }

  Future<List<HealthFacility>> findNearest({
    double? latitude,
    double? longitude,
    int limit = 5,
    bool soloObstetricas = false,
    bool soloUrgencias = false,
    bool soloObstetricasOUrgencias = false,
    String? departamento,
    String? municipio,
  }) {
    return getNearestFacilities.execute(
      latitude,
      longitude,
      limite: limit,
      soloObstetricas: soloObstetricas,
      soloUrgencias: soloUrgencias,
      soloObstetricasOUrgencias: soloObstetricasOUrgencias,
      departamento: departamento,
      municipio: municipio,
    );
  }
}
