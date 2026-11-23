import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/facility_catalog_status.dart';
import '../../domain/entities/health_facility.dart';
import '../../domain/repositories/facility_repository.dart';
import '../datasources/facility_local_datasource.dart';
import '../datasources/facility_remote_datasource.dart';
import '../models/health_facility_model.dart';

class FacilityRepositoryImpl implements FacilityRepository {
  static const _cursorKey = 'health_facilities_updated_at_cursor';
  static const _pageSize = 500;
  static const _earthRadiusKm = 6371.0088;

  final FacilityRemoteDataSource remoteDataSource;
  final FacilityLocalDataSource localDataSource;
  final SharedPreferences preferences;

  const FacilityRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.preferences,
  });

  @override
  Future<int> syncFacilities() async {
    final storedCursor = preferences.getString(_cursorKey);
    final cursor = storedCursor == null
        ? null
        : DateTime.parse(storedCursor).toUtc();
    var newestUpdatedAt = cursor;
    var offset = 0;
    var received = 0;

    while (true) {
      final rows = await remoteDataSource.fetchFacilities(
        updatedAfter: cursor,
        offset: offset,
        limit: _pageSize,
      );
      if (rows.isEmpty) break;

      final facilities = rows
          .map(HealthFacilityModel.fromJson)
          .toList(growable: false);
      await localDataSource.applyFacilities(facilities);
      received += facilities.length;
      offset += _pageSize;

      for (final facility in facilities) {
        final updatedAt = facility.updatedAt?.toUtc();
        if (updatedAt != null &&
            (newestUpdatedAt == null || updatedAt.isAfter(newestUpdatedAt))) {
          newestUpdatedAt = updatedAt;
        }
      }

      if (rows.length < _pageSize) break;
    }

    if (newestUpdatedAt != null &&
        (cursor == null || newestUpdatedAt.isAfter(cursor))) {
      final saved = await preferences.setString(
        _cursorKey,
        newestUpdatedAt.toUtc().toIso8601String(),
      );
      if (!saved) {
        throw StateError('No se pudo guardar el cursor del catálogo.');
      }
    }
    return received;
  }

  @override
  Future<FacilityCatalogStatus> getCatalogStatus() async {
    final count = await localDataSource.countActiveFacilities();
    final cursorValue = preferences.getString(_cursorKey);
    return FacilityCatalogStatus(
      availableCount: count,
      lastUpdatedAt: cursorValue == null
          ? null
          : DateTime.parse(cursorValue).toUtc(),
    );
  }

  @override
  Future<List<HealthFacility>> getNearestFacilities(
    double? latitude,
    double? longitude, {
    int limit = 5,
    bool soloObstetricas = false,
    bool soloUrgencias = false,
    bool soloObstetricasOUrgencias = false,
    String? departamento,
    String? municipio,
  }) async {
    if (limit <= 0) return const [];
    final departmentFilter = _normalized(departamento);
    final municipalityFilter = _normalized(municipio);
    final territorialSearch =
        departmentFilter != null || municipalityFilter != null;

    if (territorialSearch) {
      final facilities = await _filteredFacilities(
        soloObstetricas: soloObstetricas,
        soloUrgencias: soloUrgencias,
        soloObstetricasOUrgencias: soloObstetricasOUrgencias,
        department: departmentFilter,
        municipality: municipalityFilter,
      );
      facilities.sort(_compareByName);
      return facilities.take(limit).toList(growable: false);
    }

    if (latitude == null || longitude == null) {
      throw ArgumentError('Indique coordenadas o un territorio.');
    }
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      throw ArgumentError('Las coordenadas no son válidas.');
    }

    final facilities = await _filteredFacilities(
      soloObstetricas: soloObstetricas,
      soloUrgencias: soloUrgencias,
      soloObstetricasOUrgencias: soloObstetricasOUrgencias,
    );
    final located = facilities
        .where(
          (facility) =>
              facility.latitude != null &&
              facility.longitude != null &&
              facility.latitude!.isFinite &&
              facility.longitude!.isFinite &&
              facility.latitude! >= -90 &&
              facility.latitude! <= 90 &&
              facility.longitude! >= -180 &&
              facility.longitude! <= 180,
        )
        .toList(growable: false);
    if (located.isEmpty) return const [];

    var radiusKm = 50.0;
    final maximumRadiusKm = math.pi * _earthRadiusKm;
    while (true) {
      final inBox =
          located
              .where(
                (facility) => _withinBoundingBox(
                  facility.latitude!,
                  facility.longitude!,
                  latitude,
                  longitude,
                  radiusKm,
                ),
              )
              .map(
                (facility) => facility.withDistanceKm(
                  _haversineKm(
                    latitude,
                    longitude,
                    facility.latitude!,
                    facility.longitude!,
                  ),
                ),
              )
              .toList(growable: false)
            ..sort(_compareByDistance);

      if (radiusKm >= maximumRadiusKm ||
          inBox.length >= limit && inBox[limit - 1].distanceKm! < radiusKm) {
        return inBox.take(limit).toList(growable: false);
      }
      radiusKm = math.min(radiusKm * 2, maximumRadiusKm);
    }
  }

  Future<List<HealthFacility>> _filteredFacilities({
    required bool soloObstetricas,
    required bool soloUrgencias,
    required bool soloObstetricasOUrgencias,
    String? department,
    String? municipality,
  }) async {
    final facilities = await localDataSource.getActiveFacilities();
    return facilities.where((facility) {
      if (soloObstetricas &&
          facility.verified == true &&
          facility.obstetricCare != true) {
        return false;
      }
      if (soloUrgencias &&
          facility.verified == true &&
          facility.emergency24h != true) {
        return false;
      }
      if (soloObstetricasOUrgencias &&
          facility.verified == true &&
          facility.obstetricCare != true &&
          facility.emergency24h != true) {
        return false;
      }
      if (department != null &&
          _normalized(facility.department) != department) {
        return false;
      }
      if (municipality != null &&
          _normalized(facility.municipality) != municipality) {
        return false;
      }
      return true;
    }).toList();
  }

  static bool _withinBoundingBox(
    double facilityLatitude,
    double facilityLongitude,
    double latitude,
    double longitude,
    double radiusKm,
  ) {
    final angularRadius = math.min(radiusKm / _earthRadiusKm, math.pi);
    final latitudeDelta = angularRadius * 180 / math.pi;
    final south = math.max(-90.0, latitude - latitudeDelta);
    final north = math.min(90.0, latitude + latitudeDelta);
    if (facilityLatitude < south || facilityLatitude > north) return false;
    if (angularRadius >= math.pi) return true;

    final maxAbsLatitude = math.max(south.abs(), north.abs()) * math.pi / 180;
    final cosLatitude = math.cos(maxAbsLatitude);
    final longitudeDelta = cosLatitude <= 0
        ? 180.0
        : 2 *
              math.asin(
                math.min(1.0, math.sin(angularRadius / 2) / cosLatitude),
              ) *
              180 /
              math.pi;
    final longitudeDifference =
        ((facilityLongitude - longitude + 540) % 360) - 180;
    return longitudeDifference.abs() <= longitudeDelta;
  }

  static double _haversineKm(
    double latitude1,
    double longitude1,
    double latitude2,
    double longitude2,
  ) {
    final latitudeDelta = (latitude2 - latitude1) * math.pi / 180;
    final longitudeDelta =
        (((longitude2 - longitude1 + 540) % 360) - 180) * math.pi / 180;
    final haversine =
        math.pow(math.sin(latitudeDelta / 2), 2) +
        math.cos(latitude1 * math.pi / 180) *
            math.cos(latitude2 * math.pi / 180) *
            math.pow(math.sin(longitudeDelta / 2), 2);
    final centralAngle = 2 * math.asin(math.sqrt(haversine.clamp(0.0, 1.0)));
    return _earthRadiusKm * centralAngle;
  }

  static String? _normalized(String? value) {
    final normalized = value?.trim().toLowerCase();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  static int _compareByName(HealthFacility left, HealthFacility right) {
    final byName = (left.name ?? '').compareTo(right.name ?? '');
    return byName != 0 ? byName : left.id.compareTo(right.id);
  }

  static int _compareByDistance(HealthFacility left, HealthFacility right) {
    final byDistance = left.distanceKm!.compareTo(right.distanceKm!);
    return byDistance != 0 ? byDistance : left.id.compareTo(right.id);
  }
}
