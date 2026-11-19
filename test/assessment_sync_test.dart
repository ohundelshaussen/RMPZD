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

  test('migrates version 2 rows and preserves them without a consultation code', () async {
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

    final rows = await db.query(
      'assessments',
      columns: ['patient_id', 'codigo_consulta'],
    );
    expect(rows.single, {'patient_id': 'legacy', 'codigo_consulta': null});
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
    expect(savedRecord.consultationCode, matches(r'^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{8}$'));
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

PatientAssessment _patient(String patientId) => PatientAssessment(
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
      version: 3,
      onCreate: (db, version) => DatabaseHelper.createV3Schema(db),
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
