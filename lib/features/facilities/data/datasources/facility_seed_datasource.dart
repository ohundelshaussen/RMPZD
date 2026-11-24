import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../models/health_facility_model.dart';

abstract interface class FacilitySeedDataSource {
  Future<List<HealthFacilityModel>> loadSeedFacilities();
}

class AssetFacilitySeedDataSource implements FacilitySeedDataSource {
  static const defaultAssetPath = 'assets/data/health_facilities_seed.json';

  final AssetBundle? bundle;
  final String assetPath;

  const AssetFacilitySeedDataSource({
    this.bundle,
    this.assetPath = defaultAssetPath,
  });

  @override
  Future<List<HealthFacilityModel>> loadSeedFacilities() async {
    final jsonString = await (bundle ?? rootBundle).loadString(assetPath);
    final decoded = jsonDecode(jsonString);
    if (decoded is! List) {
      throw const FormatException(
        'El catálogo semilla de centros de salud no es una lista JSON válida.',
      );
    }
    return decoded
        .map(
          (entry) =>
              HealthFacilityModel.fromJson(Map<String, dynamic>.from(entry as Map)),
        )
        .toList(growable: false);
  }
}
