import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/colombia_locations.dart';
import '../../../../core/constants/form_options.dart';
import '../../../../core/constants/input_limits.dart';
import '../../../../core/sync/sync_provider.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/consultation_code_badge.dart';
import '../../../auth/presentation/widgets/account_menu_button.dart';
import '../../../facilities/presentation/providers/facility_provider.dart';
import '../../../facilities/presentation/providers/nearest_facilities_provider.dart';
import '../../../facilities/presentation/widgets/nearest_facilities_section.dart';
import '../../../triage/domain/entities/assessment_record.dart';
import '../../../triage/domain/entities/patient_assessment.dart';
import '../../../triage/presentation/widgets/consultation_code_card.dart';
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
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    tooltip: 'Limpiar búsqueda',
                    onPressed: () {
                      _searchController.clear();
                      provider.setSearchQuery('');
                      setState(() {});
                    },
                    icon: const Icon(Icons.close_rounded, size: 18),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: const Text('Todos'),
                  selected: !provider.onlyPending && provider.riskFilter == null,
                  onSelected: (_) {
                    provider.setRiskFilter(null);
                    provider.setOnlyPending(false);
                  },
                ),
              ),
              for (final level in const [
                ('Alto', 'Alto riesgo'),
                ('Medio', 'Moderado'),
                ('Bajo', 'Bajo'),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(level.$2),
                    selected: provider.riskFilter == level.$1,
                    onSelected: (selected) =>
                        provider.setRiskFilter(selected ? level.$1 : null),
                  ),
                ),
              FilterChip(
                label: const Text('Pendientes'),
                selected: provider.onlyPending,
                onSelected: provider.setOnlyPending,
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
        border: Border.all(color: AppColors.border),
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
                  syncProvider.isSyncing ? 'Sincronizando' : 'Sincronizar',
                ),
              ),
            ],
          ),
          if (syncProvider.lastMessage case final message?) ...[
            const SizedBox(height: 6),
            Text(message, style: TextStyle(fontSize: 11, color: color)),
          ],
          const Divider(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Catálogo de centros: $facilityCount · '
                  '${lastUpdatedAt == null ? 'sin actualizar' : DateFormat('dd/MM/yyyy HH:mm').format(lastUpdatedAt.toLocal())}'
                  '${facilityProvider?.isSyncing == true ? ' · actualizando' : ''}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
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
                  icon: const Icon(Icons.refresh_rounded, size: 16),
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
    final (badgeColor, badgeBg) = _riskBadgeColors(
      riesgo,
      hasEmergency: hasEmergency,
    );
    final fecha = DateFormat('dd/MM/yyyy').format(record.fechaGuardado.toLocal());
    final patientName = patient.nombrePaciente?.trim() ?? '';
    final syncColor = switch (record.syncStatus) {
      SyncStatus.pending => AppColors.secondary,
      SyncStatus.synced => AppColors.riskLow,
      SyncStatus.error => AppColors.riskHigh,
    };
    final syncLabel = switch (record.syncStatus) {
      SyncStatus.pending => 'Pendiente',
      SyncStatus.synced => 'Sincronizado',
      SyncStatus.error => 'Error',
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showRecordDetails(record, provider),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.person_outline_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
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
                            fontSize: 14,
                          ),
                        ),
                        if (patientName.isNotEmpty)
                          Text(
                            'ID: ${patient.patientId}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
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
              const SizedBox(height: 8),
              Row(
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
                  const SizedBox(width: 8),
                  Icon(
                    switch (record.syncStatus) {
                      SyncStatus.pending => Icons.schedule_rounded,
                      SyncStatus.synced => Icons.cloud_done_rounded,
                      SyncStatus.error => Icons.error_outline_rounded,
                    },
                    size: 13,
                    color: syncColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$syncLabel · $fecha',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: syncColor,
                    ),
                  ),
                ],
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
              if (record.consultationCode case final code?
                  when code.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ConsultationCodeBadge(code: code),
                ),
              ],
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

  void _showRecordDetails(AssessmentRecord record, HistoryProvider provider) {
    final patient = record.patient;
    final result = record.result;
    final riesgo = result.riskLabel;
    final hasEmergency = result.hasImmediateEmergency;
    final (badgeColor, badgeBg) = _riskBadgeColors(
      riesgo,
      hasEmergency: hasEmergency,
    );
    final fecha = DateFormat(
      'dd/MM/yyyy HH:mm',
    ).format(record.fechaGuardado.toLocal());
    final hasFacilities = context.read<NearestFacilitiesProvider?>() != null;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      patient.nombrePaciente?.trim().isNotEmpty == true
                          ? '${patient.nombrePaciente} · ${patient.patientId}'
                          : 'Detalle · ${patient.patientId}',
                      style: Theme.of(sheetContext).textTheme.titleLarge,
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
              const SizedBox(height: 10),
              Text(
                '${patient.etnia} • ${patient.municipio}, ${patient.departamento}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Fecha: $fecha · ${patient.zona} · ${patient.afiliacionSgsss}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              if (patient.direccionPaciente case final address?) ...[
                const SizedBox(height: 6),
                Text('Dirección: $address', style: const TextStyle(fontSize: 13)),
              ],
              if (patient.latitud != null && patient.longitud != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Ubicación: ${patient.latitud!.toStringAsFixed(5)}, '
                  '${patient.longitud!.toStringAsFixed(5)}'
                  '${patient.precisionGpsM == null ? '' : ' · precisión ${patient.precisionGpsM!.toStringAsFixed(1)} m'}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
              if (hasFacilities) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => _showNearbyFacilities(record),
                  icon: const Icon(Icons.local_hospital_outlined),
                  label: const Text('Centros cercanos'),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildMetricPill('Edad', '${patient.edadMaterna} años'),
                  _buildMetricPill('Controles', '${patient.numeroControles}'),
                  _buildMetricPill(
                    'PA',
                    '${patient.presionSistolica.toInt()}/${patient.presionDiastolica.toInt()} mmHg',
                  ),
                  _buildMetricPill('Hb', '${patient.hemoglobina} g/dL'),
                  _buildMetricPill('IMC', '${patient.imc}'),
                  _buildMetricPill('Sem', '${patient.semanasGestacion} sem'),
                  _buildMetricPill('Dist', '${patient.distanciaKm} km'),
                  _buildMetricPill(
                    'Traslado',
                    '${patient.tiempoTrasladoHoras} h',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Estimación del modelo de IA',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Riesgo alto: ${(result.probAlto * 100).toStringAsFixed(1)}%'
                      '${(result.probMedio > 0 || result.probBajo > 0) ? ' · Moderado: ${(result.probMedio * 100).toStringAsFixed(1)}% · Bajo: ${(result.probBajo * 100).toStringAsFixed(1)}%' : ''}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      'Desenlace adverso: ${(result.probDesenlaceAdverso * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
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
              if (record.consultationCode case final code?
                  when code.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                ConsultationCodeCard(code: code),
              ],
              if (provider.updateAssessment != null ||
                  provider.deleteAssessment != null) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    if (provider.updateAssessment != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: provider.isMutating
                              ? null
                              : () {
                                  Navigator.pop(sheetContext);
                                  _showEditDialog(context, provider, record);
                                },
                          icon: const Icon(Icons.edit_outlined, size: 18),
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
                            side: const BorderSide(color: AppColors.riskHigh),
                          ),
                          onPressed: provider.isMutating
                              ? null
                              : () => _confirmDelete(
                                  context,
                                  sheetContext,
                                  provider,
                                  record,
                                ),
                          icon: const Icon(Icons.delete_outline, size: 18),
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
