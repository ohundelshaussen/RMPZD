import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/clinical_thresholds.dart';
import '../../../../core/constants/colombia_locations.dart';
import '../../../../core/constants/form_options.dart';
import '../../../../core/constants/input_limits.dart';
import '../../../../core/sync/sync_provider.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/consultation_code_badge.dart';
import '../../../../shared/widgets/contact_phone_action.dart';
import '../../../auth/presentation/widgets/account_menu_button.dart';
import '../../../facilities/presentation/providers/facility_provider.dart';
import '../../../facilities/presentation/providers/nearest_facilities_provider.dart';
import '../../../facilities/presentation/widgets/nearest_facilities_section.dart';
import '../../../triage/domain/entities/assessment_record.dart';
import '../../../triage/domain/entities/patient_assessment.dart';
import '../../../triage/presentation/widgets/consultation_code_card.dart';
import '../../../triage/domain/usecases/regenerate_consultation_code_usecase.dart';
import '../providers/history_provider.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HistoryProvider>().loadHistory();
      context.read<FacilityProvider?>()?.refreshCatalogStatus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HistoryProvider>();
    final syncProvider = context.watch<SyncProvider>();
    final facilityProvider = context.watch<FacilityProvider?>();
    final totalRecords = provider.history;
    final visibleRecords = provider.filteredHistory;

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
            _buildSyncBanner(
              context,
              totalRecords.length,
              syncProvider,
              facilityProvider,
            ),
            if (totalRecords.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildSearchAndFilters(provider),
            ],
            const SizedBox(height: 12),
            if (totalRecords.isEmpty)
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
            else if (visibleRecords.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 36),
                child: Column(
                  children: [
                    const Text(
                      'No hay evaluaciones que coincidan con la búsqueda.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        _searchController.clear();
                        provider.clearFilters();
                      },
                      child: const Text('Restablecer filtros'),
                    ),
                  ],
                ),
              )
            else
              ...visibleRecords.map(
                (record) => _buildRecordCard(record, provider),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters(HistoryProvider provider) {
    final allSelected = !provider.onlyPending && provider.riskFilter == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _searchController,
          onChanged: (value) {
            provider.setSearchQuery(value);
            setState(() {});
          },
          decoration: InputDecoration(
            hintText: 'Buscar por ID, nombre, código o municipio...',
            hintStyle: const TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
            ),
            fillColor: AppColors.surface,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 11,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              size: 19,
              color: AppColors.textMuted,
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    tooltip: 'Limpiar búsqueda',
                    onPressed: () {
                      _searchController.clear();
                      provider.setSearchQuery('');
                      setState(() {});
                    },
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _CalmFilterChip(
                label: 'Todos',
                selected: allSelected,
                onTap: () {
                  provider.setRiskFilter(null);
                  provider.setOnlyPending(false);
                },
              ),
              const SizedBox(width: 6),
              for (final level in const [
                ('Alto', 'Alto riesgo', AppColors.riskHigh),
                ('Medio', 'Moderado', AppColors.riskMedium),
                ('Bajo', 'Bajo', AppColors.riskLow),
              ]) ...[
                _CalmFilterChip(
                  label: level.$2,
                  selected: provider.riskFilter == level.$1,
                  indicatorColor: level.$3,
                  onTap: () => provider.setRiskFilter(
                    provider.riskFilter == level.$1 ? null : level.$1,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              _CalmFilterChip(
                label: 'Pendientes',
                selected: provider.onlyPending,
                indicatorColor: provider.onlyPending
                    ? AppColors.secondary
                    : null,
                onTap: () => provider.setOnlyPending(!provider.onlyPending),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSyncBanner(
    BuildContext context,
    int recordCount,
    SyncProvider syncProvider,
    FacilityProvider? facilityProvider,
  ) {
    final facilityCount = facilityProvider?.availableCount ?? 0;
    final lastUpdatedAt = facilityProvider?.lastUpdatedAt;
    final needsAttention = syncProvider.hasError || syncProvider.pendingCount > 0;
    final statusColor = syncProvider.hasError
        ? AppColors.riskHigh
        : syncProvider.pendingCount > 0
        ? AppColors.secondary
        : AppColors.textMuted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: syncProvider.hasError
              ? AppColors.riskHigh.withValues(alpha: 0.35)
              : syncProvider.pendingCount > 0
              ? AppColors.secondary.withValues(alpha: 0.35)
              : AppColors.border,
        ),
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
                size: 18,
                color: statusColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$recordCount evaluaciones en este dispositivo',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (syncProvider.pendingCount > 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Hay ${syncProvider.pendingCount} registros sin sincronizar. No desinstale la app hasta que se sincronicen.',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.secondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (needsAttention)
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: syncProvider.isSyncing
                      ? null
                      : () async {
                          await syncProvider.syncNow();
                          if (context.mounted) {
                            await context.read<HistoryProvider>().loadHistory();
                          }
                        },
                  child: Text(
                    syncProvider.isSyncing ? 'Sincronizando' : 'Sincronizar',
                  ),
                )
              else
                TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppColors.textSecondary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: syncProvider.isSyncing
                      ? null
                      : () async {
                          await syncProvider.syncNow();
                          if (context.mounted) {
                            await context.read<HistoryProvider>().loadHistory();
                          }
                        },
                  child: Text(
                    syncProvider.isSyncing ? 'Sincronizando' : 'Sincronizar',
                  ),
                ),
            ],
          ),
          if (syncProvider.lastMessage case final message?) ...[
            const SizedBox(height: 6),
            Text(
              message,
              style: TextStyle(
                fontSize: 11.5,
                color: needsAttention ? statusColor : AppColors.textSecondary,
              ),
            ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1, thickness: 1, color: AppColors.border),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Catálogo de centros: $facilityCount · '
                  '${lastUpdatedAt == null ? 'sin actualizar' : DateFormat('dd/MM/yyyy HH:mm').format(lastUpdatedAt.toLocal())}'
                  '${facilityProvider?.isSyncing == true ? ' · actualizando' : ''}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              if (facilityProvider != null)
                IconButton(
                  tooltip: 'Actualizar catálogo de centros',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  onPressed: facilityProvider.isSyncing
                      ? null
                      : facilityProvider.sync,
                  icon: const Icon(
                    Icons.refresh_rounded,
                    size: 15,
                    color: AppColors.textMuted,
                  ),
                ),
            ],
          ),
          if (facilityCount == 0) ...[
            const SizedBox(height: 2),
            const Text(
              FacilityProvider.catalogUnavailableMessage,
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
          if (facilityProvider?.errorMessage case final error?) ...[
            const SizedBox(height: 2),
            Text(
              error,
              style: const TextStyle(fontSize: 11, color: AppColors.riskHigh),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecordCard(AssessmentRecord record, HistoryProvider provider) {
    final patient = record.patient;
    final result = record.result;
    final riesgo = result.riskLabel;
    final hasEmergency = result.hasImmediateEmergency;
    final isHighPriority = hasEmergency || riesgo.contains('Alto');
    final (badgeFg, badgeBg, badgeBorder) = _riskBadgeStyle(
      riesgo,
      hasEmergency: hasEmergency,
    );
    final fecha = DateFormat('dd/MM/yyyy').format(record.fechaGuardado.toLocal());
    final patientName = patient.nombrePaciente?.trim() ?? '';
    final syncColor = switch (record.syncStatus) {
      SyncStatus.pending => AppColors.secondary,
      SyncStatus.synced => AppColors.textMuted,
      SyncStatus.error => AppColors.riskHigh,
    };
    final syncLabel = switch (record.syncStatus) {
      SyncStatus.pending => 'Pendiente',
      SyncStatus.synced => 'Sincronizado',
      SyncStatus.error => 'Error',
    };
    final bpTone = _bloodPressureTone(
      patient.presionSistolica,
      patient.presionDiastolica,
    );
    final hbTone = _hemoglobinTone(patient.hemoglobina);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showRecordDetails(record, provider),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isHighPriority)
                    Container(width: 3.5, color: badgeFg),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      patientName.isNotEmpty
                                          ? patientName
                                          : patient.patientId,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                        color: AppColors.textPrimary,
                                        letterSpacing: -0.1,
                                      ),
                                    ),
                                    if (patientName.isNotEmpty) ...[
                                      const SizedBox(height: 1),
                                      Text(
                                        'ID: ${patient.patientId}',
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          color: AppColors.textMuted,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 165,
                                ),
                                child: _RiskPill(
                                  label: hasEmergency ? 'CÓDIGO ROJO' : riesgo,
                                  foreground: badgeFg,
                                  background: badgeBg,
                                  borderColor: badgeBorder,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${patient.municipio} · ${patient.etnia}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 10,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _InlineMetric(
                                label: 'PA',
                                value:
                                    '${patient.presionSistolica.toInt()}/${patient.presionDiastolica.toInt()}',
                                emphasisColor: bpTone,
                              ),
                              _InlineMetric(
                                label: 'Hb',
                                value: '${patient.hemoglobina}',
                                emphasisColor: hbTone,
                              ),
                              _InlineMetric(
                                label: 'Sem',
                                value: '${patient.semanasGestacion}',
                              ),
                              _InlineMetric(
                                label: 'Dist',
                                value: '${patient.distanciaKm} km',
                              ),
                            ],
                          ),
                          if (result.clinicalAlerts.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 1),
                                  child: Icon(
                                    Icons.warning_amber_rounded,
                                    size: 14,
                                    color: AppColors.emergencyRed,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    'Alerta: ${result.clinicalAlerts.map((alert) => alert.title).join(' | ')}',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: AppColors.emergencyRed,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 10),
                          const Divider(
                            height: 1,
                            thickness: 1,
                            color: AppColors.border,
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (record.consultationCode case final code?
                                    when code.trim().isNotEmpty)
                                  ConsultationCodeBadge(code: code)
                                else
                                  const SizedBox.shrink(),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      switch (record.syncStatus) {
                                        SyncStatus.pending =>
                                          Icons.schedule_rounded,
                                        SyncStatus.synced =>
                                          Icons.cloud_done_outlined,
                                        SyncStatus.error =>
                                          Icons.error_outline_rounded,
                                      },
                                      size: 13,
                                      color: syncColor,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$syncLabel · $fecha',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight:
                                            record.syncStatus ==
                                                SyncStatus.synced
                                            ? FontWeight.w500
                                            : FontWeight.w600,
                                        color: syncColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (record.syncStatus == SyncStatus.error &&
                              record.lastSyncError != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Error: ${record.lastSyncError}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.riskHigh,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showRecordDetails(AssessmentRecord record, HistoryProvider provider) {
    final patient = record.patient;
    final result = record.result;
    final riesgo = result.riskLabel;
    final hasEmergency = result.hasImmediateEmergency;
    final (badgeFg, badgeBg, badgeBorder) = _riskBadgeStyle(
      riesgo,
      hasEmergency: hasEmergency,
    );
    final fecha = DateFormat(
      'dd/MM/yyyy HH:mm',
    ).format(record.fechaGuardado.toLocal());
    final hasFacilities = context.read<NearestFacilitiesProvider?>() != null;
    final patientName = patient.nombrePaciente?.trim() ?? '';
    final bpTone = _bloodPressureTone(
      patient.presionSistolica,
      patient.presionDiastolica,
    );
    final hbTone = _hemoglobinTone(patient.hemoglobina);
    final bmiTone = _bmiTone(patient.imc);
    final syncLabel = switch (record.syncStatus) {
      SyncStatus.pending => 'Pendiente de sincronización',
      SyncStatus.synced => 'Sincronizado',
      SyncStatus.error => 'Error de sincronización',
    };

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (sheetContext, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Hero Risk Summary
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: badgeBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _RiskPill(
                            label: hasEmergency ? 'CÓDIGO ROJO' : riesgo,
                            foreground: badgeFg,
                            background: AppColors.surface,
                            borderColor: badgeBorder,
                          ),
                          Text(
                            fecha,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textSecondary,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      patientName.isNotEmpty
                          ? patientName
                          : 'Detalle · ${patient.patientId}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (patientName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'ID: ${patient.patientId}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      '${patient.etnia} · ${patient.municipio}, ${patient.departamento}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (result.clinicalAlerts.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.emergencyRed.withValues(alpha: 0.32),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 1),
                        child: Icon(
                          Icons.warning_amber_rounded,
                          size: 18,
                          color: AppColors.emergencyRed,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Alerta: ${result.clinicalAlerts.map((alert) => alert.title).join(' | ')}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            height: 1.35,
                            color: AppColors.emergencyRed,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              const _SheetSectionTitle('Signos vitales y datos clínicos'),
              const SizedBox(height: 10),
              _TwoColumnMetricGrid(
                items: [
                  _GridMetricItem(
                    label: 'Presión arterial',
                    value:
                        '${patient.presionSistolica.toInt()}/${patient.presionDiastolica.toInt()} mmHg',
                    emphasisColor: bpTone,
                  ),
                  _GridMetricItem(
                    label: 'Hemoglobina',
                    value: '${patient.hemoglobina} g/dL',
                    emphasisColor: hbTone,
                  ),
                  _GridMetricItem(
                    label: 'Edad materna',
                    value: '${patient.edadMaterna} años',
                  ),
                  _GridMetricItem(
                    label: 'Semanas',
                    value: '${patient.semanasGestacion} sem',
                  ),
                  _GridMetricItem(
                    label: 'IMC',
                    value: '${patient.imc} kg/m²',
                    emphasisColor: bmiTone,
                  ),
                  _GridMetricItem(
                    label: 'Controles',
                    value: '${patient.numeroControles}',
                  ),
                  _GridMetricItem(
                    label: 'Distancia',
                    value: '${patient.distanciaKm} km',
                  ),
                  _GridMetricItem(
                    label: 'Traslado',
                    value: '${patient.tiempoTrasladoHoras} h',
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _KeyValueRow(
                label: 'Antec. preeclampsia',
                value: patient.antecedentePreeclampsia ? 'Sí' : 'No',
                emphasisColor: patient.antecedentePreeclampsia
                    ? AppColors.secondary
                    : null,
              ),
              _KeyValueRow(
                label: 'Antec. diabetes',
                value: patient.antecedenteDiabetes ? 'Sí' : 'No',
                emphasisColor: patient.antecedenteDiabetes
                    ? AppColors.secondary
                    : null,
              ),
              _KeyValueRow(
                label: 'Parto institucional previo',
                value: patient.partoInstitucionalPrevio ? 'Sí' : 'No',
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Divider(height: 1, thickness: 1, color: AppColors.border),
              ),
              const _SheetSectionTitle('Estimación del modelo de IA'),
              const SizedBox(height: 10),
              _AiProbabilityBar(
                label: 'Riesgo alto',
                probability: result.probAlto,
                threshold: ClinicalThresholds.aiRiskHighThreshold,
                accentColor: AppColors.riskHigh,
              ),
              if (result.probMedio > 0 || result.probBajo > 0) ...[
                const SizedBox(height: 10),
                _AiProbabilityBar(
                  label: 'Riesgo moderado',
                  probability: result.probMedio,
                  threshold: 1.1,
                  accentColor: AppColors.riskMedium,
                ),
                const SizedBox(height: 10),
                _AiProbabilityBar(
                  label: 'Riesgo bajo',
                  probability: result.probBajo,
                  threshold: 1.1,
                  accentColor: AppColors.riskLow,
                ),
              ],
              const SizedBox(height: 10),
              _AiProbabilityBar(
                label: 'Desenlace adverso',
                probability: result.probDesenlaceAdverso,
                threshold: ClinicalThresholds.aiAdverseOutcomeThreshold,
                accentColor: AppColors.secondary,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Divider(height: 1, thickness: 1, color: AppColors.border),
              ),
              const _SheetSectionTitle('Identificación y territorio'),
              const SizedBox(height: 8),
              _KeyValueRow(label: 'Zona', value: patient.zona),
              _KeyValueRow(
                label: 'Régimen SGSSS',
                value: patient.afiliacionSgsss,
              ),
              if (patient.direccionPaciente case final address?)
                _KeyValueRow(label: 'Dirección', value: address),
              if (record.telefonoPaciente case final phone?)
                ContactPhoneAction(phone: phone),
              if (patient.latitud != null && patient.longitud != null)
                _KeyValueRow(
                  label: 'Ubicación GPS',
                  value:
                      '${patient.latitud!.toStringAsFixed(5)}, '
                      '${patient.longitud!.toStringAsFixed(5)}'
                      '${patient.precisionGpsM == null ? '' : ' (±${patient.precisionGpsM!.toStringAsFixed(1)} m)'}',
                ),
              _KeyValueRow(label: 'Sincronización', value: syncLabel),
              if (hasFacilities) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => _showNearbyFacilities(record),
                  icon: const Icon(Icons.local_hospital_outlined, size: 18),
                  label: const Text('Centros cercanos'),
                ),
              ],
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Divider(height: 1, thickness: 1, color: AppColors.border),
              ),
              ConsultationCodeCard(
                code: (record.consultationCode?.trim().isNotEmpty ?? false)
                    ? record.consultationCode
                    : null,
                recordUuid: record.uuid,
                syncStatus: record.syncStatus,
                regenerateUseCase: context
                    .read<RegenerateConsultationCodeUseCase?>(),
                onCodeRegenerated: (_) => provider.loadHistory(),
              ),
              if (provider.updateAssessment != null ||
                  provider.deleteAssessment != null) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (provider.updateAssessment != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textPrimary,
                            side: const BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: provider.isMutating
                              ? null
                              : () {
                                  Navigator.pop(sheetContext);
                                  _showEditDialog(context, provider, record);
                                },
                          icon: const Icon(Icons.edit_outlined, size: 17),
                          label: const Text('Editar'),
                        ),
                      ),
                    if (provider.updateAssessment != null &&
                        provider.deleteAssessment != null)
                      const SizedBox(width: 10),
                    if (provider.deleteAssessment != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.riskHigh,
                            side: BorderSide(
                              color: AppColors.riskHigh.withValues(alpha: 0.4),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: provider.isMutating
                              ? null
                              : () => _confirmDelete(
                                  context,
                                  sheetContext,
                                  provider,
                                  record,
                                ),
                          icon: const Icon(Icons.delete_outline, size: 17),
                          label: const Text('Eliminar'),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showEditDialog(
    BuildContext context,
    HistoryProvider provider,
    AssessmentRecord record,
  ) async {
    final p = record.patient;
    final idController = TextEditingController(text: p.patientId);
    final ageController = TextEditingController(text: '${p.edadMaterna}');
    final weeksController = TextEditingController(
      text: '${p.semanasGestacion}',
    );
    final visitsController = TextEditingController(
      text: '${p.numeroControles}',
    );
    final distanceController = TextEditingController(text: '${p.distanciaKm}');
    final travelController = TextEditingController(
      text: '${p.tiempoTrasladoHoras}',
    );
    final systolicController = TextEditingController(
      text: p.presionSistolica.toStringAsFixed(0),
    );
    final diastolicController = TextEditingController(
      text: p.presionDiastolica.toStringAsFixed(0),
    );
    final hemoglobinController = TextEditingController(
      text: '${p.hemoglobina}',
    );
    final bmiController = TextEditingController(text: '${p.imc}');
    final nameController = TextEditingController(text: p.nombrePaciente ?? '');
    final addressController = TextEditingController(
      text: p.direccionPaciente ?? '',
    );

    var department = colombiaDepartments.contains(p.departamento)
        ? p.departamento
        : colombiaDepartments.first;
    final munis = municipalitiesByDepartment[department]!;
    var municipality = munis.contains(p.municipio) ? p.municipio : munis.first;
    var ethnicity = ethnicities.contains(p.etnia) ? p.etnia : ethnicities.first;
    var zone = residentialZones.contains(p.zona)
        ? p.zona
        : residentialZones.first;
    var affiliation = healthAffiliations.contains(p.afiliacionSgsss)
        ? p.afiliacionSgsss
        : healthAffiliations.first;
    var preeclampsia = p.antecedentePreeclampsia;
    var diabetes = p.antecedenteDiabetes;
    var institutionalBirth = p.partoInstitucionalPrevio;
    var consent = p.consentimientoDatos;
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Editar evaluación'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: idController,
                      decoration: const InputDecoration(
                        labelText: 'ID de Gestante',
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: department,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Departamento',
                            ),
                            items: colombiaDepartments
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(
                                      e,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              if (v == null) return;
                              setDialogState(() {
                                department = v;
                                municipality =
                                    municipalitiesByDepartment[v]!.first;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            key: ValueKey('hist_muni_$department'),
                            initialValue: municipality,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Municipio',
                            ),
                            items: municipalitiesByDepartment[department]!
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(
                                      e,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setDialogState(() => municipality = v);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: ethnicity,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Etnia',
                            ),
                            items: ethnicities
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(
                                      e,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setDialogState(() => ethnicity = v);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: zone,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Zona',
                            ),
                            items: residentialZones
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(
                                      e,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              if (v != null) setDialogState(() => zone = v);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: affiliation,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Régimen SGSSS',
                      ),
                      items: healthAffiliations
                          .map(
                            (e) => DropdownMenuItem(
                              value: e,
                              child: Text(e, overflow: TextOverflow.ellipsis),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setDialogState(() => affiliation = v);
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: systolicController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'PA Sistólica',
                            ),
                            validator: requiredDouble(
                              InputLimits.systolicPressureMin,
                              InputLimits.systolicPressureMax,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: diastolicController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'PA Diastólica',
                            ),
                            validator: combineValidators([
                              requiredDouble(
                                InputLimits.diastolicPressureMin,
                                InputLimits.diastolicPressureMax,
                              ),
                              lessThanController(
                                systolicController,
                                message: 'Debe ser menor a sistólica',
                              ),
                            ]),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: hemoglobinController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Hemoglobina',
                            ),
                            validator: requiredDouble(
                              InputLimits.hemoglobinMin,
                              InputLimits.hemoglobinMax,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: bmiController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(labelText: 'IMC'),
                            validator: requiredDouble(
                              InputLimits.bmiMin,
                              InputLimits.bmiMax,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: ageController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Edad (años)',
                            ),
                            validator: requiredInt(
                              InputLimits.ageMin,
                              InputLimits.ageMax,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: weeksController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Semanas',
                            ),
                            validator: requiredInt(
                              InputLimits.gestationalWeeksMin,
                              InputLimits.gestationalWeeksMax,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: visitsController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Controles',
                            ),
                            validator: requiredInt(
                              InputLimits.prenatalVisitsMin,
                              InputLimits.prenatalVisitsMax,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: distanceController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Distancia (km)',
                            ),
                            validator: requiredDouble(
                              InputLimits.distanceMin,
                              InputLimits.distanceMax,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: travelController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Traslado (h)',
                            ),
                            validator: requiredDouble(
                              InputLimits.travelTimeMin,
                              InputLimits.travelTimeMax,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Antecedente de preeclampsia',
                        style: TextStyle(fontSize: 13),
                      ),
                      value: preeclampsia,
                      onChanged: (v) => setDialogState(() => preeclampsia = v),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Antecedente de diabetes',
                        style: TextStyle(fontSize: 13),
                      ),
                      value: diabetes,
                      onChanged: (v) => setDialogState(() => diabetes = v),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Parto institucional previo',
                        style: TextStyle(fontSize: 13),
                      ),
                      value: institutionalBirth,
                      onChanged: (v) =>
                          setDialogState(() => institutionalBirth = v),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text(
                        'Incluir nombre y dirección autorizados',
                        style: TextStyle(fontSize: 13),
                      ),
                      value: consent,
                      onChanged: (v) {
                        if (v != null) setDialogState(() => consent = v);
                      },
                    ),
                    if (consent) ...[
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre completo',
                        ),
                        validator: (v) => (v == null || v.trim().length < 2)
                            ? 'Mínimo 2 caracteres'
                            : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: addressController,
                        decoration: const InputDecoration(
                          labelText: 'Dirección',
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Obligatoria'
                            : null,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: const Text('Guardar cambios'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !context.mounted) {
      for (final controller in [
        idController,
        ageController,
        weeksController,
        visitsController,
        distanceController,
        travelController,
        systolicController,
        diastolicController,
        hemoglobinController,
        bmiController,
        nameController,
        addressController,
      ]) {
        controller.dispose();
      }
      return;
    }

    double parse(TextEditingController c) =>
        double.parse(c.text.trim().replaceAll(',', '.'));

    final updatedPatient = PatientAssessment(
      patientId: idController.text.trim(),
      municipio: municipality,
      departamento: department,
      etnia: ethnicity,
      zona: zone,
      edadMaterna: int.parse(ageController.text.trim()),
      semanasGestacion: int.parse(weeksController.text.trim()),
      numeroControles: int.parse(visitsController.text.trim()),
      distanciaKm: parse(distanceController),
      tiempoTrasladoHoras: parse(travelController),
      hemoglobina: parse(hemoglobinController),
      presionSistolica: parse(systolicController),
      presionDiastolica: parse(diastolicController),
      imc: parse(bmiController),
      antecedentePreeclampsia: preeclampsia,
      antecedenteDiabetes: diabetes,
      partoInstitucionalPrevio: institutionalBirth,
      afiliacionSgsss: affiliation,
      fechaEvaluacion: p.fechaEvaluacion,
      consentimientoDatos: consent,
      nombrePaciente: consent ? nameController.text.trim() : null,
      direccionPaciente: consent ? addressController.text.trim() : null,
      telefonoPaciente: consent ? p.telefonoPaciente : null,
      latitud: consent ? p.latitud : null,
      longitud: consent ? p.longitud : null,
      precisionGpsM: consent ? p.precisionGpsM : null,
      ubicacionCapturadaAt: consent ? p.ubicacionCapturadaAt : null,
    );

    for (final controller in [
      idController,
      ageController,
      weeksController,
      visitsController,
      distanceController,
      travelController,
      systolicController,
      diastolicController,
      hemoglobinController,
      bmiController,
      nameController,
      addressController,
    ]) {
      controller.dispose();
    }

    final outcome = await provider.editRecord(record, updatedPatient);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: outcome.success
            ? AppColors.primary
            : AppColors.riskHigh,
        content: Text(outcome.message),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext pageContext,
    BuildContext sheetContext,
    HistoryProvider provider,
    AssessmentRecord record,
  ) async {
    bool? deleteCloud;
    if (record.isSynced && provider.remoteDataSource != null) {
      deleteCloud = await showDialog<bool>(
        context: pageContext,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Eliminar evaluación sincronizada'),
          content: const Text(
            'Esta evaluación ya fue sincronizada. ¿Deseas eliminar solo la copia local o también borrarla de Supabase?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Solo de este dispositivo'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.riskHigh,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Dispositivo y nube'),
            ),
          ],
        ),
      );
      if (deleteCloud == null) return;
    } else {
      final ok = await showDialog<bool>(
        context: pageContext,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Eliminar evaluación'),
          content: Text(
            'Se eliminará la evaluación local de ${record.patient.patientId}.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.riskHigh,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Eliminar'),
            ),
          ],
        ),
      );
      if (ok != true) return;
      deleteCloud = false;
    }

    if (!pageContext.mounted) return;
    final outcome = await provider.removeRecord(
      record,
      deleteFromCloud: deleteCloud,
    );
    if (!pageContext.mounted) return;
    if (outcome.success && sheetContext.mounted) {
      Navigator.pop(sheetContext);
    }
    ScaffoldMessenger.of(pageContext).showSnackBar(
      SnackBar(
        backgroundColor: outcome.success
            ? AppColors.primary
            : AppColors.riskHigh,
        content: Text(outcome.message),
      ),
    );
  }

  void _showNearbyFacilities(AssessmentRecord record) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          child: NearestFacilitiesSection(
            latitude: record.patient.latitud,
            longitude: record.patient.longitud,
            department: record.patient.departamento,
            municipality: record.patient.municipio,
          ),
        ),
      ),
    );
  }

  (Color, Color, Color) _riskBadgeStyle(
    String riesgo, {
    required bool hasEmergency,
  }) {
    if (hasEmergency) {
      return (
        AppColors.emergencyRed,
        const Color(0xFFFEF2F2),
        AppColors.emergencyRed.withValues(alpha: 0.30),
      );
    }
    if (riesgo.contains('Alto')) {
      return (
        AppColors.riskHigh,
        const Color(0xFFFEF2F2),
        AppColors.riskHigh.withValues(alpha: 0.28),
      );
    }
    if (riesgo.contains('Medio') || riesgo.contains('Moderado')) {
      return (
        const Color(0xFFB45309),
        const Color(0xFFFFFBEB),
        AppColors.riskMedium.withValues(alpha: 0.32),
      );
    }
    return (
      const Color(0xFF047857),
      const Color(0xFFF0FDF4),
      AppColors.riskLow.withValues(alpha: 0.25),
    );
  }

  Color? _bloodPressureTone(double systolic, double diastolic) {
    if (systolic >= ClinicalThresholds.severeSystolicCrisis ||
        diastolic >= ClinicalThresholds.severeDiastolicCrisis) {
      return AppColors.emergencyRed;
    }
    if (systolic >= ClinicalThresholds.moderateSystolicCrisis ||
        diastolic >= ClinicalThresholds.moderateDiastolicCrisis) {
      return AppColors.secondary;
    }
    return null;
  }

  Color? _hemoglobinTone(double hemoglobin) {
    if (hemoglobin <= 0) return null;
    if (hemoglobin < ClinicalThresholds.severeAnemia) {
      return AppColors.emergencyRed;
    }
    if (hemoglobin < ClinicalThresholds.mildAnemia) {
      return AppColors.secondary;
    }
    return null;
  }

  Color? _bmiTone(double bmi) {
    if (bmi <= 0) return null;
    if (bmi < 18.5 || bmi >= 30.0) return AppColors.secondary;
    return null;
  }
}

class _CalmFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? indicatorColor;
  final VoidCallback onTap;

  const _CalmFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.indicatorColor,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = selected
        ? AppColors.primary.withValues(alpha: 0.09)
        : AppColors.surface;
    final borderColor = selected ? AppColors.primary : AppColors.border;
    final textColor = selected
        ? AppColors.primaryDark
        : AppColors.textSecondary;

    return Material(
      color: bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: borderColor),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (indicatorColor != null) ...[
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: indicatorColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RiskPill extends StatelessWidget {
  final String label;
  final Color foreground;
  final Color background;
  final Color borderColor;

  const _RiskPill({
    required this.label,
    required this.foreground,
    required this.background,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: borderColor),
    ),
    child: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: foreground,
      ),
    ),
  );
}

