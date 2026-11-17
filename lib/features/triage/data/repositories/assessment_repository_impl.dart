import '../../domain/entities/assessment_record.dart';
import '../../domain/entities/patient_assessment.dart';
import '../../domain/entities/triage_result.dart';
import '../../domain/repositories/assessment_repository.dart';
import '../datasources/assessment_local_datasource.dart';
import '../models/assessment_model.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/utils/consultation_code_generator.dart';

class AssessmentRepositoryImpl implements AssessmentRepository {
  final AssessmentLocalDataSource localDataSource;

  AssessmentRepositoryImpl({required this.localDataSource});

  @override
  Future<AssessmentRecord> saveAssessment(
    PatientAssessment patient,
    TriageResult result, {
    required String ownerId,
  }) async {
    final assessment = AssessmentModel(
      record: AssessmentRecord(
        patient: patient,
        result: result,
        uuid: const Uuid().v4(),
        ownerId: ownerId,
        consultationCode: ConsultationCodeGenerator().generate(),
        fechaGuardado: patient.fechaEvaluacion,
      ),
    );
    final savedAssessment = await localDataSource.insertAssessment(
      assessment,
      ownerId: ownerId,
    );
    return savedAssessment.record;
  }

  @override
  Future<List<AssessmentRecord>> getHistory({required String ownerId}) async {
    final assessments = await localDataSource.getAssessments(ownerId);
    return assessments.map((assessment) => assessment.record).toList();
  }

  @override
  Future<int> getUnsyncedCount({required String ownerId}) async {
    return await localDataSource.getUnsyncedCount(ownerId);
  }
}
