import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../history/presentation/providers/history_provider.dart';
import '../../../facilities/presentation/widgets/risk_facilities_recommendations.dart';
import '../providers/triage_provider.dart';
import '../widgets/ai_probability_card.dart';
import '../widgets/clinical_alert_section.dart';
import '../widgets/consultation_code_card.dart';
import '../widgets/result_status_card.dart';

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

    void startNewEvaluation() {
      if (Navigator.canPop(context)) {
        Navigator.pop(context, true);
      }
      provider.reset();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Dictamen de Triage')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ResultStatusCard(patient: patient, result: result),
                const SizedBox(height: 16),
                AiProbabilityCard(result: result),
                const SizedBox(height: 16),
                ClinicalAlertSection(alerts: result.clinicalAlerts),
                const SizedBox(height: 16),
                RiskFacilitiesRecommendations(
                  riskLevel: result.riskLevel,
                  latitude: patient.latitud,
                  longitude: patient.longitud,
                  department: patient.departamento,
                  municipality: patient.municipio,
                ),
                if (provider.isSaved) ...[
                  if (provider.savedAssessment?.consultationCode
                      case final consultationCode?) ...[
                    ConsultationCodeCard(code: consultationCode),
                    const SizedBox(height: 16),
                  ],
                  ElevatedButton.icon(
                    icon: const Icon(
                      Icons.add_circle_outline_rounded,
                      size: 20,
                    ),
                    label: const Text('Realizar Nueva Evaluación'),
                    onPressed: startNewEvaluation,
                  ),
                ] else ...[
                  ElevatedButton.icon(
                    icon: provider.isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.check_rounded, size: 20),
                    label: Text(
                      provider.isSaving
                          ? 'GUARDANDO...'
                          : 'GUARDAR EN REGISTRO LOCAL',
                    ),
                    onPressed: provider.isSaving
                        ? null
                        : () async {
                            final success = await provider
                                .saveCurrentAssessment();
                            if (!context.mounted) return;
                            if (success) {
                              await context
                                  .read<HistoryProvider?>()
                                  ?.loadHistory();
                            }
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: success
                                    ? AppColors.primary
                                    : AppColors.riskHigh,
                                content: Text(
                                  success
                                      ? 'Evaluación guardada correctamente.'
                                      : 'Error al registrar consulta.',
                                ),
                              ),
                            );
                          },
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: provider.isSaving ? null : startNewEvaluation,
                    child: const Text(
                      'Realizar Nueva Evaluación',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
