import '../entities/facility_catalog_status.dart';
import '../repositories/facility_repository.dart';

class GetFacilityCatalogStatusUseCase {
  final FacilityRepository repository;

  const GetFacilityCatalogStatusUseCase(this.repository);

  Future<FacilityCatalogStatus> execute() => repository.getCatalogStatus();
}
