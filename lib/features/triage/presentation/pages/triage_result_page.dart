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

    Color headerColor;
    IconData headerIcon;
    String statusTitle;

    if (result.hasImmediateEmergency) {
      headerColor = AppColors.emergencyRed;
      headerIcon = Icons.warning_rounded;
      statusTitle = '¡ALERTA ROJA OBSTÉTRICA INMEDIATA!';
    } else {
      switch (result.riskLevel) {
        case RiskLevel.alto:
          headerColor = AppColors.riskHigh;
          headerIcon = Icons.report_problem_rounded;
          statusTitle = 'ALTO RIESGO MATERNO-PERINATAL';
          break;
        case RiskLevel.medio:
          headerColor = AppColors.riskMedium;
          headerIcon = Icons.info_outline_rounded;
          statusTitle = 'RIESGO MODERADO - SEGUIMIENTO';
          break;
        case RiskLevel.bajo:
          headerColor = AppColors.riskLow;
          headerIcon = Icons.check_circle_outline_rounded;
          statusTitle = 'BAJO RIESGO OBSTÉTRICO';
          break;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dictamen de Alerta Temprana'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Exportar o compartir reporte',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Reporte clínico preparado para remisión.'),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: headerColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: headerColor.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(headerIcon, size: 48, color: Colors.white),
                  const SizedBox(height: 12),
                  Text(
                    statusTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Gestante: ${patient.patientId} • ${patient.etnia} (${patient.municipio})',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Emergency Notice if applicable
            if (result.hasImmediateEmergency) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Icon(Icons.emergency, color: AppColors.emergencyRed, size: 28),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Criterio obstétrico inflexible activado por crisis hemodinámica. Se sobrepone a cualquier probabilidad estadística.',
                        style: TextStyle(
                          color: Color(0xFF991B1B),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Model Probabilities
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.psychology_outlined, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text(
                          'Probabilidades del Modelo Supervisado',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildProbBar(
                      'Probabilidad Alto Riesgo',
                      result.probAlto,
                      AppColors.riskHigh,
                      thresholdMarker: 0.25,
                    ),
                    const SizedBox(height: 12),
                    _buildProbBar(
                      'Probabilidad Riesgo Medio',
                      result.probMedio,
                      AppColors.riskMedium,
                    ),
                    const SizedBox(height: 12),
                    _buildProbBar(
                      'Probabilidad Bajo Riesgo',
                      result.probBajo,
                      AppColors.riskLow,
                    ),
                    const Divider(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Desenlace Adverso Estimado:',
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: result.riesgoDesenlaceAdverso
                                ? const Color(0xFFFEE2E2)
                                : const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            result.riesgoDesenlaceAdverso
                                ? 'Alto Riesgo (${(result.probDesenlaceAdverso * 100).toStringAsFixed(1)}%)'
                                : 'Normal / Estable (${(result.probDesenlaceAdverso * 100).toStringAsFixed(1)}%)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: result.riesgoDesenlaceAdverso
                                  ? AppColors.riskHigh
                                  : AppColors.riskLow,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Clinical Alerts
            if (result.clinicalAlerts.isNotEmpty) ...[
              const Text(
                'Signos de Alarma y Reglas Clínicas Detectadas',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              ...result.clinicalAlerts.map((alert) => _buildAlertCard(alert)),
              const SizedBox(height: 20),
            ],

            // Action Buttons
            ElevatedButton.icon(
              icon: const Icon(Icons.save_outlined),
              label: const Text('Guardar Consulta en Registro Local'),
              onPressed: () async {
                final success = await provider.saveCurrentAssessment();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor:
                          success ? AppColors.primary : AppColors.riskHigh,
                      content: Text(
                        success
                            ? 'Consulta guardada con éxito en la base de datos local SQLite.'
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
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Realizar Nueva Evaluación'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildProbBar(
    String label,
    double prob,
    Color color, {
    double? thresholdMarker,
  }) {
    final percentage = (prob * 100).toStringAsFixed(1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            Text('$percentage%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: prob.clamp(0.0, 1.0),
            backgroundColor: AppColors.surfaceVariant,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildAlertCard(ClinicalAlert alert) {
    Color borderColor;
    Color iconColor;

    switch (alert.severity) {
      case AlertSeverity.immediateEmergency:
        borderColor = AppColors.emergencyRed;
        iconColor = AppColors.emergencyRed;
        break;
      case AlertSeverity.warning:
        borderColor = AppColors.riskMedium;
        iconColor = AppColors.riskMedium;
        break;
      case AlertSeverity.informational:
        borderColor = AppColors.primary;
        iconColor = AppColors.primary;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: borderColor, width: 4)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.report_gmailerrorred_rounded, size: 20, color: iconColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  alert.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            alert.description,
            style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    alert.actionRequired,
                    style: const TextStyle(
                      fontSize: 12,
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
    );
  }
}
