import '../entities/health_facility.dart';
import '../repositories/facility_repository.dart';

class GetNearestFacilitiesUseCase {
  final FacilityRepository repository;

  const GetNearestFacilitiesUseCase(this.repository);

  Future<List<HealthFacility>> execute(
    double? latitude,
    double? longitude, {
    int limite = 5,
    bool soloObstetricas = false,
    bool soloUrgencias = false,
    bool soloObstetricasOUrgencias = false,
    String? departamento,
    String? municipio,
  }) {
    return repository.getNearestFacilities(
      latitude,
      longitude,
      limit: limite,
      soloObstetricas: soloObstetricas,
      soloUrgencias: soloUrgencias,
      soloObstetricasOUrgencias: soloObstetricasOUrgencias,
      departamento: departamento,
      municipio: municipio,
    );
  }
}
