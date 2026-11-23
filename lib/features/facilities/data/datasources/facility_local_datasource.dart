import '../../../../core/database/database_helper.dart';
import 'package:sqflite/sqflite.dart';

import '../../domain/entities/health_facility.dart';
import '../models/health_facility_model.dart';

class FacilityLocalDataSource {
  final DatabaseHelper dbHelper;

  const FacilityLocalDataSource({required this.dbHelper});

  Future<void> applyFacilities(List<HealthFacility> facilities) async {
    if (facilities.isEmpty) return;
    final db = await dbHelper.database;
    await db.transaction((transaction) async {
      for (final facility in facilities) {
        if (facility.active == false) {
          await transaction.delete(
            'health_facilities',
            where: 'id = ?',
            whereArgs: [facility.id],
          );
        } else {
          await transaction.insert(
            'health_facilities',
            HealthFacilityModel.fromEntity(facility).toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });
  }

  Future<List<HealthFacilityModel>> getActiveFacilities() async {
    final db = await dbHelper.database;
    final rows = await db.query(
      'health_facilities',
      where: 'activo = ?',
      whereArgs: [1],
    );
    return rows
        .map((row) => HealthFacilityModel.fromMap(row))
        .toList(growable: false);
  }

  Future<int> countActiveFacilities() async {
    final db = await dbHelper.database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM health_facilities WHERE activo = ?',
      [1],
    );
    return rows.single['count'] as int;
  }
}
