import 'package:flutter_test/flutter_test.dart';
import 'package:rmpzd/core/database/database_helper.dart';
import 'package:rmpzd/core/sync/sync_service.dart';
import 'package:rmpzd/features/triage/data/datasources/assessment_local_datasource.dart';
import 'package:rmpzd/features/triage/data/datasources/assessment_remote_datasource.dart';
import 'package:rmpzd/features/triage/data/models/assessment_model.dart';
import 'package:rmpzd/features/triage/data/repositories/assessment_repository_impl.dart';
import 'package:rmpzd/features/triage/domain/entities/assessment_record.dart';
import 'package:rmpzd/features/triage/domain/entities/patient_assessment.dart';
import 'package:rmpzd/features/triage/domain/entities/triage_result.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test(
    'migrates version 1 rows to unique UUIDs and correct sync statuses',
    () async {
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      addTearDown(db.close);
      await db.execute('''
      CREATE TABLE assessments (
        id INTEGER PRIMARY KEY,
        sincronizado INTEGER NOT NULL DEFAULT 0
      )
    ''');
      await db.insert('assessments', {'sincronizado': 1});
      await db.insert('assessments', {'sincronizado': 0});

      await DatabaseHelper.migrateV1ToV2(db);

      final rows = await db.query('assessments', orderBy: 'id');
      expect(rows.map((row) => row['uuid']).toSet(), hasLength(2));
      expect(rows.map((row) => row['sync_status']), ['synced', 'pending']);
      expect(rows.map((row) => row['owner_id']), [null, null]);
      expect(rows.map((row) => row['sync_attempts']), [0, 0]);
      await expectLater(
        db.update(
          'assessments',
          {'uuid': rows.first['uuid']},
          where: 'id = ?',
          whereArgs: [rows.last['id']],
        ),
        throwsA(isA<DatabaseException>()),
      );
    },
  );

  test(
    'migrates version 2 rows and preserves them without a consultation code',
    () async {
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      addTearDown(db.close);
      await DatabaseHelper.createV2Schema(db);
      await db.insert('assessments', {
        'patient_id': 'legacy',
        'municipio': 'Valledupar',
        'departamento': 'Cesar',
        'etnia': 'No Indígena',
        'zona': 'Urbana',
        'edad_materna': 24,
        'semanas_gestacion': 28,
        'numero_controles': 3,
        'distancia_km': 18.5,
        'tiempo_traslado_horas': 1.8,
        'hemoglobina': 11.2,
        'presion_sistolica': 120,
        'presion_diastolica': 75,
        'imc': 25.4,
        'antecedente_preeclampsia': 0,
        'antecedente_diabetes': 0,
        'parto_institucional_previo': 1,
        'afiliacion_sgsss': 'Subsidiado',
        'fecha_evaluacion': '2026-11-11T00:00:00.000',
        'nivel_riesgo_predicho': 'Bajo Riesgo',
        'probabilidad_riesgo_alto': 0.1,
        'alerta_clinica_inmediata': 0,
        'probabilidad_desenlace_adverso': 0.1,
        'uuid': 'legacy-uuid',
      });

      await DatabaseHelper.migrateV2ToV3(db);
      await DatabaseHelper.migrateV3ToV4(db);

      final rows = await db.query(
        'assessments',
        columns: [
          'patient_id',
          'codigo_consulta',
          'nombre_paciente',
          'direccion_paciente',
          'latitud',
          'longitud',
          'precision_gps_m',
          'ubicacion_capturada_at',
          'consentimiento_datos',
          'consentimiento_at',
        ],
      );
      expect(rows.single, {
        'patient_id': 'legacy',
        'codigo_consulta': null,
        'nombre_paciente': null,
        'direccion_paciente': null,
        'latitud': null,
        'longitud': null,
        'precision_gps_m': null,
        'ubicacion_capturada_at': null,
        'consentimiento_datos': 0,
        'consentimiento_at': null,
      });
    },
  );

  test('migrates version 4 by creating the indexed facility catalog', () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    addTearDown(db.close);
    await DatabaseHelper.createV4Schema(db);

    await DatabaseHelper.migrateV4ToV5(db);

    final columns = await db.rawQuery('PRAGMA table_info(health_facilities)');
    expect(columns.map((column) => column['name']), [
      'id',
      'nombre',
      'tipo',
      'nivel_atencion',
      'municipio',
      'departamento',
      'direccion',
      'telefono',
      'latitud',
      'longitud',
      'urgencias_24h',
      'atencion_obstetrica',
      'atencion_parto',
      'uci_adultos',
      'codigo_reps',
      'fuente',
      'verificado',
      'observaciones',
      'activo',
      'created_at',
      'updated_at',
    ]);
    final columnTypes = {
      for (final column in columns)
        column['name']: column['type'],
    };
    expect(columnTypes['id'], 'TEXT');
    expect(columnTypes['nivel_atencion'], 'INTEGER');
    expect(columnTypes['latitud'], 'REAL');
    expect(columnTypes['longitud'], 'REAL');
    for (final column in [
      'urgencias_24h',
      'atencion_obstetrica',
      'atencion_parto',
      'uci_adultos',
      'verificado',
      'activo',
    ]) {
      expect(columnTypes[column], 'INTEGER');
    }
    expect(columnTypes['created_at'], 'TEXT');
    expect(columnTypes['updated_at'], 'TEXT');
    final indexes = await db.rawQuery('PRAGMA index_list(health_facilities)');
    expect(
      indexes.map((index) => index['name']),
      containsAll([
        'idx_health_facilities_department_municipality',
        'idx_health_facilities_active',
      ]),
    );
  });

  test('migrates version 5 by adding full probability columns', () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    addTearDown(db.close);
    await DatabaseHelper.createV5Schema(db);

    await DatabaseHelper.migrateV5ToV6(db);

    final columns = await db.rawQuery('PRAGMA table_info(assessments)');
    expect(
      columns.map((column) => column['name']),
      containsAll(['probabilidad_riesgo_medio', 'probabilidad_riesgo_bajo']),
    );
  });

  test('updates and deletes local assessments while preserving uuid', () async {
    final (database, _, _, repository) = await _createLocalStore();
    addTearDown(database.close);
    final saved = await repository.saveAssessment(
      _patient('editable', consentimientoDatos: true, nombrePaciente: 'Inicial'),
      _result,
      ownerId: 'doctor-1',
    );

    final updatedPatient = _patient(
      'editable-2',
      consentimientoDatos: true,
      nombrePaciente: 'Actualizada',
      direccionPaciente: 'Vereda Norte',
    );
    const updatedResult = TriageResult(
      riskLevel: RiskLevel.medio,
      probAlto: 0.2,
      probMedio: 0.65,
      probBajo: 0.15,
      riesgoDesenlaceAdverso: false,
      probDesenlaceAdverso: 0.18,
      clinicalAlerts: [],
      hasImmediateEmergency: false,
    );

    final updated = await repository.updateAssessment(
      saved,
      updatedPatient,
      updatedResult,
    );

    expect(updated.uuid, saved.uuid);
    expect(updated.consultationCode, saved.consultationCode);
    expect(updated.patient.patientId, 'editable-2');
    expect(updated.patient.nombrePaciente, 'Actualizada');
    expect(updated.result.probMedio, 0.65);
    expect(updated.result.probBajo, 0.15);

    await repository.deleteAssessment(uuid: saved.uuid);
    expect(await repository.getHistory(ownerId: 'doctor-1'), isEmpty);
  });

  test('history and pending counts are scoped to the current owner', () async {
    final (database, _, local, repository) = await _createLocalStore();
    addTearDown(database.close);
    await database.insert(
      'assessments',
      AssessmentModel(
        record: AssessmentRecord(
          patient: _patient('legacy'),
          result: _result,
          uuid: '97c76ec7-9228-4de0-88c3-f2efee432939',
          ownerId: null,
          fechaGuardado: DateTime.utc(2026, 11, 10),
        ),
      ).toMap(),
    );
    await repository.saveAssessment(
      _patient('one'),
      _result,
      ownerId: 'doctor-1',
    );
    await repository.saveAssessment(
      _patient('two'),
      _result,
      ownerId: 'doctor-2',
    );

    final firstOwnerHistory = await repository.getHistory(ownerId: 'doctor-1');

    expect(firstOwnerHistory, hasLength(2));
    expect(
      firstOwnerHistory.map((record) => record.patient.patientId),
      containsAll(['one', 'legacy']),
    );
    final savedRecord = firstOwnerHistory.singleWhere(
      (record) => record.patient.patientId == 'one',
    );
    expect(
      savedRecord.consultationCode,
      matches(r'^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{8}$'),
    );
    expect(await repository.getUnsyncedCount(ownerId: 'doctor-1'), 2);
    expect(await local.getUnsyncedCount('doctor-2'), 1);
    final legacyRow = await database.query(
      'assessments',
      columns: ['owner_id'],
      where: 'patient_id = ?',
      whereArgs: ['legacy'],
    );
    expect(legacyRow.single['owner_id'], 'doctor-1');
  });

  test('sets the consent timestamp when the assessment is saved', () async {
    final (database, _, _, repository) = await _createLocalStore();
    addTearDown(database.close);
    final beforeSave = DateTime.now().toUtc();

    final saved = await repository.saveAssessment(
      _patient(
        'consented',
        consentimientoDatos: true,
        nombrePaciente: 'Paciente de prueba',
        direccionPaciente: 'Vereda Central',
      ),
      _result,
      ownerId: 'doctor-1',
    );
    final afterSave = DateTime.now().toUtc();

    expect(saved.consentimientoAt, isNotNull);
    expect(saved.consentimientoAt!.isUtc, isTrue);
    expect(saved.consentimientoAt!.isBefore(beforeSave), isFalse);
    expect(
      saved.consentimientoAt!.isBefore(afterSave) ||
          saved.consentimientoAt == afterSave,
      isTrue,
    );
    final row = await database.query(
      'assessments',
      columns: [
        'nombre_paciente',
        'direccion_paciente',
        'consentimiento_datos',
      ],
      where: 'patient_id = ?',
      whereArgs: ['consented'],
    );
    expect(row.single['consentimiento_datos'], 1);
    expect(row.single['nombre_paciente'], 'Paciente de prueba');
    expect(row.single['direccion_paciente'], 'Vereda Central');
  });

  test('sync marks the full batch as synced on success', () async {
    final fixture = await _syncFixture();
    addTearDown(fixture.database.close);
    await fixture.repository.saveAssessment(
      _patient('good-1'),
      _result,
      ownerId: 'doctor-1',
    );
    await fixture.repository.saveAssessment(
      _patient('good-2'),
      _result,
      ownerId: 'doctor-1',
    );

    final result = await fixture.service.syncPending();

    expect(result.enviados, 2);
    expect(result.fallidos, 0);
    expect(result.pendientes, 0);
    expect(fixture.remote.acceptedIds, hasLength(2));
    expect(await fixture.repository.getUnsyncedCount(ownerId: 'doctor-1'), 0);
  });

  test('network failure leaves records pending', () async {
    final fixture = await _syncFixture();
    addTearDown(fixture.database.close);
    await fixture.repository.saveAssessment(
      _patient('offline'),
      _result,
      ownerId: 'doctor-1',
    );
    fixture.remote.networkFailure = true;

    final result = await fixture.service.syncPending();

    expect(result.enviados, 0);
    expect(result.pendientes, 1);
    final record = (await fixture.repository.getHistory(
      ownerId: 'doctor-1',
    )).single;
    expect(record.syncStatus, SyncStatus.pending);
  });

  test(
    'isolates a rejected record while syncing valid records in the batch',
    () async {
      final fixture = await _syncFixture();
      addTearDown(fixture.database.close);
      await fixture.repository.saveAssessment(
        _patient('valid-one'),
        _result,
        ownerId: 'doctor-1',
      );
      await fixture.repository.saveAssessment(
        _patient('invalid'),
        _result,
        ownerId: 'doctor-1',
      );
      await fixture.repository.saveAssessment(
        _patient('valid-two'),
        _result,
        ownerId: 'doctor-1',
      );
      fixture.remote.invalidPatientId = 'invalid';

      final result = await fixture.service.syncPending();
      final history = await fixture.repository.getHistory(ownerId: 'doctor-1');

      expect(result.enviados, 2);
      expect(result.fallidos, 1);
      expect(result.pendientes, 1);
      expect(
        history
            .singleWhere((record) => record.patient.patientId == 'invalid')
            .syncStatus,
        SyncStatus.error,
      );
      expect(
        history.where((record) => record.syncStatus == SyncStatus.synced),
        hasLength(2),
      );
      final rejectedRow = await fixture.database.query(
        'assessments',
        columns: ['sync_attempts', 'last_sync_error'],
        where: 'patient_id = ?',
        whereArgs: ['invalid'],
      );
      expect(rejectedRow.single['sync_attempts'], 1);
      expect(rejectedRow.single['last_sync_error'], isNotEmpty);
    },
  );

  test(
    'retry after an ambiguous network failure does not duplicate remote identity',
    () async {
      final fixture = await _syncFixture();
      addTearDown(fixture.database.close);
      await fixture.repository.saveAssessment(
        _patient('once'),
        _result,
        ownerId: 'doctor-1',
      );
      fixture.remote.acceptThenNetworkFailure = true;

      final firstResult = await fixture.service.syncPending();
      final secondResult = await fixture.service.syncPending();

      expect(firstResult.pendientes, 1);
      expect(fixture.remote.acceptedIds, hasLength(1));
      expect(fixture.remote.batchCalls, 2);
      expect(secondResult.enviados, 1);
      expect(secondResult.pendientes, 0);
    },
  );
}

