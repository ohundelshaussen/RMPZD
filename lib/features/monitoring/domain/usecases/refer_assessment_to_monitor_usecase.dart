import '../../data/datasources/doctor_monitoring_remote_data_source.dart';
import '../entities/doctor_monitoring_case.dart';

class ReferAssessmentToMonitorUseCase {
  final DoctorMonitoringRemoteDataSource remoteDataSource;

  const ReferAssessmentToMonitorUseCase(this.remoteDataSource);

  Future<DoctorReferralResult> execute({
    required String assessmentId,
    required String motive,
  }) => remoteDataSource.referAssessment(assessmentId, motive);
}
