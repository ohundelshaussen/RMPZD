import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../triage/domain/entities/assessment_record.dart';
import '../providers/history_provider.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HistoryProvider>().loadHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HistoryProvider>();
    final history = provider.history;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial Clínico'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_sync_outlined),
            tooltip: 'Sincronizar con servidor central',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  behavior: SnackBarBehavior.floating,
                  content: Text(
                    'Comprobando conectividad... Registros almacenados de forma segura en SQLite.',
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => provider.loadHistory(),
        child: history.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.assignment_outlined,
                          size: 48,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Sin consultas registradas',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Las evaluaciones que guardes offline en el triage aparecerán aquí.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                children: [
                  // Banner de Sincronización
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.cloud_off_rounded,
                            size: 18,
                            color: AppColors.secondary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${history.length} consultas en SQLite local',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                '${provider.unsyncedCount} pendientes de sincronización',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  ...history.map((record) => _buildRecordCard(record)),
                ],
              ),
      ),
    );
  }

  Widget _buildRecordCard(AssessmentRecord record) {
    final patient = record.patient;
    final result = record.result;
    final riesgo = result.riskLabel;
    final hasEmergency = result.hasImmediateEmergency;

    Color badgeColor = AppColors.riskLow;
    Color badgeBg = const Color(0xFFDCFCE7);
    if (hasEmergency) {
      badgeColor = AppColors.emergencyRed;
      badgeBg = const Color(0xFFFEE2E2);
    } else if (riesgo.contains('Alto')) {
      badgeColor = AppColors.riskHigh;
      badgeBg = const Color(0xFFFEE2E2);
    } else if (riesgo.contains('Medio') || riesgo.contains('Moderado')) {
      badgeColor = AppColors.riskMedium;
      badgeBg = const Color(0xFFFEF3C7);
    }

    final fecha = record.fechaGuardado.toIso8601String().split('T').first;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.person_outline_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      patient.patientId,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    hasEmergency ? 'CÓDIGO ROJO' : riesgo,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: badgeColor,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 14, color: Color(0xFFF1F5F9)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${patient.etnia} • ${patient.municipio}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  fecha,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _buildMetricPill(
                  'PA',
                  '${patient.presionSistolica.toInt()}/${patient.presionDiastolica.toInt()}',
                ),
                _buildMetricPill('Hb', '${patient.hemoglobina} g/dL'),
                _buildMetricPill('Sem', '${patient.semanasGestacion} sem'),
                _buildMetricPill('Dist', '${patient.distanciaKm} km'),
              ],
            ),
            if (result.clinicalAlerts.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Alerta: ${result.clinicalAlerts.map((alert) => alert.title).join(' | ')}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.emergencyRed,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricPill(String title, String val) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$title: $val',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}
