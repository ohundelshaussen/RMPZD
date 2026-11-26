import '../../data/datasources/doctor_monitoring_remote_data_source.dart';
import '../entities/doctor_monitoring_case.dart';

class GetDoctorMonitoringCasesUseCase {
  final DoctorMonitoringRemoteDataSource remoteDataSource;

  const GetDoctorMonitoringCasesUseCase(this.remoteDataSource);

  Future<Map<String, DoctorMonitoringCase>> execute(
    List<String> assessmentIds,
  ) => remoteDataSource.fetchCaseStatuses(assessmentIds);
}
