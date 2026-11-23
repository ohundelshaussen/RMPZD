import 'package:flutter/material.dart';

import '../../../triage/domain/entities/triage_result.dart';
import 'nearest_facilities_section.dart';

class RiskFacilitiesRecommendations extends StatelessWidget {
  final RiskLevel riskLevel;
  final double? latitude;
  final double? longitude;
  final String? department;
  final String? municipality;

  const RiskFacilitiesRecommendations({
    required this.riskLevel,
    required this.latitude,
    required this.longitude,
    required this.department,
    required this.municipality,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (riskLevel == RiskLevel.bajo) return const SizedBox.shrink();
    final isHighRisk = riskLevel == RiskLevel.alto;
    return NearestFacilitiesSection(
      latitude: latitude,
      longitude: longitude,
      department: department,
      municipality: municipality,
      highRisk: isHighRisk,
      initiallyExpanded: isHighRisk,
    );
  }
}
