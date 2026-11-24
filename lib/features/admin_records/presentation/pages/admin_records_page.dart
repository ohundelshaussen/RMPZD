import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/colombia_locations.dart';
import '../../../../core/constants/form_options.dart';
import '../../../../shared/widgets/consultation_code_badge.dart';
import '../../../admin_users/presentation/pages/admin_users_page.dart';
import '../../../admin_users/presentation/providers/admin_users_provider.dart';
import '../../../auth/presentation/widgets/account_menu_button.dart';
import '../../../facilities/presentation/providers/nearest_facilities_provider.dart';
import '../../../facilities/presentation/widgets/nearest_facilities_section.dart';
import '../../domain/entities/remote_assessment.dart';
import '../../domain/repositories/admin_records_repository.dart';
import '../providers/admin_records_provider.dart';
import '../../../triage/domain/usecases/regenerate_consultation_code_usecase.dart';
import '../../../triage/presentation/widgets/consultation_code_card.dart';

class AdminRecordsPage extends StatefulWidget {
  const AdminRecordsPage({super.key});

  @override
  State<AdminRecordsPage> createState() => _AdminRecordsPageState();
}

class _AdminRecordsPageState extends State<AdminRecordsPage> {
  final _searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AdminRecordsProvider>().loadInitial();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value, AdminRecordsProvider provider) {
    _searchDebounce?.cancel();
    setState(() {});
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      final normalized = value.trim();
      provider.setFilters(
        _copyFilters(
          provider.filters,
          searchQuery: normalized.isEmpty ? null : normalized,
          clearSearch: normalized.isEmpty,
        ),
      );
    });
  }

  void _submitSearch(String value, AdminRecordsProvider provider) {
    _searchDebounce?.cancel();
    final normalized = value.trim();
    provider.setFilters(
      _copyFilters(
        provider.filters,
        searchQuery: normalized.isEmpty ? null : normalized,
        clearSearch: normalized.isEmpty,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminRecordsProvider>();
    final hasUsersFeature = context.read<AdminUsersProvider?>() != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registros'),
        actions: [
          if (hasUsersFeature)
            IconButton(
              tooltip: 'Gestión de usuarios',
              icon: const Icon(Icons.manage_accounts_outlined),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AdminUsersPage(),
                  ),
                );
              },
            ),
          const AccountMenuButton(),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(provider),
          Expanded(child: _buildContent(provider)),
        ],
      ),
    );
  }

  Widget _buildFilters(AdminRecordsProvider provider) {
    final filters = provider.filters;
    final doctors = provider.doctors;
    final selectedDoctor = filters.doctorId == null
        ? null
        : (doctors[filters.doctorId] ?? filters.doctorId);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onChanged: (value) => _onSearchChanged(value, provider),
            onSubmitted: (value) => _submitSearch(value, provider),
            decoration: InputDecoration(
              hintText: 'Buscar por paciente, código de consulta o ID usuario',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      tooltip: 'Limpiar búsqueda',
                      onPressed: () {
                        _searchController.clear();
                        _submitSearch('', provider);
                        setState(() {});
                      },
                      icon: const Icon(Icons.close_rounded, size: 18),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterPill(
                  label: filters.riskLevel ?? 'Riesgo',
                  selected: filters.riskLevel != null,
                  icon: Icons.health_and_safety_outlined,
                  onTap: () => _pickStringOption(
                    title: 'Nivel de riesgo',
                    options: {
                      for (final risk in provider.riskLevels) risk: risk,
                    },
                    selectedKey: filters.riskLevel,
                    showRiskDot: true,
                    onSelected: (value) => provider.setFilters(
                      _copyFilters(
                        filters,
                        riskLevel: value,
                        clearRisk: value == null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _FilterPill(
                  label: filters.department ?? 'Departamento',
                  selected: filters.department != null,
                  icon: Icons.location_city_outlined,
                  onTap: () => _pickStringOption(
                    title: 'Departamento',
                    options: {
                      for (final dept in provider.departments) dept: dept,
                    },
                    selectedKey: filters.department,
                    onSelected: (value) => provider.setFilters(
                      _copyFilters(
                        filters,
                        department: value,
                        clearDepartment: value == null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _FilterPill(
                  label: selectedDoctor ?? 'Médico',
                  selected: filters.doctorId != null,
                  icon: Icons.medical_services_outlined,
                  onTap: () => _pickStringOption(
                    title: 'Médico responsable',
                    options: doctors,
                    selectedKey: filters.doctorId,
                    enableSearch: doctors.length > 5,
                    onSelected: (value) => provider.setFilters(
                      _copyFilters(
                        filters,
                        doctorId: value,
                        clearDoctor: value == null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _FilterPill(
                  label: _dateRangeLabel(filters),
                  selected: filters.fromDate != null || filters.toDate != null,
                  icon: Icons.date_range_outlined,
                  onTap: () => _selectDateRange(provider, filters),
                ),
                if (filters.hasActiveFilters) ...[
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: const Icon(Icons.filter_alt_off_outlined, size: 16),
                    label: Text('Limpiar (${filters.activeFilterCount})'),
                    onPressed: () {
                      _searchDebounce?.cancel();
                      _searchController.clear();
                      provider.setFilters(const AdminAssessmentFilters());
                      setState(() {});
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickStringOption({
    required String title,
    required Map<String, String> options,
    required String? selectedKey,
    required ValueChanged<String?> onSelected,
    bool showRiskDot = false,
    bool enableSearch = false,
  }) async {
    final chosen = await showModalBottomSheet<({bool cleared, String? key})>(
      context: context,
      isScrollControlled: enableSearch,
      builder: (sheetContext) {
        var query = '';
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final entries = options.entries.where((entry) {
              if (query.trim().isEmpty) return true;
              final normalized = query.trim().toLowerCase();
              return entry.value.toLowerCase().contains(normalized) ||
                  entry.key.toLowerCase().contains(normalized);
            }).toList();

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  16 + MediaQuery.viewInsetsOf(sheetContext).bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(sheetContext).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (selectedKey != null)
                          TextButton(
                            onPressed: () => Navigator.pop(sheetContext, (
                              cleared: true,
                              key: null,
                            )),
                            child: const Text('Todos'),
                          ),
                      ],
                    ),
                    if (enableSearch) ...[
                      const SizedBox(height: 8),
                      TextField(
                        onChanged: (value) =>
                            setSheetState(() => query = value),
                        decoration: const InputDecoration(
                          hintText: 'Filtrar lista...',
                          prefixIcon: Icon(Icons.search_rounded, size: 18),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          ListTile(
                            dense: true,
                            leading: Icon(
                              selectedKey == null
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              color: selectedKey == null
                                  ? AppColors.primary
                                  : AppColors.textMuted,
                            ),
                            title: const Text('Todos'),
                            onTap: () => Navigator.pop(sheetContext, (
                              cleared: true,
                              key: null,
                            )),
                          ),
                          for (final entry in entries)
                            ListTile(
                              dense: true,
                              leading: showRiskDot
                                  ? Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: _riskBadgeColors(entry.value).$1,
                                      ),
                                    )
                                  : Icon(
                                      selectedKey == entry.key
                                          ? Icons.radio_button_checked
                                          : Icons.radio_button_off,
                                      color: selectedKey == entry.key
                                          ? AppColors.primary
                                          : AppColors.textMuted,
                                    ),
                              title: Text(entry.value),
                              trailing: selectedKey == entry.key
                                  ? const Icon(
                                      Icons.check_rounded,
                                      color: AppColors.primary,
                                      size: 18,
                                    )
                                  : null,
                              onTap: () => Navigator.pop(sheetContext, (
                                cleared: false,
                                key: entry.key,
                              )),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (chosen == null || !mounted) return;
    onSelected(chosen.cleared ? null : chosen.key);
  }

  Widget _buildContent(AdminRecordsProvider provider) {
    if (provider.errorMessage != null && provider.records.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                provider.isOffline
                    ? Icons.wifi_off_rounded
                    : Icons.error_outline,
                size: 44,
                color: AppColors.textMuted,
              ),
              const SizedBox(height: 12),
              Text(provider.errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: provider.isLoading ? null : provider.retry,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }
    if (provider.isLoading && provider.records.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.records.isEmpty) {
      return const Center(
        child: Text('No hay registros para estos filtros.'),
      );
    }

    return RefreshIndicator(
      onRefresh: provider.loadInitial,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        itemCount: provider.records.length + (provider.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == provider.records.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: provider.errorMessage != null
                    ? Column(
                        children: [
                          Text(
                            provider.errorMessage!,
                            textAlign: TextAlign.center,
                          ),
                          TextButton.icon(
                            onPressed: provider.isLoading
                                ? null
                                : provider.retry,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Reintentar'),
                          ),
                        ],
                      )
                    : provider.isLoading
                    ? const CircularProgressIndicator()
                    : FilledButton.tonal(
                        onPressed: provider.loadMore,
                        child: const Text('Cargar más'),
                      ),
              ),
            );
          }
          final record = provider.records[index];
          return _recordCard(context, record, provider);
        },
      ),
    );
  }

  Widget _recordCard(
    BuildContext context,
    RemoteAssessment record,
    AdminRecordsProvider provider,
  ) {
    final date = record.evaluationDate;
    final riskLabel = record.riskLevel ?? 'Riesgo no informado';
    final (Color badgeColor, Color badgeBg) = _riskBadgeColors(riskLabel);
    final hasPatientName = record.patientName != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showDetails(context, record, provider),
        child: Padding(
          padding: const EdgeInsets.all(14),
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
                          record.patientName ??
                              record.patientId ??
                              'Paciente sin identificador',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        if (hasPatientName && record.patientId != null)
                          Text(
                            'ID: ${record.patientId}',
                            style: const TextStyle(
                              fontSize: 12,
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
                      riskLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: badgeColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${record.municipality ?? 'Municipio no informado'}, '
                '${record.department ?? 'departamento no informado'}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              if (record.hasImmediateAlert ||
                  record.formattedConsultationCode != null) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (record.hasImmediateAlert)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              size: 15,
                              color: AppColors.emergencyRed,
                            ),
                            SizedBox(width: 5),
                            Text(
                              'Alerta clínica inmediata',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.emergencyRed,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (record.formattedConsultationCode case final code?)
                      ConsultationCodeBadge(code: code),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Médico: ${record.doctorName ?? 'No informado'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    date == null
                        ? 'Sin fecha'
                        : DateFormat('dd/MM/yyyy').format(date.toLocal()),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectDateRange(
    AdminRecordsProvider provider,
    AdminAssessmentFilters filters,
  ) async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: filters.fromDate != null && filters.toDate != null
          ? DateTimeRange(start: filters.fromDate!, end: filters.toDate!)
          : null,
    );
    if (range == null || !mounted) return;
    await provider.setFilters(
      _copyFilters(filters, fromDate: range.start, toDate: range.end),
    );
  }

  void _showDetails(
    BuildContext context,
    RemoteAssessment record,
    AdminRecordsProvider provider,
  ) {
    final canEditOrDelete = record.id != null;
    final hasFacilities = context.read<NearestFacilitiesProvider?>() != null;
    final riskLabel = record.riskLevel ?? 'Riesgo no informado';
    final (badgeColor, badgeBg) = _riskBadgeColors(riskLabel);
    final date = record.evaluationDate;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          builder: (sheetContext, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.patientName ??
                              record.patientId ??
                              'Detalle de evaluación',
                          style: Theme.of(sheetContext).textTheme.titleLarge,
                        ),
                        if (record.patientId != null)
                          Text(
                            'ID paciente: ${record.patientId}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
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
                      riskLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: badgeColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _detailSection('Paciente y ubicación', [
                _detailField('Identificador', record.patientId),
                if (record.patientName != null)
                  _detailField('Nombre', record.patientName),
                if (record.address != null)
                  _detailField('Dirección', record.address),
                _detailField(
                  'Territorio',
                  '${record.municipality ?? 'N/D'}, ${record.department ?? 'N/D'}',
                ),
                _detailField('Etnia', record.ethnicity),
                _detailField('Zona', record.zone),
                _detailField('Régimen SGSSS', record.affiliation),
                _detailField(
                  'Consentimiento de datos',
                  record.consentimientoDatos ? 'Autorizado' : 'No autorizado',
                ),
                if (record.latitude != null && record.longitude != null)
                  _detailField(
                    'Coordenadas GPS',
                    '${record.latitude!.toStringAsFixed(5)}, '
                        '${record.longitude!.toStringAsFixed(5)}'
                        '${record.gpsAccuracyM == null ? '' : ' (±${record.gpsAccuracyM!.toStringAsFixed(1)} m)'}',
                  ),
              ]),
              if (hasFacilities) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _showNearbyFacilities(record),
                  icon: const Icon(Icons.local_hospital_outlined),
                  label: const Text('Centros cercanos'),
                ),
              ],
              const SizedBox(height: 12),
              _detailSection('Datos clínicos y signos', [
                _detailField(
                  'Edad / Semanas',
                  '${record.age ?? '-'} años · ${record.weeks ?? '-'} sem',
                ),
                _detailField(
                  'Controles prenatales',
                  record.visits?.toString(),
                ),
                _detailField(
                  'Distancia / Traslado',
                  '${record.distanceKm ?? '-'} km · ${record.travelTimeHours ?? '-'} h',
                ),
                _detailField(
                  'Presión arterial',
                  record.systolic != null && record.diastolic != null
                      ? '${record.systolic!.toInt()}/${record.diastolic!.toInt()} mmHg'
                      : null,
                ),
                _detailField(
                  'Hemoglobina / IMC',
                  '${record.hemoglobin ?? '-'} g/dL · ${record.bmi ?? '-'} kg/m²',
                ),
                _detailField('Antec. preeclampsia', record.preeclampsiaHistory),
                _detailField('Antec. diabetes', record.diabetesHistory),
                _detailField(
                  'Parto institucional previo',
                  record.institutionalBirthHistory,
                ),
              ]),
              const SizedBox(height: 12),
              _detailSection('Estimación de IA y alerta', [
                _detailField(
                  'Prob. riesgo alto',
                  record.probHigh == null
                      ? null
                      : '${(record.probHigh! * 100).toStringAsFixed(1)} %',
                ),
                _detailField(
                  'Prob. desenlace adverso',
                  record.probAdverse == null
                      ? null
                      : '${(record.probAdverse! * 100).toStringAsFixed(1)} %',
                ),
                if (record.hasImmediateAlert)
                  _detailField(
                    'Alerta clínica',
                    record.alertDescription ?? 'Alerta inmediata activada',
                  ),
                if (record.formattedConsultationCode case final code?)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const Expanded(
                          flex: 2,
                          child: Text(
                            'Código de consulta',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: ConsultationCodeBadge(code: code),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  _detailField(
                    'Código de consulta',
                    record.hasConsultationCodeHash
                        ? 'Protegido en servidor (solo hash)'
                        : 'No disponible en nube',
                  ),
              ]),
              const SizedBox(height: 12),
              _detailSection('Auditoría del registro', [
                _detailField('Médico', record.doctorName ?? 'No informado'),
                if (record.doctorEmail != null)
                  _detailField('Correo del médico', record.doctorEmail),
                if (record.doctorId != null)
                  _detailField('ID de usuario (médico)', record.doctorId),
                if (record.id != null)
                  _detailField('ID de registro', record.id),
                _detailField(
                  'Fecha de evaluación',
                  date == null
                      ? null
                      : DateFormat('dd/MM/yyyy HH:mm').format(date.toLocal()),
                ),
              ]),
              if (record.id case final recordId?)
                if (sheetContext.read<RegenerateConsultationCodeUseCase?>()
                    case final regenerateUseCase?) ...[
                  const SizedBox(height: 12),
                  ConsultationCodeCard(
                    recordUuid: recordId,
                    regenerateUseCase: regenerateUseCase,
                    adminMode: true,
                  ),
                ],
              if (canEditOrDelete) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
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
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.riskHigh,
                          side: const BorderSide(color: AppColors.riskHigh),
                        ),
                        onPressed: provider.isMutating
                            ? null
                            : () => _confirmDeleteRecord(
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

  void _showNearbyFacilities(RemoteAssessment record) {
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
            latitude: record.latitude,
            longitude: record.longitude,
            department: record.department,
            municipality: record.municipality,
          ),
        ),
      ),
    );
  }

  Future<void> _showEditDialog(
    BuildContext context,
    AdminRecordsProvider provider,
    RemoteAssessment record,
  ) async {
    final id = record.id;
    if (id == null) return;

    final patientIdController = TextEditingController(
      text: record.patientId ?? '',
    );
    final nameController = TextEditingController(text: record.patientName ?? '');
    final addressController = TextEditingController(text: record.address ?? '');

    var department = colombiaDepartments.contains(record.department)
        ? record.department!
        : colombiaDepartments.first;
    final munis = municipalitiesByDepartment[department]!;
    var municipality = munis.contains(record.municipality)
        ? record.municipality!
        : munis.first;
    var ethnicity = ethnicities.contains(record.ethnicity)
        ? record.ethnicity!
        : ethnicities.first;
    var zone = residentialZones.contains(record.zone)
        ? record.zone!
        : residentialZones.first;
    var affiliation = healthAffiliations.contains(record.affiliation)
        ? record.affiliation!
        : healthAffiliations.first;
    var consent = record.consentimientoDatos;
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Editar registro remoto'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: patientIdController,
                    decoration: const InputDecoration(
                      labelText: 'ID de gestante',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Requerido'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: department,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Departamento',
                    ),
                    items: colombiaDepartments
                        .map(
                          (item) =>
                              DropdownMenuItem(value: item, child: Text(item)),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() {
                        department = value;
                        municipality = municipalitiesByDepartment[value]!.first;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    key: ValueKey('edit_muni_$department'),
                    initialValue: municipality,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Municipio'),
                    items: municipalitiesByDepartment[department]!
                        .map(
                          (item) =>
                              DropdownMenuItem(value: item, child: Text(item)),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => municipality = value);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: ethnicity,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Etnia'),
                    items: ethnicities
                        .map(
                          (item) =>
                              DropdownMenuItem(value: item, child: Text(item)),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => ethnicity = value);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: zone,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Zona'),
                    items: residentialZones
                        .map(
                          (item) =>
                              DropdownMenuItem(value: item, child: Text(item)),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setDialogState(() => zone = value);
                    },
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
                          (item) =>
                              DropdownMenuItem(value: item, child: Text(item)),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => affiliation = value);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: consent,
                    title: const Text(
                      'Conservar/editar nombre y dirección autorizados',
                      style: TextStyle(fontSize: 13),
                    ),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => consent = value);
                      }
                    },
                  ),
                  if (consent) ...[
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre completo de la paciente',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: addressController,
                      decoration: const InputDecoration(labelText: 'Dirección'),
                    ),
                  ],
                ],
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
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !context.mounted) {
      patientIdController.dispose();
      nameController.dispose();
      addressController.dispose();
      return;
    }

    final updates = <String, dynamic>{
      'patient_id': patientIdController.text.trim(),
      'departamento': department,
      'municipio': municipality,
      'etnia': ethnicity,
      'zona': zone,
      'afiliacion_sgsss': affiliation,
      'consentimiento_datos': consent,
      'nombre_paciente': consent && nameController.text.trim().isNotEmpty
          ? nameController.text.trim()
          : null,
      'direccion_paciente': consent && addressController.text.trim().isNotEmpty
          ? addressController.text.trim()
          : null,
      if (!consent) ...{
        'latitud': null,
        'longitud': null,
        'precision_gps_m': null,
        'ubicacion_capturada_at': null,
        'consentimiento_at': null,
      },
    };
    patientIdController.dispose();
    nameController.dispose();
    addressController.dispose();

    final result = await provider.editAssessment(id, updates);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: result.success
            ? AppColors.primary
            : AppColors.riskHigh,
        content: Text(result.message),
      ),
    );
  }

  Future<void> _confirmDeleteRecord(
    BuildContext pageContext,
    BuildContext sheetContext,
    AdminRecordsProvider provider,
    RemoteAssessment record,
  ) async {
    final id = record.id;
    if (id == null) return;

    final confirmed = await showDialog<bool>(
      context: pageContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar registro remoto'),
        content: Text(
          'Esta acción eliminará la evaluación de ${record.patientId ?? id} '
          'en Supabase (si las políticas del servidor lo autorizan).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.riskHigh),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !pageContext.mounted) return;

    final result = await provider.removeAssessment(id);
    if (!pageContext.mounted) return;
    if (result.success && sheetContext.mounted) {
      Navigator.pop(sheetContext);
    }
    ScaffoldMessenger.of(pageContext).showSnackBar(
      SnackBar(
        backgroundColor: result.success
            ? AppColors.primary
            : AppColors.riskHigh,
        content: Text(result.message),
      ),
    );
  }

  Widget _detailSection(String title, List<Widget> rows) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 8),
          ...rows,
        ],
      ),
    );
  }

  Widget _detailField(String label, Object? value) {
    final displayValue = value == null
        ? 'No informado'
        : value is bool
        ? (value ? 'Sí' : 'No')
        : value.toString();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              displayValue,
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  (Color, Color) _riskBadgeColors(String riskLabel) {
    if (riskLabel.contains('Alto')) {
      return (AppColors.riskHigh, const Color(0xFFFEE2E2));
    }
    if (riskLabel.contains('Moderado') || riskLabel.contains('Medio')) {
      return (AppColors.riskMedium, const Color(0xFFFEF3C7));
    }
    if (riskLabel.contains('Bajo')) {
      return (AppColors.riskLow, const Color(0xFFDCFCE7));
    }
    return (AppColors.textSecondary, AppColors.surfaceVariant);
  }

  String _dateRangeLabel(AdminAssessmentFilters filters) {
    if (filters.fromDate == null || filters.toDate == null) {
      return 'Fechas';
    }
    final format = DateFormat('dd/MM/yy');
    return '${format.format(filters.fromDate!)} - ${format.format(filters.toDate!)}';
  }

  AdminAssessmentFilters _copyFilters(
    AdminAssessmentFilters filters, {
    String? doctorId,
    String? riskLevel,
    String? department,
    DateTime? fromDate,
    DateTime? toDate,
    String? searchQuery,
    bool clearDoctor = false,
    bool clearRisk = false,
    bool clearDepartment = false,
    bool clearSearch = false,
  }) {
    return AdminAssessmentFilters(
      doctorId: clearDoctor ? null : doctorId ?? filters.doctorId,
      riskLevel: clearRisk ? null : riskLevel ?? filters.riskLevel,
      department: clearDepartment ? null : department ?? filters.department,
      fromDate: fromDate ?? filters.fromDate,
      toDate: toDate ?? filters.toDate,
      searchQuery: clearSearch ? null : searchQuery ?? filters.searchQuery,
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? AppColors.primary : AppColors.border;
    final bgColor = selected
        ? AppColors.primary.withValues(alpha: 0.1)
        : AppColors.surface;
    final fgColor = selected ? AppColors.primaryDark : AppColors.textPrimary;

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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: fgColor),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: fgColor,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: fgColor),
            ],
          ),
        ),
      ),
    );
  }
}
