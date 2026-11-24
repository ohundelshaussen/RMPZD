import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:rmpzd/core/constants/colombia_locations.dart';
import 'package:rmpzd/core/database/database_helper.dart';
import 'package:rmpzd/features/facilities/data/datasources/facility_local_datasource.dart';
import 'package:rmpzd/features/facilities/data/datasources/facility_remote_datasource.dart';
import 'package:rmpzd/features/facilities/data/datasources/facility_seed_datasource.dart';
import 'package:rmpzd/features/facilities/data/repositories/facility_repository_impl.dart';
import 'package:rmpzd/features/facilities/domain/entities/health_facility.dart';
import 'package:rmpzd/features/facilities/domain/repositories/facility_repository.dart';
import 'package:rmpzd/features/facilities/domain/usecases/get_nearest_facilities_usecase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
  });

  test(
    'GPS search ignores territory and orders facilities across municipalities by distance',
    () async {
      final (database, repository) = await _createRepository();
      addTearDown(database.close);
      final local = FacilityLocalDataSource(
        dbHelper: DatabaseHelper.forDatabase(database),
      );
      await local.applyFacilities([
        _facility(
          'inside-x',
          name: 'Centro A',
          municipality: 'Municipio X',
          latitude: 10.9,
          longitude: -73.2,
        ),
        _facility(
          'neighbor-b',
          name: 'Centro B',
          municipality: 'Municipio Y',
          latitude: 10.46,
          longitude: -73.25,
        ),
      ]);

      final results = await GetNearestFacilitiesUseCase(
        repository,
      ).execute(10.4631, -73.2532, municipio: 'Municipio X', limite: 5);

      expect(results.map((facility) => facility.id), [
        'neighbor-b',
        'inside-x',
      ]);
      expect(results.first.distanceKm, isNotNull);
      expect(results.last.distanceKm, isNotNull);
      expect(results.first.distanceKm!, lessThan(results.last.distanceKm!));
    },
  );

  test('territory fallback is alphabetical and has no distance', () async {
    final (database, repository) = await _createRepository();
    addTearDown(database.close);
    final local = FacilityLocalDataSource(
      dbHelper: DatabaseHelper.forDatabase(database),
    );
    await local.applyFacilities([
      _facility('z', name: 'Zulu', municipality: 'Riohacha'),
      _facility('a', name: 'Alfa', municipality: 'Riohacha'),
      _facility('neighbor', name: 'Vecino', municipality: 'Maicao'),
    ]);

    final results = await GetNearestFacilitiesUseCase(
      repository,
    ).execute(null, null, municipio: 'Riohacha');

    expect(results.map((facility) => facility.id), ['a', 'z']);
    expect(results.every((facility) => facility.distanceKm == null), isTrue);
  });

  test('without GPS or territory throws ArgumentError', () async {
    final (database, repository) = await _createRepository();
    addTearDown(database.close);

    expect(
      GetNearestFacilitiesUseCase(repository).execute(null, null),
      throwsArgumentError,
    );
  });

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

  test(
    'seed asset loads verified facilities for all supported municipalities',
    () async {
      final facilities = await const AssetFacilitySeedDataSource()
          .loadSeedFacilities();
      expect(facilities, hasLength(26));
      for (final facility in facilities) {
        expect(facility.active, isTrue, reason: 'Inactive seed ${facility.id}');
        expect(
          facility.verified,
          isTrue,
          reason: 'Unverified seed ${facility.id}',
        );
        expect(
          facility.repsCode?.trim(),
          isNotEmpty,
          reason: 'Missing REPS code for ${facility.id}',
        );
        expect(facility.latitude, isNotNull);
        expect(facility.longitude, isNotNull);
        expect(
          facility.latitude!,
          inInclusiveRange(7.8, 12.6),
          reason: 'Latitude out of La Guajira/Cesar bounds for ${facility.id}',
        );
        expect(
          facility.longitude!,
          inInclusiveRange(-74.2, -71.0),
          reason: 'Longitude out of La Guajira/Cesar bounds for ${facility.id}',
        );
      }

      for (var i = 0; i < facilities.length; i++) {
        for (var j = i + 1; j < facilities.length; j++) {
          final distanceM = _distanceMeters(
            facilities[i].latitude!,
            facilities[i].longitude!,
            facilities[j].latitude!,
            facilities[j].longitude!,
          );
          expect(
            distanceM,
            greaterThan(50.0),
            reason:
                'Facilities ${facilities[i].id} and ${facilities[j].id} are too close ($distanceM m)',
          );
        }
      }

      final byId = {for (final f in facilities) f.id: f};
      expect(byId['seed-guajira-sanjuan-bautista']?.adultIcu, isTrue);
      expect(byId['seed-cesar-aguachica-local']?.deliveryCare, isTrue);

      final seededMunicipalities = facilities
          .map((f) => normalizeLocationName(f.municipality))
          .whereType<String>()
          .toSet();
      for (final munis in municipalitiesByDepartment.values) {
        for (final muni in munis) {
          expect(
            seededMunicipalities,
            contains(normalizeLocationName(muni)),
            reason: 'Missing seed facility for $muni',
          );
          final coords = coordinatesForMunicipality(muni);
          expect(
            coords,
            isNotNull,
            reason: 'Missing centroid for $muni',
          );
          expect(coords!.lat, inInclusiveRange(7.8, 12.6));
          expect(coords.lng, inInclusiveRange(-74.2, -71.0));
        }
      }
      expect(
        coordinatesForMunicipality('Agustin Codazzi'),
        equals(coordinatesForMunicipality('Agustín Codazzi')),
      );
    },
  );

  test(
    'upgrades stale v1 seed rows to 2026 coordinates without overwriting newer remote rows',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final database = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 5,
          onCreate: (db, version) => DatabaseHelper.createV5Schema(db),
        ),
      );
      addTearDown(database.close);

      final local = FacilityLocalDataSource(
        dbHelper: DatabaseHelper.forDatabase(database),
      );
      final staleUpdatedAt = DateTime.utc(2026, 11, 24, 0, 0);
      final newerRemoteUpdatedAt = DateTime.utc(2026, 12, 1, 0, 0);
      await local.applyFacilities([
        _facility(
          'seed-cesar-valledupar-erasmo',
          name: 'Clínica Erasmo Ltda.',
          department: 'Cesar',
          municipality: 'Valledupar',
          latitude: 10.4682,
          longitude: -73.2514,
          emergency24h: true,
          updatedAt: staleUpdatedAt,
        ),
        _facility(
          'seed-guajira-riohacha-cedes',
          name: 'Clínica Cedes (Remota más reciente)',
          department: 'La Guajira',
          municipality: 'Riohacha',
          latitude: 11.54500,
          longitude: -72.91250,
          obstetricCare: true,
          emergency24h: true,
          updatedAt: newerRemoteUpdatedAt,
        ),
        _facility(
          'remote-custom-facility',
          name: 'Centro Remoto Personalizado',
          department: 'Cesar',
          municipality: 'Valledupar',
          latitude: 10.5000,
          longitude: -73.2600,
          obstetricCare: true,
          emergency24h: true,
          updatedAt: newerRemoteUpdatedAt,
        ),
      ]);

      final repository = FacilityRepositoryImpl(
        remoteDataSource: _FakeFacilityRemoteDataSource(),
        localDataSource: local,
        preferences: preferences,
        seedDataSource: const AssetFacilitySeedDataSource(),
      );

      final nearest = await repository.getNearestFacilities(
        10.4878,
        -73.2643,
        limit: 5,
      );
      expect(nearest.first.id, 'seed-cesar-valledupar-erasmo');
      expect(nearest.first.latitude, closeTo(10.487793, 1e-6));
      expect(nearest.first.longitude, closeTo(-73.264334, 1e-6));
      expect(nearest.first.repsCode, '200010026901');
      expect(nearest.first.updatedAt, DateTime.utc(2026, 11, 24, 2, 30));

      final status = await repository.getCatalogStatus();
      expect(status.availableCount, 27);
      expect(status.lastUpdatedAt, isNull);
      expect(preferences.getInt('health_facilities_seed_version'), 2);

      final activeById = {
        for (final facility in await local.getActiveFacilities())
          facility.id: facility,
      };
      final custom = activeById['remote-custom-facility']!;
      expect(custom.latitude, 10.5000);
      expect(custom.longitude, -73.2600);
      expect(custom.updatedAt, newerRemoteUpdatedAt);

      final newerSeedOverride = activeById['seed-guajira-riohacha-cedes']!;
      expect(newerSeedOverride.name, 'Clínica Cedes (Remota más reciente)');
      expect(newerSeedOverride.latitude, 11.54500);
      expect(newerSeedOverride.longitude, -72.91250);
      expect(newerSeedOverride.updatedAt, newerRemoteUpdatedAt);
    },
  );

  test(
    'auto-seeds empty database without advancing sync cursor, handles accents, and cascades to department',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final database = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 5,
          onCreate: (db, version) => DatabaseHelper.createV5Schema(db),
        ),
      );
      addTearDown(database.close);
      final repository = FacilityRepositoryImpl(
        remoteDataSource: _FakeFacilityRemoteDataSource(),
        localDataSource: FacilityLocalDataSource(
          dbHelper: DatabaseHelper.forDatabase(database),
        ),
        preferences: preferences,
        seedDataSource: const AssetFacilitySeedDataSource(),
      );

      final status = await repository.getCatalogStatus();
      expect(status.availableCount, greaterThanOrEqualTo(26));
      expect(status.lastUpdatedAt, isNull);

      final codazzi = await GetNearestFacilitiesUseCase(repository).execute(
        null,
        null,
        departamento: 'Cesar',
        municipio: 'Agustin Codazzi',
      );
      expect(codazzi, isNotEmpty);
      expect(
        codazzi.first.municipality,
        contains('Codazzi'),
      );

      final cascade = await GetNearestFacilitiesUseCase(repository).execute(
        null,
        null,
        departamento: 'Cesar',
        municipio: 'Municipio Inexistente',
        soloObstetricasOUrgencias: true,
      );
      expect(cascade, isNotEmpty);
      expect(cascade.every((f) => f.department == 'Cesar'), isTrue);
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
  DateTime? updatedAt,
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
    updatedAt: updatedAt,
  );
}

double _distanceMeters(
  double latitude1,
  double longitude1,
  double latitude2,
  double longitude2,
) {
  const earthRadiusMeters = 6371008.8;
  final latDelta = (latitude2 - latitude1) * math.pi / 180;
  final lngDelta =
      (((longitude2 - longitude1 + 540) % 360) - 180) * math.pi / 180;
  final haversine =
      math.pow(math.sin(latDelta / 2), 2) +
      math.cos(latitude1 * math.pi / 180) *
          math.cos(latitude2 * math.pi / 180) *
          math.pow(math.sin(lngDelta / 2), 2);
  final centralAngle = 2 * math.asin(math.sqrt(haversine.clamp(0.0, 1.0)));
  return earthRadiusMeters * centralAngle;
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