class _InlineMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color? emphasisColor;

  const _InlineMetric({
    required this.label,
    required this.value,
    this.emphasisColor,
  });

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        '$label ',
        style: const TextStyle(
          fontSize: 11.5,
          color: AppColors.textMuted,
          fontWeight: FontWeight.w500,
        ),
      ),
      Text(
        value,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: emphasisColor ?? AppColors.textPrimary,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    ],
  );
}

class _SheetSectionTitle extends StatelessWidget {
  final String text;

  const _SheetSectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 12.5,
      fontWeight: FontWeight.w700,
      color: AppColors.textSecondary,
      letterSpacing: 0.2,
    ),
  );
}

class _GridMetricItem {
  final String label;
  final String value;
  final Color? emphasisColor;

  const _GridMetricItem({
    required this.label,
    required this.value,
    this.emphasisColor,
  });
}

class _TwoColumnMetricGrid extends StatelessWidget {
  final List<_GridMetricItem> items;

  const _TwoColumnMetricGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < items.length; i += 2) {
      final left = items[i];
      final right = i + 1 < items.length ? items[i + 1] : null;
      if (i > 0) {
        rows.add(
          const Divider(height: 1, thickness: 1, color: AppColors.border),
        );
      }
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _MetricCell(item: left)),
              const VerticalDivider(
                width: 1,
                thickness: 1,
                color: AppColors.border,
              ),
              Expanded(
                child: right != null
                    ? _MetricCell(item: right)
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: rows,
      ),
    );
  }
}

