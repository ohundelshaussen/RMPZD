import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/health_facility.dart';
import '../services/facility_link_launcher.dart';
import 'facility_action_buttons.dart';

class HealthFacilityListItem extends StatelessWidget {
  final HealthFacility facility;
  final FacilityLinkLauncher launcher;
  final int? number;
  final bool showDistance;
  final VoidCallback? onClose;

  const HealthFacilityListItem({
    required this.facility,
    required this.launcher,
    this.number,
    this.showDistance = true,
    this.onClose,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final services = <_ServiceTagData>[
      if (facility.emergency24h == true)
        const _ServiceTagData(
          'Urgencias 24 h',
          AppColors.emergencyRed,
          Color(0xFFFEE2E2),
        ),
      if (facility.obstetricCare == true)
        const _ServiceTagData(
          'Atención obstétrica',
          AppColors.primaryDark,
          Color(0xFFCCFBF1),
        ),
      if (facility.deliveryCare == true)
        const _ServiceTagData(
          'Parto',
          AppColors.primary,
          Color(0xFFE0F2F1),
        ),
      if (facility.adultIcu == true)
        const _ServiceTagData(
          'UCI',
          Color(0xFF0369A1),
          Color(0xFFE0F2FE),
        ),
      if (facility.verified != true)
        const _ServiceTagData(
          'Servicios sin confirmar',
          AppColors.textSecondary,
          AppColors.surfaceVariant,
        ),
      if (facility.verified == false)
        const _ServiceTagData(
          'Dato no verificado',
          AppColors.riskMedium,
          Color(0xFFFEF3C7),
        ),
    ];

    return Card(
      margin: EdgeInsets.only(bottom: onClose != null ? 0 : 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (number case final itemNumber?) ...[
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    foregroundColor: AppColors.primaryDark,
                    child: Text(
                      '$itemNumber',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
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
                      fontSize: 15,
                    ),
                  ),
                ),
                if (onClose case final closeCallback?)
                  IconButton(
                    tooltip: 'Cerrar detalle',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    onPressed: closeCallback,
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${facility.type ?? 'Tipo sin informar'} · '
              '${facility.careLevel == null ? 'Nivel no informado' : 'Nivel de atención ${facility.careLevel}'}',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            if (facility.municipality?.isNotEmpty == true ||
                facility.department?.isNotEmpty == true) ...[
              const SizedBox(height: 2),
              Text(
                [facility.municipality, facility.department]
                    .whereType<String>()
                    .where((value) => value.isNotEmpty)
                    .join(', '),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
              ),
            ],
            if (showDistance && facility.distanceKm != null) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.near_me_outlined,
                    size: 14,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '≈ ${facility.distanceKm!.toStringAsFixed(1).replaceAll('.', ',')} km en línea recta',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ],
              ),
            ],
            if (services.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final tag in services) _ServiceTag(tag: tag),
                ],
              ),
            ],
            const SizedBox(height: 10),
            FacilityActionButtons(facility: facility, launcher: launcher),
          ],
        ),
      ),
    );
  }
}

class _ServiceTagData {
  final String label;
  final Color textColor;
  final Color bgColor;

  const _ServiceTagData(this.label, this.textColor, this.bgColor);
}

class _ServiceTag extends StatelessWidget {
  final _ServiceTagData tag;

  const _ServiceTag({required this.tag});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tag.bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        tag.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: tag.textColor,
        ),
      ),
    );
  }
}
