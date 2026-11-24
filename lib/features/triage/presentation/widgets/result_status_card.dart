import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/patient_assessment.dart';
import '../../domain/entities/triage_result.dart';

class ResultStatusCard extends StatelessWidget {
  final PatientAssessment patient;
  final TriageResult result;

  const ResultStatusCard({
    required this.patient,
    required this.result,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    late final Color badgeColor;
    late final Color badgeBackground;
    late final IconData statusIcon;
    late final String statusTitle;
    late final String statusSubtitle;
    late final bool solidIconFill;

    if (result.hasImmediateEmergency) {
      badgeColor = AppColors.emergencyRed;
      badgeBackground = const Color(0xFFFEF2F2);
      statusIcon = Icons.emergency_rounded;
      statusTitle = 'CÓDIGO ROJO OBSTÉTRICO';
      statusSubtitle = 'Criterio clínico de emergencia inmediata activado';
      solidIconFill = true;
    } else {
      switch (result.riskLevel) {
        case RiskLevel.alto:
          badgeColor = AppColors.riskHigh;
          badgeBackground = const Color(0xFFFEF2F2);
          statusIcon = Icons.report_problem_rounded;
          statusTitle = 'ALTO RIESGO OBSTÉTRICO';
          statusSubtitle =
              'Prioridad alta para remisión y valoración ginecológica';
          solidIconFill = true;
          break;
        case RiskLevel.medio:
          badgeColor = AppColors.riskMedium;
          badgeBackground = const Color(0xFFFFFBEB);
          statusIcon = Icons.info_outline_rounded;
          statusTitle = 'RIESGO MODERADO';
          statusSubtitle =
              'Requiere seguimiento prenatal estricto en puesto de salud';
          solidIconFill = false;
          break;
        case RiskLevel.bajo:
          badgeColor = AppColors.riskLow;
          badgeBackground = const Color(0xFFF0FDF4);
          statusIcon = Icons.check_circle_rounded;
          statusTitle = 'BAJO RIESGO';
          statusSubtitle = 'Parámetros gestacionales y hemodinámicos estables';
          solidIconFill = false;
          break;
      }
    }

    final trimmedName = patient.nombrePaciente?.trim() ?? '';
    final identitySummary = trimmedName.isNotEmpty
        ? '$trimmedName • ${patient.patientId} • ${patient.municipio}'
        : '${patient.patientId} • ${patient.etnia} • ${patient.municipio}';

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: badgeBackground,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: badgeColor.withValues(alpha: 0.32),
            width: 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(height: 4, color: badgeColor),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: solidIconFill
                          ? badgeColor
                          : badgeColor.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      statusIcon,
                      size: 32,
                      color: solidIconFill ? Colors.white : badgeColor,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    statusTitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: badgeColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    statusSubtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Divider(
                    height: 1,
                    color: badgeColor.withValues(alpha: 0.16),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.person_outline_rounded,
                        size: 15,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          identitySummary,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
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
