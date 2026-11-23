import '../../domain/entities/health_facility.dart';

class HealthFacilityModel extends HealthFacility {
  const HealthFacilityModel({
    required super.id,
    super.name,
    super.type,
    super.careLevel,
    super.municipality,
    super.department,
    super.address,
    super.phone,
    super.latitude,
    super.longitude,
    super.emergency24h,
    super.obstetricCare,
    super.deliveryCare,
    super.adultIcu,
    super.repsCode,
    super.source,
    super.verified,
    super.observations,
    super.active,
    super.createdAt,
    super.updatedAt,
  });

  factory HealthFacilityModel.fromEntity(HealthFacility facility) {
    return HealthFacilityModel(
      id: facility.id,
      name: facility.name,
      type: facility.type,
      careLevel: facility.careLevel,
      municipality: facility.municipality,
      department: facility.department,
      address: facility.address,
      phone: facility.phone,
      latitude: facility.latitude,
      longitude: facility.longitude,
      emergency24h: facility.emergency24h,
      obstetricCare: facility.obstetricCare,
      deliveryCare: facility.deliveryCare,
      adultIcu: facility.adultIcu,
      repsCode: facility.repsCode,
      source: facility.source,
      verified: facility.verified,
      observations: facility.observations,
      active: facility.active,
      createdAt: facility.createdAt,
      updatedAt: facility.updatedAt,
    );
  }

  factory HealthFacilityModel.fromJson(Map<String, dynamic> json) {
    return HealthFacilityModel(
      id: _requiredString(json, 'id'),
      name: json['nombre'] as String?,
      type: json['tipo'] as String?,
      careLevel: (json['nivel_atencion'] as num?)?.toInt(),
      municipality: json['municipio'] as String?,
      department: json['departamento'] as String?,
      address: json['direccion'] as String?,
      phone: json['telefono'] as String?,
      latitude: (json['latitud'] as num?)?.toDouble(),
      longitude: (json['longitud'] as num?)?.toDouble(),
      emergency24h: _boolValue(json['urgencias_24h']),
      obstetricCare: _boolValue(json['atencion_obstetrica']),
      deliveryCare: _boolValue(json['atencion_parto']),
      adultIcu: _boolValue(json['uci_adultos']),
      repsCode: json['codigo_reps'] as String?,
      source: json['fuente'] as String?,
      verified: _boolValue(json['verificado']),
      observations: json['observaciones'] as String?,
      active: _boolValue(json['activo']),
      createdAt: _dateValue(json['created_at']),
      updatedAt: _dateValue(json['updated_at']),
    );
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'nombre': name,
    'tipo': type,
    'nivel_atencion': careLevel,
    'municipio': municipality,
    'departamento': department,
    'direccion': address,
    'telefono': phone,
    'latitud': latitude,
    'longitud': longitude,
    'urgencias_24h': _boolToInt(emergency24h),
    'atencion_obstetrica': _boolToInt(obstetricCare),
    'atencion_parto': _boolToInt(deliveryCare),
    'uci_adultos': _boolToInt(adultIcu),
    'codigo_reps': repsCode,
    'fuente': source,
    'verificado': _boolToInt(verified),
    'observaciones': observations,
    'activo': _boolToInt(active),
    'created_at': createdAt?.toUtc().toIso8601String(),
    'updated_at': updatedAt?.toUtc().toIso8601String(),
  };

  factory HealthFacilityModel.fromMap(Map<String, dynamic> map) =>
      HealthFacilityModel.fromJson(map);

  static String _requiredString(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException(
        'El campo "$key" del centro de salud no es válido.',
      );
    }
    return value;
  }

  static bool? _boolValue(Object? value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is int && (value == 0 || value == 1)) return value == 1;
    throw const FormatException(
      'Un indicador del centro de salud no es válido.',
    );
  }

  static int? _boolToInt(bool? value) => value == null ? null : (value ? 1 : 0);

  static DateTime? _dateValue(Object? value) {
    if (value == null) return null;
    if (value is! String) {
      throw const FormatException(
        'Una fecha del centro de salud no es válida.',
      );
    }
    return DateTime.parse(value);
  }
}
