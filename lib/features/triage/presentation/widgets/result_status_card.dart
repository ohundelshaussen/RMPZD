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

    if (result.hasImmediateEmergency) {
      badgeColor = AppColors.emergencyRed;
      badgeBackground = const Color(0xFFFEF2F2);
      statusIcon = Icons.emergency_rounded;
      statusTitle = 'CÓDIGO ROJO OBSTÉTRICO';
      statusSubtitle = 'Criterio clínico de emergencia inmediata activado';
    } else {
      switch (result.riskLevel) {
        case RiskLevel.alto:
          badgeColor = AppColors.riskHigh;
          badgeBackground = const Color(0xFFFEF2F2);
          statusIcon = Icons.report_problem_rounded;
          statusTitle = 'ALTO RIESGO OBSTÉTRICO';
          statusSubtitle =
              'Prioridad alta para remisión y valoración ginecológica';
          break;
        case RiskLevel.medio:
          badgeColor = AppColors.riskMedium;
          badgeBackground = const Color(0xFFFFFBEB);
          statusIcon = Icons.info_outline_rounded;
          statusTitle = 'RIESGO MODERADO';
          statusSubtitle =
              'Requiere seguimiento prenatal estricto en puesto de salud';
          break;
        case RiskLevel.bajo:
          badgeColor = AppColors.riskLow;
          badgeBackground = const Color(0xFFF0FDF4);
          statusIcon = Icons.check_circle_rounded;
          statusTitle = 'BAJO RIESGO';
          statusSubtitle = 'Parámetros gestacionales y hemodinámicos estables';
          break;
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: badgeBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: badgeColor.withValues(alpha: 0.3),
          width: 1.2,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(statusIcon, size: 36, color: badgeColor),
          ),
          const SizedBox(height: 12),
          Text(
            statusTitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: badgeColor,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            statusSubtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              '${patient.patientId} • ${patient.etnia} • ${patient.municipio}',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
