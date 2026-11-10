import '../../../../core/database/database_helper.dart';
import '../../domain/entities/patient_assessment.dart';
import '../../domain/entities/triage_result.dart';

class AssessmentLocalDataSource {
  final DatabaseHelper dbHelper;

  AssessmentLocalDataSource({DatabaseHelper? dbHelper})
      : dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<int> insertAssessment({
    required PatientAssessment patient,
    required TriageResult result,
  }) async {
    final db = await dbHelper.database;
    final row = patient.toMap();
    
    // Add triage result fields
    row['nivel_riesgo_predicho'] = result.riskLabel;
    row['probabilidad_riesgo_alto'] = result.probAlto;
    row['alerta_clinica_inmediata'] = result.hasImmediateEmergency ? 1 : 0;
    row['descripcion_alerta'] = result.clinicalAlerts.isNotEmpty
        ? result.clinicalAlerts.map((a) => a.title).join(' | ')
        : null;
    row['probabilidad_desenlace_adverso'] = result.probDesenlaceAdverso;
    row['sincronizado'] = 0;

    return await db.insert('assessments', row);
  }

  Future<List<Map<String, dynamic>>> getAssessments() async {
    final db = await dbHelper.database;
    return await db.query('assessments', orderBy: 'fecha_evaluacion DESC');
  }

  Future<int> getUnsyncedCount() async {
    final db = await dbHelper.database;
    final res = await db.rawQuery(
      'SELECT COUNT(*) as count FROM assessments WHERE sincronizado = 0',
    );
    return res.first['count'] as int? ?? 0;
  }
}