const _result = TriageResult(
  riskLevel: RiskLevel.bajo,
  probAlto: 0.1,
  probMedio: 0.2,
  probBajo: 0.7,
  riesgoDesenlaceAdverso: false,
  probDesenlaceAdverso: 0.1,
  clinicalAlerts: [],
  hasImmediateEmergency: false,
);

PatientAssessment _patient(
  String patientId, {
  bool consentimientoDatos = false,
  String? nombrePaciente,
  String? direccionPaciente,
}) => PatientAssessment(
  patientId: patientId,
  municipio: 'Valledupar',
  departamento: 'Cesar',
  etnia: 'No Indígena',
  zona: 'Urbana',
  edadMaterna: 24,
  semanasGestacion: 28,
  numeroControles: 3,
  distanciaKm: 18.5,
  tiempoTrasladoHoras: 1.8,
  hemoglobina: 11.2,
  presionSistolica: 120,
  presionDiastolica: 75,
  imc: 25.4,
  antecedentePreeclampsia: false,
  antecedenteDiabetes: false,
  partoInstitucionalPrevio: true,
  afiliacionSgsss: 'Subsidiado',
  fechaEvaluacion: DateTime.utc(2026, 11, 11),
  nombrePaciente: nombrePaciente,
  direccionPaciente: direccionPaciente,
  consentimientoDatos: consentimientoDatos,
);

