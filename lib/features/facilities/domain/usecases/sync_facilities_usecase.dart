import '../repositories/facility_repository.dart';

class SyncFacilitiesUseCase {
  final FacilityRepository repository;

  const SyncFacilitiesUseCase(this.repository);

  Future<int> execute() => repository.syncFacilities();
}
