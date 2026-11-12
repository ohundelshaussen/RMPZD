import '../../../../core/database/database_helper.dart';
import '../../domain/entities/assessment_record.dart';
import '../models/assessment_model.dart';

class AssessmentLocalDataSource {
  final DatabaseHelper dbHelper;

  AssessmentLocalDataSource({required this.dbHelper});

  Future<AssessmentModel> insertAssessment(
    AssessmentModel assessment, {
    required String ownerId,
  }) async {
    final db = await dbHelper.database;
    await assignUnownedRecords(ownerId);
    final map = assessment.toMap()..['owner_id'] = ownerId;
    final idLocal = await db.insert('assessments', map);
    final record = assessment.record;
    return AssessmentModel(
      record: AssessmentRecord(
        patient: record.patient,
        result: record.result,
        idLocal: idLocal,
        uuid: record.uuid,
        ownerId: ownerId,
        syncStatus: record.syncStatus,
        lastSyncError: record.lastSyncError,
        fechaGuardado: record.fechaGuardado,
      ),
    );
  }

  Future<List<AssessmentModel>> getAssessments(String ownerId) async {
    final db = await dbHelper.database;
    await assignUnownedRecords(ownerId);
    final rows = await db.query(
      'assessments',
      where: 'owner_id = ?',
      whereArgs: [ownerId],
      orderBy: 'fecha_evaluacion DESC',
    );
    return rows
        .map((row) => AssessmentModel.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<int> getUnsyncedCount(String ownerId) async {
    final db = await dbHelper.database;
    await assignUnownedRecords(ownerId);
    final res = await db.rawQuery(
      "SELECT COUNT(*) as count FROM assessments WHERE owner_id = ? AND sync_status != 'synced'",
      [ownerId],
    );
    return res.first['count'] as int? ?? 0;
  }

  Future<List<AssessmentModel>> getPendingAssessments(String ownerId) async {
    final db = await dbHelper.database;
    await assignUnownedRecords(ownerId);
    final rows = await db.query(
      'assessments',
      where: "owner_id = ? AND sync_status IN ('pending', 'error')",
      whereArgs: [ownerId],
      orderBy: 'fecha_evaluacion ASC',
    );
    return rows
        .map((row) => AssessmentModel.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<void> assignUnownedRecords(String ownerId) async {
    final db = await dbHelper.database;
    await db.update('assessments', {
      'owner_id': ownerId,
    }, where: 'owner_id IS NULL');
  }

  Future<void> markSynced(List<String> uuids) async {
    if (uuids.isEmpty) return;
    final db = await dbHelper.database;
    final placeholders = List.filled(uuids.length, '?').join(',');
    await db.rawUpdate(
      "UPDATE assessments SET sync_status = 'synced', last_sync_error = NULL, updated_at = ? WHERE uuid IN ($placeholders)",
      [DateTime.now().toUtc().toIso8601String(), ...uuids],
    );
  }

  Future<void> markPending(List<String> uuids) async {
    if (uuids.isEmpty) return;
    final db = await dbHelper.database;
    final placeholders = List.filled(uuids.length, '?').join(',');
    await db.rawUpdate(
      "UPDATE assessments SET sync_status = 'pending', last_sync_error = NULL, sync_attempts = sync_attempts + 1, updated_at = ? WHERE uuid IN ($placeholders)",
      [DateTime.now().toUtc().toIso8601String(), ...uuids],
    );
  }

  Future<void> markError(String uuid, String message) async {
    final db = await dbHelper.database;
    await db.rawUpdate(
      "UPDATE assessments SET sync_status = 'error', last_sync_error = ?, sync_attempts = sync_attempts + 1, updated_at = ? WHERE uuid = ?",
      [message, DateTime.now().toUtc().toIso8601String(), uuid],
    );
  }
}
