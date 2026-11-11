import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../history/presentation/providers/history_provider.dart';
import '../providers/triage_provider.dart';
import '../widgets/ai_probability_card.dart';
import '../widgets/clinical_alert_section.dart';
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

    return Scaffold(
      appBar: AppBar(title: const Text('Dictamen de Triage')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ResultStatusCard(patient: patient, result: result),
            const SizedBox(height: 16),
            AiProbabilityCard(result: result),
            const SizedBox(height: 16),
            ClinicalAlertSection(alerts: result.clinicalAlerts),
            ElevatedButton.icon(
              icon: const Icon(Icons.check_rounded, size: 20),
              label: const Text('GUARDAR EN REGISTRO LOCAL'),
              onPressed: () async {
                final success = await provider.saveCurrentAssessment();
                if (!context.mounted) return;
                if (success) {
                  await context.read<HistoryProvider>().loadHistory();
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
                          ? 'Consulta registrada en base de datos local SQLite.'
                          : 'Error al registrar consulta.',
                    ),
                  ),
                );
                if (success) Navigator.pop(context);
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
}
