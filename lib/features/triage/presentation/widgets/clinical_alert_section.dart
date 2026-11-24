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
          padding: EdgeInsets.only(left: 2, bottom: 8),
          child: Text(
            'Alertas y Recomendaciones Clínicas',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.1,
            ),
          ),
        ),
        ...alerts.map((alert) => ClinicalAlertCard(alert: alert)),
        const SizedBox(height: 6),
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
    late final Color cardBackground;
    late final Color borderColor;
    late final IconData icon;

    switch (alert.severity) {
      case AlertSeverity.immediateEmergency:
        alertColor = AppColors.emergencyRed;
        cardBackground = const Color(0xFFFFFAFA);
        borderColor = AppColors.emergencyRed.withValues(alpha: 0.28);
        icon = Icons.warning_rounded;
        break;
      case AlertSeverity.warning:
        alertColor = AppColors.riskMedium;
        cardBackground = AppColors.surface;
        borderColor = AppColors.border;
        icon = Icons.info_outline_rounded;
        break;
      case AlertSeverity.informational:
        alertColor = AppColors.primary;
        cardBackground = AppColors.surface;
        borderColor = AppColors.border;
        icon = Icons.notifications_none_rounded;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: alertColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(icon, size: 17, color: alertColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              alert.title,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color:
                                    alert.severity ==
                                        AlertSeverity.informational
                                    ? AppColors.textPrimary
                                    : alertColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        alert.description,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textPrimary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.arrow_right_alt_rounded,
                              size: 16,
                              color: alertColor,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                alert.actionRequired,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
