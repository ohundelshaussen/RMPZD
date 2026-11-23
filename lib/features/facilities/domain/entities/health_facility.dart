class HealthFacility {
  final String id;
  final String? name;
  final String? type;
  final int? careLevel;
  final String? municipality;
  final String? department;
  final String? address;
  final String? phone;
  final double? latitude;
  final double? longitude;
  final bool? emergency24h;
  final bool? obstetricCare;
  final bool? deliveryCare;
  final bool? adultIcu;
  final String? repsCode;
  final String? source;
  final bool? verified;
  final String? observations;
  final bool? active;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final double? distanceKm;

  const HealthFacility({
    required this.id,
    this.name,
    this.type,
    this.careLevel,
    this.municipality,
    this.department,
    this.address,
    this.phone,
    this.latitude,
    this.longitude,
    this.emergency24h,
    this.obstetricCare,
    this.deliveryCare,
    this.adultIcu,
    this.repsCode,
    this.source,
    this.verified,
    this.observations,
    this.active,
    this.createdAt,
    this.updatedAt,
    this.distanceKm,
  });

  HealthFacility withDistanceKm(double value) => HealthFacility(
    id: id,
    name: name,
    type: type,
    careLevel: careLevel,
    municipality: municipality,
    department: department,
    address: address,
    phone: phone,
    latitude: latitude,
    longitude: longitude,
    emergency24h: emergency24h,
    obstetricCare: obstetricCare,
    deliveryCare: deliveryCare,
    adultIcu: adultIcu,
    repsCode: repsCode,
    source: source,
    verified: verified,
    observations: observations,
    active: active,
    createdAt: createdAt,
    updatedAt: updatedAt,
    distanceKm: value,
  );
}
