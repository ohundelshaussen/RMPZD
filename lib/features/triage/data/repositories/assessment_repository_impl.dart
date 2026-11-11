import '../../domain/entities/assessment_record.dart';
import '../../domain/entities/patient_assessment.dart';
import '../../domain/entities/triage_result.dart';
import '../../domain/repositories/assessment_repository.dart';
import '../datasources/assessment_local_datasource.dart';
import '../models/assessment_model.dart';

class AssessmentRepositoryImpl implements AssessmentRepository {
  final AssessmentLocalDataSource localDataSource;

  AssessmentRepositoryImpl({required this.localDataSource});

  @override
  Future<int> saveAssessment(
    PatientAssessment patient,
    TriageResult result,
  ) async {
    final assessment = AssessmentModel(
      record: AssessmentRecord(
        patient: patient,
        result: result,
        fechaGuardado: patient.fechaEvaluacion,
      ),
    );
    final savedAssessment = await localDataSource.insertAssessment(assessment);
    return savedAssessment.record.idLocal!;
  }

  @override
  Future<List<AssessmentRecord>> getHistory() async {
    final assessments = await localDataSource.getAssessments();
    return assessments.map((assessment) => assessment.record).toList();
  }

  @override
  Future<int> getUnsyncedCount() async {
    return await localDataSource.getUnsyncedCount();
  }
}
