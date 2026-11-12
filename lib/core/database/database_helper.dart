import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'
    show sqfliteFfiInit, databaseFactoryFfi;

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
      sincronizado INTEGER NOT NULL DEFAULT 0,
      uuid TEXT,
      owner_id TEXT,
      sync_status TEXT NOT NULL DEFAULT 'pending',
      last_sync_error TEXT,
      sync_attempts INTEGER NOT NULL DEFAULT 0,
      updated_at TEXT
    )
  ''';

  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  final Database? _providedDatabase;

  DatabaseHelper._init() : _providedDatabase = null;
  DatabaseHelper.forDatabase(this._providedDatabase);

  Future<Database> get database async {
    final providedDatabase = _providedDatabase;
    if (providedDatabase != null) return providedDatabase;
    if (_database != null) return _database!;
    _database = await _initDB('rmpzd_maternal_health.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    // If running on Windows / Linux desktop in debug or release, ensure FFI is ready
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      sqfliteFfiInit();
      if (databaseFactory != databaseFactoryFfi) {
        databaseFactory = databaseFactoryFfi;
      }
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await createV2Schema(db);
  }

  @visibleForTesting
  static Future<void> createV2Schema(DatabaseExecutor db) async {
    await db.execute(_createAssessmentsTable);
    await db.execute(
      'CREATE UNIQUE INDEX idx_assessments_uuid ON assessments(uuid)',
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    for (var version = oldVersion; version < newVersion; version++) {
      switch (version) {
        case 1:
          await migrateV1ToV2(db);
          break;
      }
    }
  }

  @visibleForTesting
  static Future<void> migrateV1ToV2(DatabaseExecutor db) async {
    await db.execute('ALTER TABLE assessments ADD COLUMN uuid TEXT');
    await db.execute('ALTER TABLE assessments ADD COLUMN owner_id TEXT');
    await db.execute(
      "ALTER TABLE assessments ADD COLUMN sync_status TEXT NOT NULL DEFAULT 'pending'",
    );
    await db.execute('ALTER TABLE assessments ADD COLUMN last_sync_error TEXT');
    await db.execute(
      'ALTER TABLE assessments ADD COLUMN sync_attempts INTEGER NOT NULL DEFAULT 0',
    );
    await db.execute('ALTER TABLE assessments ADD COLUMN updated_at TEXT');

    final rows = await db.query('assessments', columns: ['id', 'sincronizado']);
    const uuid = Uuid();
    for (final row in rows) {
      await db.update(
        'assessments',
        {
          'uuid': uuid.v4(),
          'sync_status': row['sincronizado'] == 1 ? 'synced' : 'pending',
        },
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }

    // Legacy ownerless rows are assigned to the first user who accesses local data after login.
    await db.execute(
      'CREATE UNIQUE INDEX idx_assessments_uuid ON assessments(uuid)',
    );
  }

  Future<void> close() async {
    final injectedDb = _providedDatabase;
    if (injectedDb != null) {
      await injectedDb.close();
      return;
    }
    final db = _database;
    if (db != null) {
      await db.close();
    }
  }
}
