import 'package:flutter/foundation.dart';

import '../../domain/entities/health_facility.dart';
import '../../domain/usecases/get_facility_catalog_status_usecase.dart';
import '../../domain/usecases/get_nearest_facilities_usecase.dart';

class NearestFacilitiesProvider extends ChangeNotifier {
  final GetNearestFacilitiesUseCase getNearestFacilities;
  final GetFacilityCatalogStatusUseCase getCatalogStatus;
  final Future<bool> Function() checkInternet;

  List<HealthFacility> _facilities = const [];
  List<HealthFacility> get facilities => _facilities;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _catalogStatusLoaded = false;
  bool get catalogStatusLoaded => _catalogStatusLoaded;

  bool _catalogAvailable = false;
  bool get catalogAvailable => _catalogAvailable;

  bool _isOnline = false;
  bool get isOnline => _isOnline;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  NearestFacilitiesProvider({
    required this.getNearestFacilities,
    required this.getCatalogStatus,
    required this.checkInternet,
  });

  Future<void> load({
    double? latitude,
    double? longitude,
    required String? department,
    required String? municipality,
    bool soloObstetricas = false,
    bool soloUrgencias = false,
    bool soloObstetricasOUrgencias = false,
    int limit = 5,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final status = await getCatalogStatus.execute();
      _catalogStatusLoaded = true;
      _catalogAvailable = status.availableCount > 0;
      if (!_catalogAvailable) {
        _facilities = const [];
        return;
      }

      try {
        _isOnline = await checkInternet();
      } on Object {
        _isOnline = false;
      }

      _facilities = await getNearestFacilities.execute(
        latitude,
        longitude,
        limite: limit,
        soloObstetricas: soloObstetricas,
        soloUrgencias: soloUrgencias,
        soloObstetricasOUrgencias: soloObstetricasOUrgencias,
        departamento: department,
        municipio: municipality,
      );
    } on Object {
      _errorMessage = 'No se pudieron cargar los centros cercanos.';
      _facilities = const [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> refreshConnectivity() async {
    try {
      _isOnline = await checkInternet();
    } on Object {
      _isOnline = false;
    }
    notifyListeners();
    return _isOnline;
  }
}
