import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'
    show sqfliteFfiInit, databaseFactoryFfi;

class DatabaseHelper {
  static String _createAssessmentsTable({
    required bool withConsultationCode,
    bool withIdentityFields = false,
    bool withFullProbabilities = false,
  }) =>
      '''
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
      updated_at TEXT${withConsultationCode ? ',\n      codigo_consulta TEXT' : ''}${withIdentityFields ? ''',
      nombre_paciente TEXT,
      direccion_paciente TEXT,
      latitud REAL,
      longitud REAL,
      precision_gps_m REAL,
      ubicacion_capturada_at TEXT,
      consentimiento_datos INTEGER NOT NULL DEFAULT 0,
      consentimiento_at TEXT''' : ''}${withFullProbabilities ? ''',
      probabilidad_riesgo_medio REAL NOT NULL DEFAULT 0,
      probabilidad_riesgo_bajo REAL NOT NULL DEFAULT 0''' : ''}
    )
  ''';

  static const _createHealthFacilitiesTable = '''
    CREATE TABLE health_facilities (
    id TEXT PRIMARY KEY NOT NULL,
    nombre TEXT,
    tipo TEXT,
    nivel_atencion INTEGER,
    municipio TEXT,
    departamento TEXT,
    direccion TEXT,
    telefono TEXT,
    latitud REAL,
    longitud REAL,
    urgencias_24h INTEGER,
    atencion_obstetrica INTEGER,
    atencion_parto INTEGER,
    uci_adultos INTEGER,
    codigo_reps TEXT,
    fuente TEXT,
    verificado INTEGER,
    observaciones TEXT,
    activo INTEGER,
    created_at TEXT,
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
      version: 6,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await createV6Schema(db);
  }

  @visibleForTesting
  static Future<void> createV2Schema(DatabaseExecutor db) async {
    await db.execute(_createAssessmentsTable(withConsultationCode: false));
    await db.execute(
      'CREATE UNIQUE INDEX idx_assessments_uuid ON assessments(uuid)',
    );
  }

  @visibleForTesting
  static Future<void> createV3Schema(DatabaseExecutor db) async {
    await db.execute(_createAssessmentsTable(withConsultationCode: true));
    await db.execute(
      'CREATE UNIQUE INDEX idx_assessments_uuid ON assessments(uuid)',
    );
  }

  @visibleForTesting
  static Future<void> createV4Schema(DatabaseExecutor db) async {
    await db.execute(
      _createAssessmentsTable(
        withConsultationCode: true,
        withIdentityFields: true,
      ),
    );
    await db.execute(
      'CREATE UNIQUE INDEX idx_assessments_uuid ON assessments(uuid)',
    );
  }

  @visibleForTesting
  static Future<void> createV5Schema(DatabaseExecutor db) async {
    await createV4Schema(db);
    await _createHealthFacilities(db);
  }

  @visibleForTesting
  static Future<void> createV6Schema(DatabaseExecutor db) async {
    await db.execute(
      _createAssessmentsTable(
        withConsultationCode: true,
        withIdentityFields: true,
        withFullProbabilities: true,
      ),
    );
    await db.execute(
      'CREATE UNIQUE INDEX idx_assessments_uuid ON assessments(uuid)',
    );
    await _createHealthFacilities(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    for (var version = oldVersion; version < newVersion; version++) {
      switch (version) {
        case 1:
          await migrateV1ToV2(db);
          break;
        case 2:
          await migrateV2ToV3(db);
          break;
        case 3:
          await migrateV3ToV4(db);
          break;
        case 4:
          await migrateV4ToV5(db);
          break;
        case 5:
          await migrateV5ToV6(db);
          break;
      }
    }
  }

  @visibleForTesting
  static Future<void> migrateV2ToV3(DatabaseExecutor db) async {
    await db.execute('ALTER TABLE assessments ADD COLUMN codigo_consulta TEXT');
  }

  @visibleForTesting
  static Future<void> migrateV3ToV4(DatabaseExecutor db) async {
    await db.execute('ALTER TABLE assessments ADD COLUMN nombre_paciente TEXT');
    await db.execute(
      'ALTER TABLE assessments ADD COLUMN direccion_paciente TEXT',
    );
    await db.execute('ALTER TABLE assessments ADD COLUMN latitud REAL');
    await db.execute('ALTER TABLE assessments ADD COLUMN longitud REAL');
    await db.execute('ALTER TABLE assessments ADD COLUMN precision_gps_m REAL');
    await db.execute(
      'ALTER TABLE assessments ADD COLUMN ubicacion_capturada_at TEXT',
    );
    await db.execute(
      'ALTER TABLE assessments ADD COLUMN consentimiento_datos INTEGER NOT NULL DEFAULT 0',
    );
    await db.execute(
      'ALTER TABLE assessments ADD COLUMN consentimiento_at TEXT',
    );
  }

  @visibleForTesting
  static Future<void> migrateV4ToV5(DatabaseExecutor db) async {
    await _createHealthFacilities(db);
  }

  @visibleForTesting
  static Future<void> migrateV5ToV6(DatabaseExecutor db) async {
    await db.execute(
      'ALTER TABLE assessments ADD COLUMN probabilidad_riesgo_medio REAL NOT NULL DEFAULT 0',
    );
    await db.execute(
      'ALTER TABLE assessments ADD COLUMN probabilidad_riesgo_bajo REAL NOT NULL DEFAULT 0',
    );
  }

  static Future<void> _createHealthFacilities(DatabaseExecutor db) async {
    await db.execute(_createHealthFacilitiesTable);
    await db.execute(
      'CREATE INDEX idx_health_facilities_department_municipality '
      'ON health_facilities(departamento, municipio)',
    );
    await db.execute(
      'CREATE INDEX idx_health_facilities_active ON health_facilities(activo)',
    );
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
