import '../../../../core/database/database_helper.dart';
import '../../domain/entities/assessment_record.dart';
import '../models/assessment_model.dart';

class AssessmentLocalDataSource {
  final DatabaseHelper dbHelper;

  AssessmentLocalDataSource({required this.dbHelper});

  Future<AssessmentModel> insertAssessment(AssessmentModel assessment) async {
    final db = await dbHelper.database;
    final idLocal = await db.insert('assessments', assessment.toMap());
    final record = assessment.record;
    return AssessmentModel(
      record: AssessmentRecord(
        patient: record.patient,
        result: record.result,
        idLocal: idLocal,
        fechaGuardado: record.fechaGuardado,
        sincronizado: record.sincronizado,
      ),
    );
  }

  Future<List<AssessmentModel>> getAssessments() async {
    final db = await dbHelper.database;
    final rows = await db.query(
      'assessments',
      orderBy: 'fecha_evaluacion DESC',
    );
    return rows
        .map((row) => AssessmentModel.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<int> getUnsyncedCount() async {
    final db = await dbHelper.database;
    final res = await db.rawQuery(
      'SELECT COUNT(*) as count FROM assessments WHERE sincronizado = 0',
    );
    return res.first['count'] as int? ?? 0;
  }
}