Future<
  (
    Database,
    DatabaseHelper,
    AssessmentLocalDataSource,
    AssessmentRepositoryImpl,
  )
>
_createLocalStore() async {
  final database = await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 6,
      onCreate: (db, version) => DatabaseHelper.createV6Schema(db),
    ),
  );
  final helper = DatabaseHelper.forDatabase(database);
  final local = AssessmentLocalDataSource(dbHelper: helper);
  final repository = AssessmentRepositoryImpl(localDataSource: local);
  return (database, helper, local, repository);
}

Future<_SyncFixture> _syncFixture() async {
  final (database, _, local, repository) = await _createLocalStore();
  final remote = _FakeRemoteDataSource();
  final service = SyncService(
    localDataSource: local,
    remoteDataSource: remote,
    hasInternet: () async => true,
    currentOwnerId: () => 'doctor-1',
    hasSession: () => true,
  );
  return _SyncFixture(database, repository, remote, service);
}

class _SyncFixture {
  final Database database;
  final AssessmentRepositoryImpl repository;
  final _FakeRemoteDataSource remote;
  final SyncService service;

  const _SyncFixture(this.database, this.repository, this.remote, this.service);
}

class _FakeRemoteDataSource implements AssessmentRemoteDataSource {
  final Set<String> acceptedIds = {};
  int batchCalls = 0;
  bool networkFailure = false;
  bool acceptThenNetworkFailure = false;
  String? invalidPatientId;

  @override
  Future<void> upsertBatch(List<Map<String, dynamic>> payload) async {
    batchCalls++;
    if (networkFailure) throw const _NetworkFailure();
    if (payload.any((row) => row['patient_id'] == invalidPatientId)) {
      throw const _ClientFailure();
    }
    for (final row in payload) {
      acceptedIds.add(row['id'] as String);
    }
    if (acceptThenNetworkFailure) {
      acceptThenNetworkFailure = false;
      throw const _NetworkFailure();
    }
  }

  @override
  Future<bool> updateAssessment(
    String uuid,
    Map<String, dynamic> payload,
  ) async => true;

  @override
  Future<bool> deleteAssessment(String uuid) async => true;

  @override
  bool isClientFailure(Object error) => error is _ClientFailure;

  @override
  bool isNetworkFailure(Object error) => error is _NetworkFailure;
}

class _ClientFailure implements Exception {
  const _ClientFailure();
}

class _NetworkFailure implements Exception {
  const _NetworkFailure();
}
