import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/clinical_alert.dart';

class ClinicalAlertSection extends StatelessWidget {
  final List<ClinicalAlert> alerts;

  const ClinicalAlertSection({required this.alerts, super.key});

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Alertas y Recomendaciones Clínicas',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        ...alerts.map((alert) => ClinicalAlertCard(alert: alert)),
        const SizedBox(height: 16),
      ],
    );
  }
}

class ClinicalAlertCard extends StatelessWidget {
  final ClinicalAlert alert;

  const ClinicalAlertCard({required this.alert, super.key});

  @override
  Widget build(BuildContext context) {
    late final Color alertColor;
    late final IconData icon;

    switch (alert.severity) {
      case AlertSeverity.immediateEmergency:
        alertColor = AppColors.emergencyRed;
        icon = Icons.warning_rounded;
        break;
      case AlertSeverity.warning:
        alertColor = AppColors.riskMedium;
        icon = Icons.info_outline_rounded;
        break;
      case AlertSeverity.informational:
        alertColor = AppColors.primary;
        icon = Icons.notifications_none_rounded;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: alertColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    alert.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: alertColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              alert.description,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textPrimary,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.arrow_right_alt_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      alert.actionRequired,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
