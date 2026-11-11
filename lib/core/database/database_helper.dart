import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DatabaseHelper {
  static const String _createAssessmentsTable = '''
    CREATE TABLE assessments (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      patient_id TEXT NOT NULL,
      municipio TEXT NOT NULL,
      departamento TEXT NOT NULL,
      etnia TEXT NOT NULL,
      zona TEXT NOT NULL,
      edad_materna INTEGER NOT NULL,
      semanas_gestacion INTEGER NOT NULL,
      numero_controles INTEGER NOT NULL,
      distancia_km REAL NOT NULL,
      tiempo_traslado_horas REAL NOT NULL,
      hemoglobina REAL NOT NULL,
      presion_sistolica REAL NOT NULL,
      presion_diastolica REAL NOT NULL,
      imc REAL NOT NULL,
      antecedente_preeclampsia INTEGER NOT NULL,
      antecedente_diabetes INTEGER NOT NULL,
      parto_institucional_previo INTEGER NOT NULL,
      afiliacion_sgsss TEXT NOT NULL,
      fecha_evaluacion TEXT NOT NULL,
      nivel_riesgo_predicho TEXT NOT NULL,
      probabilidad_riesgo_alto REAL NOT NULL,
      alerta_clinica_inmediata INTEGER NOT NULL,
      descripcion_alerta TEXT,
      probabilidad_desenlace_adverso REAL NOT NULL,
      sincronizado INTEGER NOT NULL DEFAULT 0
    )
  ''';

  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('rmpzd_maternal_health.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    // If running on Windows / Linux desktop in debug or release, initialize FFI
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute(_createAssessmentsTable);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    for (var version = oldVersion; version < newVersion; version++) {
      switch (version) {
        case 1:
          // Add the version 2 migration here when the schema changes.
          break;
      }
    }
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
    }
  }
}
