import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/clinical_alert.dart';
import '../../domain/entities/triage_result.dart';
import '../providers/triage_provider.dart';

class TriageResultPage extends StatelessWidget {
  const TriageResultPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TriageProvider>();
    final result = provider.currentResult;
    final patient = provider.currentPatient;

    if (result == null || patient == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Resultado del Triage')),
        body: const Center(child: Text('No hay evaluación disponible.')),
      );
    }

    Color badgeColor;
    Color badgeBg;
    IconData statusIcon;
    String statusTitle;
    String statusSubtitle;

    if (result.hasImmediateEmergency) {
      badgeColor = AppColors.emergencyRed;
      badgeBg = const Color(0xFFFEF2F2);
      statusIcon = Icons.emergency_rounded;
      statusTitle = 'CÓDIGO ROJO OBSTÉTRICO';
      statusSubtitle = 'Criterio clínico de emergencia inmediata activado';
    } else {
      switch (result.riskLevel) {
        case RiskLevel.alto:
          badgeColor = AppColors.riskHigh;
          badgeBg = const Color(0xFFFEF2F2);
          statusIcon = Icons.report_problem_rounded;
          statusTitle = 'ALTO RIESGO OBSTÉTRICO';
          statusSubtitle = 'Prioridad alta para remisión y valoración ginecológica';
          break;
        case RiskLevel.medio:
          badgeColor = AppColors.riskMedium;
          badgeBg = const Color(0xFFFFFBEB);
          statusIcon = Icons.info_outline_rounded;
          statusTitle = 'RIESGO MODERADO';
          statusSubtitle = 'Requiere seguimiento prenatal estricto en puesto de salud';
          break;
        case RiskLevel.bajo:
          badgeColor = AppColors.riskLow;
          badgeBg = const Color(0xFFF0FDF4);
          statusIcon = Icons.check_circle_rounded;
          statusTitle = 'BAJO RIESGO';
          statusSubtitle = 'Parámetros gestacionales y hemodinámicos estables';
          break;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dictamen de Triage'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Banner Principal de Estado
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: badgeColor.withValues(alpha: 0.3), width: 1.2),
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
            ),
            const SizedBox(height: 16),

            // Card de Inferencia IA y Probabilidades
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.auto_awesome_rounded, size: 18, color: AppColors.primary),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Estimación de Modelos de IA',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildProbBar(
                      'Alto Riesgo',
                      result.probAlto,
                      AppColors.riskHigh,
                      threshold: 0.25,
                    ),
                    const SizedBox(height: 10),
                    _buildProbBar(
                      'Riesgo Moderado',
                      result.probMedio,
                      AppColors.riskMedium,
                    ),
                    const SizedBox(height: 10),
                    _buildProbBar(
                      'Bajo Riesgo',
                      result.probBajo,
                      AppColors.riskLow,
                    ),
                    const Divider(height: 24, color: Color(0xFFF1F5F9)),

                    // Desenlace Adverso (Layout vertical/flex para evitar overflow horizontal)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Desenlace Gestacional Estimado:',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: result.riesgoDesenlaceAdverso
                                ? const Color(0xFFFEE2E2)
                                : const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                result.riesgoDesenlaceAdverso
                                    ? Icons.warning_amber_rounded
                                    : Icons.check_circle_outline_rounded,
                                size: 16,
                                color: result.riesgoDesenlaceAdverso
                                    ? AppColors.riskHigh
                                    : AppColors.riskLow,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                result.riesgoDesenlaceAdverso
                                    ? 'Posible Complicación Obstétrica (${(result.probDesenlaceAdverso * 100).toStringAsFixed(1)}%)'
                                    : 'Desenlace Normal / Estable (${(result.probDesenlaceAdverso * 100).toStringAsFixed(1)}%)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: result.riesgoDesenlaceAdverso
                                      ? AppColors.riskHigh
                                      : AppColors.riskLow,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Reglas Clínicas Obstétricas
            if (result.clinicalAlerts.isNotEmpty) ...[
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
              ...result.clinicalAlerts.map((alert) => _buildAlertCard(alert)),
              const SizedBox(height: 16),
            ],

            // Botones de Acción
            ElevatedButton.icon(
              icon: const Icon(Icons.check_rounded, size: 20),
              label: const Text('GUARDAR EN REGISTRO LOCAL'),
              onPressed: () async {
                final success = await provider.saveCurrentAssessment();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: success ? AppColors.primary : AppColors.riskHigh,
                      content: Text(
                        success
                            ? 'Consulta registrada en base de datos local SQLite.'
                            : 'Error al registrar consulta.',
                      ),
                    ),
                  );
                  if (success) {
                    Navigator.pop(context);
                  }
                }
              },
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Descartar y Volver al Formulario',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildProbBar(
    String label,
    double prob,
    Color color, {
    double? threshold,
  }) {
    final percentage = (prob * 100).toStringAsFixed(1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                threshold != null ? '$label (Umbral ${(threshold * 100).toInt()}%)' : label,
                style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '$percentage%',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: prob.clamp(0.0, 1.0),
            backgroundColor: const Color(0xFFF1F5F9),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildAlertCard(ClinicalAlert alert) {
    Color alertColor;
    IconData icon;

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
              style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, height: 1.3),
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
                  const Icon(Icons.arrow_right_alt_rounded, size: 16, color: AppColors.primary),
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
