import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import 'package:rmpzd/features/triage/presentation/providers/triage_provider.dart';

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
      context.read<TriageProvider>().loadHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TriageProvider>();
    final history = provider.history;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial Clínico Offline'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync_rounded),
            tooltip: 'Sincronizar con servidor central',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Comprobando conectividad... Registros almacenados de forma segura en SQLite.'),
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
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.textMuted.withValues(alpha: 0.5)),
                    const SizedBox(height: 16),
                    const Text(
                      'No hay evaluaciones registradas aún',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Realiza un triage desde el formulario para almacenar registros locales.',
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Sync status header
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${history.length} Evaluaciones en memoria local',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${provider.unsyncedCount} pendientes de sincronización central',
                              style: const TextStyle(fontSize: 11, color: AppColors.secondary),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.cloud_queue_rounded, size: 16, color: AppColors.secondary),
                              SizedBox(width: 4),
                              Text('Offline', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.secondary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  ...history.map((record) => _buildRecordCard(record)),
                ],
              ),
      ),
    );
  }

  Widget _buildRecordCard(Map<String, dynamic> record) {
    final riesgo = record['nivel_riesgo_predicho'] as String? ?? 'Bajo';
    final hasEmergency = (record['alerta_clinica_inmediata'] as int? ?? 0) == 1;

    Color badgeColor = AppColors.riskLow;
    if (hasEmergency) {
      badgeColor = AppColors.emergencyRed;
    } else if (riesgo.contains('Alto')) {
      badgeColor = AppColors.riskHigh;
    } else if (riesgo.contains('Medio') || riesgo.contains('Moderado')) {
      badgeColor = AppColors.riskMedium;
    }

    final fecha = record['fecha_evaluacion']?.toString().split('T').first ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
                    const Icon(Icons.person_pin_outlined, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      record['patient_id'] ?? 'Sin ID',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    hasEmergency ? 'CÓDIGO ROJO' : riesgo,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: badgeColor,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${record['etnia']} • ${record['municipio']} (${record['zona']})',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                Text(
                  fecha,
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _buildMetricPill('PA', '${record['presion_sistolica']?.toInt()}/${record['presion_diastolica']?.toInt()}'),
                const SizedBox(width: 8),
                _buildMetricPill('Hb', '${record['hemoglobina']} g/dL'),
                const SizedBox(width: 8),
                _buildMetricPill('Sem', '${record['semanas_gestacion']} sem'),
                const SizedBox(width: 8),
                _buildMetricPill('Dist', '${record['distancia_km']} km'),
              ],
            ),
            if (record['descripcion_alerta'] != null) ...[
              const SizedBox(height: 8),
              Text(
                'Alerta: ${record['descripcion_alerta']}',
                style: const TextStyle(fontSize: 11, color: AppColors.emergencyRed, fontWeight: FontWeight.w500),
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$title: $val',
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
      ),
    );
  }
}
