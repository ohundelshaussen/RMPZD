import 'package:flutter_test/flutter_test.dart';
import 'package:rmpzd/core/database/database_helper.dart';
import 'package:rmpzd/features/facilities/data/datasources/facility_local_datasource.dart';
import 'package:rmpzd/features/facilities/data/datasources/facility_remote_datasource.dart';
import 'package:rmpzd/features/facilities/data/repositories/facility_repository_impl.dart';
import 'package:rmpzd/features/facilities/domain/entities/health_facility.dart';
import 'package:rmpzd/features/facilities/domain/repositories/facility_repository.dart';
import 'package:rmpzd/features/facilities/domain/usecases/get_nearest_facilities_usecase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test(
    'finds nearest facilities with Haversine distance and correct ordering',
    () async {
      final (database, repository) = await _createRepository();
      addTearDown(database.close);
      final local = FacilityLocalDataSource(
        dbHelper: DatabaseHelper.forDatabase(database),
      );
      await local.applyFacilities([
        _facility(
          'riohacha',
          name: 'Hospital de Riohacha',
          latitude: 11.5444,
          longitude: -72.9072,
        ),
        _facility(
          'nearby',
          name: 'Centro cercano',
          latitude: 10.50,
          longitude: -73.25,
        ),
        _facility('far', name: 'Centro distante', latitude: 15, longitude: -74),
      ]);

      final results = await GetNearestFacilitiesUseCase(
        repository,
      ).execute(10.4631, -73.2532, limite: 2);

      expect(results.map((facility) => facility.id), ['nearby', 'riohacha']);
      expect(results.first.distanceKm!, lessThan(results.last.distanceKm!));
      expect(results.last.distanceKm, closeTo(126, 3));
    },
  );

  test(
    'filters active catalog by obstetric care, emergencies, and territory',
    () async {
      final (database, repository) = await _createRepository();
      addTearDown(database.close);
      final local = FacilityLocalDataSource(
        dbHelper: DatabaseHelper.forDatabase(database),
      );
      await local.applyFacilities([
        _facility(
          'both',
          name: 'Centro A',
          department: 'La Guajira',
          municipality: 'Riohacha',
          obstetricCare: true,
          emergency24h: true,
        ),
        _facility(
          'obstetric',
          name: 'Centro B',
          department: 'La Guajira',
          municipality: 'Riohacha',
          obstetricCare: true,
          emergency24h: false,
        ),
        _facility(
          'urgent',
          name: 'Centro C',
          department: 'Cesar',
          municipality: 'Valledupar',
          obstetricCare: false,
          emergency24h: true,
        ),
        _facility(
          'inactive',
          name: 'Centro inactivo',
          department: 'La Guajira',
          municipality: 'Riohacha',
          active: false,
          obstetricCare: true,
          emergency24h: true,
        ),
      ]);
      final useCase = GetNearestFacilitiesUseCase(repository);

      final obstetric = await useCase.execute(
        null,
        null,
        departamento: 'la guajira',
        soloObstetricas: true,
      );
      final emergency = await useCase.execute(
        null,
        null,
        municipio: 'Riohacha',
        soloUrgencias: true,
      );
      final combined = await useCase.execute(
        null,
        null,
        departamento: 'Cesar',
        soloObstetricas: true,
        soloUrgencias: true,
      );

      expect(obstetric.map((facility) => facility.id), ['both', 'obstetric']);
      expect(
        obstetric.every((facility) => facility.distanceKm == null),
        isTrue,
      );
      expect(emergency.map((facility) => facility.id), ['both']);
      expect(combined, isEmpty);
      expect(await local.countActiveFacilities(), 3);
    },
  );

  test(
    'OR service filter includes unverified centers but excludes verified negatives',
    () async {
      final (database, repository) = await _createRepository();
      addTearDown(database.close);
      final local = FacilityLocalDataSource(
        dbHelper: DatabaseHelper.forDatabase(database),
      );
      await local.applyFacilities([
        _facility(
          'unknown',
          name: 'Centro desconocido',
          latitude: 10.50,
          longitude: -73.25,
          verified: false,
          obstetricCare: false,
          emergency24h: false,
        ),
        _facility(
          'confirmed',
          name: 'Centro confirmado',
          latitude: 11.5444,
          longitude: -72.9072,
          verified: true,
          obstetricCare: true,
          emergency24h: false,
        ),
        _facility(
          'negative',
          name: 'Centro sin servicios',
          latitude: 12,
          longitude: -72.5,
          verified: true,
          obstetricCare: false,
          emergency24h: false,
        ),
      ]);

      final results = await GetNearestFacilitiesUseCase(
        repository,
      ).execute(10.4631, -73.2532, soloObstetricasOUrgencias: true);

      expect(results.map((facility) => facility.id), ['unknown', 'confirmed']);
      expect(results.first.distanceKm, lessThan(results.last.distanceKm!));
    },
  );

  test(
    'pulls incrementally in pages, saves the cursor, and deletes inactive rows',
    () async {
      final (database, repository, remote) =
          await _createRepositoryWithRemote();
      addTearDown(database.close);
      final local = FacilityLocalDataSource(
        dbHelper: DatabaseHelper.forDatabase(database),
      );
      await local.applyFacilities([_facility('remove-me')]);
      final updatedAt = DateTime.utc(2026, 11, 20);
      remote.rows.addAll([
        for (var index = 0; index < 500; index++)
          _remoteFacility(
            'facility-$index',
            updatedAt.add(Duration(seconds: index)),
          ),
        _remoteFacility(
          'remove-me',
          updatedAt.add(const Duration(seconds: 500)),
          active: false,
        ),
      ]);

      final received = await repository.syncFacilities();
      final cursor = (await repository.getCatalogStatus()).lastUpdatedAt;
      final activeFacilities = await local.getActiveFacilities();

      expect(received, 501);
      expect(remote.calls, hasLength(2));
      expect(remote.calls.map((call) => call.offset), [0, 500]);
      expect(remote.calls.map((call) => call.limit), [500, 500]);
      expect(remote.calls.map((call) => call.updatedAfter), [null, null]);
      expect(cursor, updatedAt.add(const Duration(seconds: 500)));
      expect(activeFacilities, hasLength(500));
      expect(
        activeFacilities.any((facility) => facility.id == 'remove-me'),
        isFalse,
      );

      final nextReceived = await repository.syncFacilities();
      expect(nextReceived, 0);
      expect(remote.calls.last.updatedAfter, cursor);
      expect(remote.calls.last.updatedAfter?.isUtc, isTrue);
    },
  );
}

