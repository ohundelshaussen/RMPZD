import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/sync/sync_provider.dart';
import '../../../auth/presentation/widgets/account_menu_button.dart';
import '../../../triage/domain/entities/assessment_record.dart';
import '../../../triage/presentation/widgets/consultation_code_card.dart';
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
    final syncProvider = context.watch<SyncProvider>();
    final history = provider.history;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial Clínico'),
        actions: const [AccountMenuButton()],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await provider.loadHistory();
          await syncProvider.refreshPendingCount();
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          children: [
            _buildSyncBanner(context, history.length, syncProvider),
            const SizedBox(height: 14),
            if (history.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48, horizontal: 16),
                child: Column(
                  children: [
                    Icon(
                      Icons.assignment_outlined,
                      size: 48,
                      color: AppColors.textMuted,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Sin consultas registradas',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Las evaluaciones que guardes offline en el triage aparecerán aquí.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              )
            else
              ...history.map((record) => _buildRecordCard(record)),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncBanner(
    BuildContext context,
    int recordCount,
    SyncProvider syncProvider,
  ) {
    final color = syncProvider.hasError
        ? AppColors.riskHigh
        : syncProvider.pendingCount > 0
        ? AppColors.secondary
        : AppColors.riskLow;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                syncProvider.hasError
                    ? Icons.cloud_off_rounded
                    : syncProvider.pendingCount > 0
                    ? Icons.cloud_upload_outlined
                    : Icons.cloud_done_outlined,
                size: 20,
                color: color,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$recordCount evaluaciones en este dispositivo',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      '${syncProvider.pendingCount} pendientes de sincronización',
                      style: TextStyle(fontSize: 11, color: color),
                    ),
                  ],
                ),
              ),
              FilledButton.tonal(
                onPressed: syncProvider.isSyncing
                    ? null
                    : () async {
                        await syncProvider.syncNow();
                        if (context.mounted) {
                          await context.read<HistoryProvider>().loadHistory();
                        }
                      },
                child: Text(
                  syncProvider.isSyncing
                      ? 'Sincronizando'
                      : 'Sincronizar ahora',
                ),
              ),
            ],
          ),
          if (syncProvider.lastMessage case final message?) ...[
            const SizedBox(height: 8),
            Text(message, style: TextStyle(fontSize: 11, color: color)),
          ],
        ],
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
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showRecordDetails(record),
        child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.person_outline_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    patient.patientId,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
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
              children: [
                Icon(
                  switch (record.syncStatus) {
                    SyncStatus.pending => Icons.schedule_rounded,
                    SyncStatus.synced => Icons.cloud_done_rounded,
                    SyncStatus.error => Icons.error_outline_rounded,
                  },
                  size: 14,
                  color: switch (record.syncStatus) {
                    SyncStatus.pending => AppColors.secondary,
                    SyncStatus.synced => AppColors.riskLow,
                    SyncStatus.error => AppColors.riskHigh,
                  },
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    switch (record.syncStatus) {
                      SyncStatus.pending => 'Pendiente de sincronización',
                      SyncStatus.synced => 'Sincronizado',
                      SyncStatus.error =>
                        'Error: ${record.lastSyncError ?? 'no especificado'}',
                    },
                    style: TextStyle(
                      fontSize: 11,
                      color: switch (record.syncStatus) {
                        SyncStatus.pending => AppColors.secondary,
                        SyncStatus.synced => AppColors.riskLow,
                        SyncStatus.error => AppColors.riskHigh,
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
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
      ),
    );
  }

  void _showRecordDetails(AssessmentRecord record) {
    final patient = record.patient;
    final result = record.result;
    final riesgo = result.riskLabel;
    final hasEmergency = result.hasImmediateEmergency;
    final (Color badgeColor, Color badgeBg) = _riskBadgeColors(
      riesgo,
      hasEmergency: hasEmergency,
    );
    final fecha = record.fechaGuardado.toIso8601String().split('T').first;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Detalle de evaluación · ${patient.patientId}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      hasEmergency ? 'CÓDIGO ROJO' : riesgo,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: badgeColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '${patient.etnia} • ${patient.municipio}, ${patient.departamento}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text('Fecha: $fecha'),
              Text('Municipio: ${patient.municipio}'),
              Text('Semanas de gestación: ${patient.semanasGestacion}'),
              Text('Resultado: $riesgo'),
              const SizedBox(height: 12),
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
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Alerta: ${result.clinicalAlerts.map((alert) => alert.title).join(' | ')}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.emergencyRed,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              if (record.consultationCode case final code?) ...[
                const SizedBox(height: 12),
                ConsultationCodeCard(code: code),
              ],
            ],
          ),
        ),
      ),
    );
  }

  (Color, Color) _riskBadgeColors(String riesgo, {required bool hasEmergency}) {
    if (hasEmergency) {
      return (AppColors.emergencyRed, const Color(0xFFFEE2E2));
    }
    if (riesgo.contains('Alto')) {
      return (AppColors.riskHigh, const Color(0xFFFEE2E2));
    }
    if (riesgo.contains('Medio') || riesgo.contains('Moderado')) {
      return (AppColors.riskMedium, const Color(0xFFFEF3C7));
    }
    return (AppColors.riskLow, const Color(0xFFDCFCE7));
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
