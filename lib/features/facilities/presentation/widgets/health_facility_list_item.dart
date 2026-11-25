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
  final double? originLatitude;
  final double? originLongitude;
  final VoidCallback? onRefer;

  const HealthFacilityListItem({
    required this.facility,
    required this.launcher,
    this.number,
    this.showDistance = true,
    this.onClose,
    this.originLatitude,
    this.originLongitude,
    this.onRefer,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isNearest = showDistance && number == 1;
    final isOverlayCard = onClose != null;

    final services = <_ServiceTagData>[
      if (facility.emergency24h == true)
        const _ServiceTagData('Urgencias 24 h', emphasized: true),
      if (facility.obstetricCare == true)
        const _ServiceTagData('Atención obstétrica', emphasized: true),
      if (facility.deliveryCare == true) const _ServiceTagData('Parto'),
      if (facility.adultIcu == true) const _ServiceTagData('UCI'),
      if (facility.verified != true)
        const _ServiceTagData('Servicios sin confirmar', muted: true),
      if (facility.verified == false)
        const _ServiceTagData(
          'Dato no verificado',
          muted: true,
          dotColor: AppColors.riskMedium,
        ),
    ];

    final cardColor = isOverlayCard || isNearest
        ? AppColors.surface
        : AppColors.background;
    final borderColor = isNearest
        ? AppColors.primary.withValues(alpha: 0.35)
        : AppColors.border;

    return Card(
      elevation: isOverlayCard ? 2 : 0,
      color: cardColor,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.only(bottom: isOverlayCard ? 0 : 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: borderColor, width: 1),
      ),
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
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isNearest
                          ? AppColors.primary.withValues(alpha: 0.12)
                          : AppColors.surfaceVariant,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$itemNumber',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isNearest
                            ? AppColors.primaryDark
                            : AppColors.textSecondary,
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
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                      color: AppColors.textPrimary,
                      height: 1.25,
                    ),
                  ),
                ),
                if (isNearest) ...[
                  const SizedBox(width: 8),
                  Container(
                    key: const ValueKey('nearest-facility-label'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.25),
                      ),
                    ),
                    child: const Text(
                      'Más cercano',
                      style: TextStyle(
                        color: AppColors.primaryDark,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
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
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              '${facility.type ?? 'Tipo sin informar'} · '
              '${facility.careLevel == null ? 'Nivel no informado' : 'Nivel de atención ${facility.careLevel}'}',
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (facility.municipality?.isNotEmpty == true ||
                facility.department?.isNotEmpty == true) ...[
              const SizedBox(height: 2),
              Text(
                [facility.municipality, facility.department]
                    .whereType<String>()
                    .where((value) => value.isNotEmpty)
                    .join(', '),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
            if (showDistance && facility.distanceKm != null) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.near_me_outlined,
                    size: 13.5,
                    color: isNearest ? AppColors.primary : AppColors.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '≈ ${facility.distanceKm!.toStringAsFixed(1).replaceAll('.', ',')} km en línea recta',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: isNearest
                          ? AppColors.primaryDark
                          : AppColors.textSecondary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ],
            if (services.isNotEmpty) ...[
              const SizedBox(height: 9),
              Wrap(
                spacing: 6,
                runSpacing: 5,
                children: [for (final tag in services) _ServiceTag(tag: tag)],
              ),
            ],
            const SizedBox(height: 11),
            FacilityActionButtons(
              facility: facility,
              launcher: launcher,
              originLatitude: originLatitude,
              originLongitude: originLongitude,
            ),
            if (onRefer != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onRefer,
                  icon: const Icon(Icons.reply_all_rounded, size: 18),
                  label: const Text('Remitir a este centro'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ServiceTagData {
  final String label;
  final bool emphasized;
  final bool muted;
  final Color? dotColor;

  const _ServiceTagData(
    this.label, {
    this.emphasized = false,
    this.muted = false,
    this.dotColor,
  });
}

class _ServiceTag extends StatelessWidget {
  final _ServiceTagData tag;

  const _ServiceTag({required this.tag});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tag.muted ? AppColors.surfaceVariant : AppColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (tag.dotColor case final dotColor?) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            tag.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: tag.emphasized ? FontWeight.w600 : FontWeight.w500,
              color: tag.muted
                  ? AppColors.textMuted
                  : (tag.emphasized
                        ? AppColors.textPrimary
                        : AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
