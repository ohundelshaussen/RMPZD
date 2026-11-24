import '../../domain/entities/assessment_record.dart';
import '../../domain/entities/patient_assessment.dart';
import '../../domain/entities/triage_result.dart';
import '../../domain/repositories/assessment_repository.dart';
import '../datasources/assessment_local_datasource.dart';
import '../models/assessment_model.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/utils/consultation_code_generator.dart';
import '../datasources/assessment_remote_datasource.dart';

class AssessmentRepositoryImpl implements AssessmentRepository {
  final AssessmentLocalDataSource localDataSource;
  final AssessmentRemoteDataSource? remoteDataSource;
  final SharedPreferences? preferences;

  AssessmentRepositoryImpl({
    required this.localDataSource,
    this.remoteDataSource,
    this.preferences,
  });

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
        consentimientoAt: patient.consentimientoDatos
            ? DateTime.now().toUtc()
            : null,
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

  @override
  Future<void> updateConsultationCode({
    required String uuid,
    required String code,
  }) {
    return localDataSource.updateConsultationCode(uuid, code);
  }

  @override
  Future<int> pullOwnAssessments({required String ownerId}) async {
    final remote = remoteDataSource;
    final prefs = preferences;
    if (remote == null || prefs == null) {
      throw StateError('La restauración remota no está configurada.');
    }

    const limit = 200;
    final cursorKey = 'own_assessments_pull_cursor_$ownerId';
    final cursor = prefs.getString(cursorKey);
    var offset = 0;
    var restored = 0;
    String? newestCursor = cursor;

    while (true) {
      final rows = await remote.fetchOwnAssessments(
        ownerId,
        updatedAfter: cursor,
        offset: offset,
        limit: limit,
      );
      if (rows.isEmpty) break;

      final models = rows
          .map(AssessmentModel.fromRemoteJson)
          .toList(growable: false);
      restored += await localDataSource.insertPulledIgnoringExisting(models);

      for (final row in rows) {
        final value = row['updated_at'];
        if (value is String) {
          if (newestCursor == null ||
              DateTime.parse(value).isAfter(DateTime.parse(newestCursor))) {
            newestCursor = value;
          }
        }
      }

      if (rows.length < limit) break;
      offset += limit;
    }

    if (newestCursor != cursor) {
      await prefs.setString(cursorKey, newestCursor ?? cursor!);
    }
    return restored;
  }
}