Future<(Database, FacilityRepository)> _createRepository() async {
  final (database, repository, _) = await _createRepositoryWithRemote();
  return (database, repository);
}

Future<(Database, FacilityRepository, _FakeFacilityRemoteDataSource)>
_createRepositoryWithRemote() async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final database = await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 5,
      onCreate: (db, version) => DatabaseHelper.createV5Schema(db),
    ),
  );
  final remote = _FakeFacilityRemoteDataSource();
  final repository = FacilityRepositoryImpl(
    remoteDataSource: remote,
    localDataSource: FacilityLocalDataSource(
      dbHelper: DatabaseHelper.forDatabase(database),
    ),
    preferences: preferences,
  );
  return (database, repository, remote);
}

HealthFacility _facility(
  String id, {
  String? name,
  String? department = 'La Guajira',
  String? municipality = 'Riohacha',
  double? latitude = 11.5444,
  double? longitude = -72.9072,
  bool? active = true,
  bool? obstetricCare = false,
  bool? emergency24h = false,
  bool? verified = true,
}) {
  return HealthFacility(
    id: id,
    name: name ?? id,
    department: department,
    municipality: municipality,
    latitude: latitude,
    longitude: longitude,
    active: active,
    obstetricCare: obstetricCare,
    emergency24h: emergency24h,
    verified: verified,
  );
}

Map<String, dynamic> _remoteFacility(
  String id,
  DateTime updatedAt, {
  bool active = true,
}) {
  return {
    'id': id,
    'nombre': id,
    'activo': active,
    'updated_at': updatedAt.toIso8601String(),
  };
}

class _FakeFacilityRemoteDataSource implements FacilityRemoteDataSource {
  final List<Map<String, dynamic>> rows = [];
  final List<_RemoteCall> calls = [];

  @override
  Future<List<Map<String, dynamic>>> fetchFacilities({
    required DateTime? updatedAfter,
    required int offset,
    required int limit,
  }) async {
    calls.add(_RemoteCall(updatedAfter, offset, limit));
    final eligible =
        rows.where((row) {
          final date = DateTime.parse(row['updated_at'] as String);
          return updatedAfter == null || date.isAfter(updatedAfter);
        }).toList()..sort((left, right) {
          final dateOrder = (left['updated_at'] as String).compareTo(
            right['updated_at'] as String,
          );
          return dateOrder != 0
              ? dateOrder
              : (left['id'] as String).compareTo(right['id'] as String);
        });
    return eligible.skip(offset).take(limit).toList();
  }
}

class _RemoteCall {
  final DateTime? updatedAfter;
  final int offset;
  final int limit;

  const _RemoteCall(this.updatedAfter, this.offset, this.limit);
}
