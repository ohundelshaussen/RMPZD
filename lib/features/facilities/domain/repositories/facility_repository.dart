import '../entities/facility_catalog_status.dart';
import '../entities/health_facility.dart';

abstract interface class FacilityRepository {
  Future<int> syncFacilities();

  Future<FacilityCatalogStatus> getCatalogStatus();

  Future<List<HealthFacility>> getNearestFacilities(
    double? latitude,
    double? longitude, {
    int limit = 5,
    bool soloObstetricas = false,
    bool soloUrgencias = false,
    bool soloObstetricasOUrgencias = false,
    String? departamento,
    String? municipio,
  });
}
