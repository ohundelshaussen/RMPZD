import 'package:flutter/material.dart';

import '../../domain/entities/health_facility.dart';
import '../services/facility_link_launcher.dart';
import 'facility_action_buttons.dart';

class HealthFacilityListItem extends StatelessWidget {
  final HealthFacility facility;
  final FacilityLinkLauncher launcher;
  final int? number;
  final bool showDistance;

  const HealthFacilityListItem({
    required this.facility,
    required this.launcher,
    this.number,
    this.showDistance = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final services = <String>[
      if (facility.emergency24h == true) 'Urgencias 24 h',
      if (facility.obstetricCare == true) 'Atención obstétrica',
      if (facility.deliveryCare == true) 'Parto',
      if (facility.adultIcu == true) 'UCI',
      if (facility.verified != true) 'Servicios sin confirmar',
      if (facility.verified == false) 'Dato no verificado',
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (number case final itemNumber?) ...[
                  CircleAvatar(
                    radius: 14,
                    child: Text(
                      '$itemNumber',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    facility.name?.trim().isNotEmpty == true
                        ? facility.name!
                        : 'Centro de salud',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${facility.type ?? 'Tipo sin informar'} · '
              '${facility.careLevel == null ? 'Nivel no informado' : 'Nivel de atención ${facility.careLevel}'}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (facility.municipality?.isNotEmpty == true ||
                facility.department?.isNotEmpty == true) ...[
              const SizedBox(height: 2),
              Text(
                [facility.municipality, facility.department]
                    .whereType<String>()
                    .where((value) => value.isNotEmpty)
                    .join(', '),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (showDistance && facility.distanceKm != null) ...[
              const SizedBox(height: 6),
              Text(
                '≈ ${facility.distanceKm!.toStringAsFixed(1).replaceAll('.', ',')} km en línea recta',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
            if (services.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final service in services)
                    Chip(
                      label: Text(service),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            FacilityActionButtons(facility: facility, launcher: launcher),
          ],
        ),
      ),
    );
  }
}