class _MetricCell extends StatelessWidget {
  final _GridMetricItem item;

  const _MetricCell({required this.item});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (item.emphasisColor != null) ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: item.emphasisColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
            ],
            Expanded(
              child: Text(
                item.label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          item.value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: item.emphasisColor ?? AppColors.textPrimary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    ),
  );
}

class _KeyValueRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? emphasisColor;

  const _KeyValueRow({
    required this.label,
    required this.value,
    this.emphasisColor,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: emphasisColor ?? AppColors.textPrimary,
            ),
          ),
        ),
      ],
    ),
  );
}

class _AiProbabilityBar extends StatelessWidget {
  final String label;
  final double probability;
  final double threshold;
  final Color accentColor;

  const _AiProbabilityBar({
    required this.label,
    required this.probability,
    required this.threshold,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = probability.clamp(0.0, 1.0);
    final isElevated = clamped >= threshold;
    final barColor = isElevated ? accentColor : AppColors.textMuted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              '${(clamped * 100).toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isElevated ? accentColor : AppColors.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: clamped,
            minHeight: 5,
            backgroundColor: AppColors.surfaceVariant,
            valueColor: AlwaysStoppedAnimation<Color>(
              barColor.withValues(alpha: isElevated ? 0.85 : 0.4),
            ),
          ),
        ),
      ],
    );
  }
}
