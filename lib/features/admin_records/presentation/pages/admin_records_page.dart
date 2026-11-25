import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/clinical_thresholds.dart';
import '../../../../core/constants/colombia_locations.dart';
import '../../../../core/constants/form_options.dart';
import '../../../../shared/widgets/consultation_code_badge.dart';
import '../../../../shared/widgets/contact_phone_action.dart';
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

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
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
                        _submitSearch('', provider);
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
                const SizedBox(width: 6),
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
                const SizedBox(width: 6),
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
                const SizedBox(width: 6),
                _FilterPill(
                  label: _dateRangeLabel(filters),
                  selected: filters.fromDate != null || filters.toDate != null,
                  icon: Icons.date_range_outlined,
                  onTap: () => _selectDateRange(provider, filters),
                ),
                if (filters.hasActiveFilters) ...[
                  const SizedBox(width: 6),
                  TextButton.icon(
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
                    icon: const Icon(Icons.filter_alt_off_outlined, size: 15),
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
                                        color: _riskBadgeStyle(entry.value).$1,
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
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
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
    final isHighPriority =
        record.hasImmediateAlert || riskLabel.contains('Alto');
    final (badgeFg, badgeBg, badgeBorder) = _riskBadgeStyle(
      riskLabel,
      hasAlert: record.hasImmediateAlert,
    );
    final hasPatientName = record.patientName != null;

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
            onTap: () => _showDetails(context, record, provider),
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
                                      record.patientName ??
                                          record.patientId ??
                                          'Paciente sin identificador',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                        color: AppColors.textPrimary,
                                        letterSpacing: -0.1,
                                      ),
                                    ),
                                    if (hasPatientName &&
                                        record.patientId != null) ...[
                                      const SizedBox(height: 1),
                                      Text(
                                        'ID: ${record.patientId}',
                                        style: const TextStyle(
                                          fontSize: 12,
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
                                child: _AdminRiskPill(
                                  label: riskLabel,
                                  foreground: badgeFg,
                                  background: badgeBg,
                                  borderColor: badgeBorder,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${record.municipality ?? 'Municipio no informado'}, '
                            '${record.department ?? 'departamento no informado'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          if (record.hasImmediateAlert) ...[
                            const SizedBox(height: 6),
                            const Row(
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  size: 14,
                                  color: AppColors.emergencyRed,
                                ),
                                SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    'Alerta clínica inmediata',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.emergencyRed,
                                    ),
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
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Médico: ${record.doctorName ?? 'No informado'}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                date == null
                                    ? 'Sin fecha'
                                    : DateFormat(
                                        'dd/MM/yyyy',
                                      ).format(date.toLocal()),
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.textMuted,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ],
                          ),
                          if (record.formattedConsultationCode
                              case final code?) ...[
                            const SizedBox(height: 7),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: ConsultationCodeBadge(code: code),
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
    final (badgeFg, badgeBg, badgeBorder) = _riskBadgeStyle(
      riskLabel,
      hasAlert: record.hasImmediateAlert,
    );
    final date = record.evaluationDate;
    final formattedDate = date == null
        ? 'Sin fecha'
        : DateFormat('dd/MM/yyyy HH:mm').format(date.toLocal());
    final bpTone = _bloodPressureTone(record.systolic, record.diastolic);
    final hbTone = _hemoglobinTone(record.hemoglobin);
    final bmiTone = _bmiTone(record.bmi);

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
                          _AdminRiskPill(
                            label: riskLabel,
                            foreground: badgeFg,
                            background: AppColors.surface,
                            borderColor: badgeBorder,
                          ),
                          Text(
                            formattedDate,
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
                      record.patientName ??
                          record.patientId ??
                          'Detalle de evaluación',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (record.patientId != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'ID paciente: ${record.patientId}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      '${record.municipality ?? 'N/D'}, ${record.department ?? 'N/D'}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (record.hasImmediateAlert) ...[
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
                          record.alertDescription ??
                              'Alerta inmediata activada',
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
              const _AdminSectionTitle('Datos clínicos y signos'),
              const SizedBox(height: 10),
              _AdminMetricGrid(
                items: [
                  _AdminMetricItem(
                    label: 'Presión arterial',
                    value: record.systolic != null && record.diastolic != null
                        ? '${record.systolic!.toInt()}/${record.diastolic!.toInt()} mmHg'
                        : 'No informado',
                    emphasisColor: bpTone,
                  ),
                  _AdminMetricItem(
                    label: 'Hemoglobina',
                    value: record.hemoglobin != null
                        ? '${record.hemoglobin} g/dL'
                        : 'No informado',
                    emphasisColor: hbTone,
                  ),
                  _AdminMetricItem(
                    label: 'Edad',
                    value: record.age != null ? '${record.age} años' : '-',
                  ),
                  _AdminMetricItem(
                    label: 'Semanas',
                    value: record.weeks != null ? '${record.weeks} sem' : '-',
                  ),
                  _AdminMetricItem(
                    label: 'IMC',
                    value: record.bmi != null ? '${record.bmi} kg/m²' : '-',
                    emphasisColor: bmiTone,
                  ),
                  _AdminMetricItem(
                    label: 'Controles',
                    value: record.visits?.toString() ?? '-',
                  ),
                  _AdminMetricItem(
                    label: 'Distancia',
                    value: record.distanceKm != null
                        ? '${record.distanceKm} km'
                        : '-',
                  ),
                  _AdminMetricItem(
                    label: 'Traslado',
                    value: record.travelTimeHours != null
                        ? '${record.travelTimeHours} h'
                        : '-',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _detailField(
                'Antec. preeclampsia',
                record.preeclampsiaHistory,
                emphasisColor: record.preeclampsiaHistory == true
                    ? AppColors.secondary
                    : null,
              ),
              _detailField(
                'Antec. diabetes',
                record.diabetesHistory,
                emphasisColor: record.diabetesHistory == true
                    ? AppColors.secondary
                    : null,
              ),
              _detailField(
                'Parto institucional previo',
                record.institutionalBirthHistory,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Divider(height: 1, thickness: 1, color: AppColors.border),
              ),
              const _AdminSectionTitle('Estimación de IA'),
              const SizedBox(height: 10),
              _AdminProbabilityBar(
                label: 'Prob. riesgo alto',
                probability: record.probHigh,
                threshold: ClinicalThresholds.aiRiskHighThreshold,
                accentColor: AppColors.riskHigh,
              ),
              const SizedBox(height: 10),
              _AdminProbabilityBar(
                label: 'Prob. desenlace adverso',
                probability: record.probAdverse,
                threshold: ClinicalThresholds.aiAdverseOutcomeThreshold,
                accentColor: AppColors.secondary,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Divider(height: 1, thickness: 1, color: AppColors.border),
              ),
              const _AdminSectionTitle('Paciente y ubicación'),
              const SizedBox(height: 8),
              _detailField('Identificador', record.patientId),
              if (record.patientName != null)
                _detailField('Nombre', record.patientName),
              if (record.address != null)
                _detailField('Dirección', record.address),
              if (record.telefonoPaciente case final phone?)
                ContactPhoneAction(phone: phone),
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
              const _AdminSectionTitle('Código de consulta y auditoría'),
              const SizedBox(height: 8),
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
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
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
                  mutedValue: true,
                ),
              _detailField('Médico', record.doctorName ?? 'No informado'),
              if (record.doctorEmail != null)
                _detailField(
                  'Correo del médico',
                  record.doctorEmail,
                  mutedValue: true,
                ),
              if (record.doctorId != null)
                _detailField(
                  'ID de usuario (médico)',
                  record.doctorId,
                  monospace: true,
                  mutedValue: true,
                ),
              if (record.id != null)
                _detailField(
                  'ID de registro',
                  record.id,
                  monospace: true,
                  mutedValue: true,
                ),
              _detailField(
                'Fecha de evaluación',
                date == null
                    ? null
                    : DateFormat('dd/MM/yyyy HH:mm').format(date.toLocal()),
                mutedValue: true,
              ),
              if (record.id case final recordId?)
                if (sheetContext.read<RegenerateConsultationCodeUseCase?>()
                    case final regenerateUseCase?) ...[
                  const SizedBox(height: 14),
                  ConsultationCodeCard(
                    recordUuid: recordId,
                    regenerateUseCase: regenerateUseCase,
                    adminMode: true,
                  ),
                ],
              if (canEditOrDelete) ...[
                const SizedBox(height: 18),
                Row(
                  children: [
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
                    const SizedBox(width: 10),
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
                            : () => _confirmDeleteRecord(
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

  Widget _detailField(
    String label,
    Object? value, {
    Color? emphasisColor,
    bool monospace = false,
    bool mutedValue = false,
  }) {
    final displayValue = value == null
        ? 'No informado'
        : value is bool
        ? (value ? 'Sí' : 'No')
        : value.toString();
    final valueColor =
        emphasisColor ??
        (mutedValue ? AppColors.textSecondary : AppColors.textPrimary);

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
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(
              displayValue,
              style: TextStyle(
                fontSize: 12.5,
                fontFamily: monospace ? 'monospace' : null,
                fontWeight: mutedValue ? FontWeight.w500 : FontWeight.w600,
                color: valueColor,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  (Color, Color, Color) _riskBadgeStyle(
    String riskLabel, {
    bool hasAlert = false,
  }) {
    if (hasAlert) {
      return (
        AppColors.emergencyRed,
        const Color(0xFFFEF2F2),
        AppColors.emergencyRed.withValues(alpha: 0.30),
      );
    }
    if (riskLabel.contains('Alto')) {
      return (
        AppColors.riskHigh,
        const Color(0xFFFEF2F2),
        AppColors.riskHigh.withValues(alpha: 0.28),
      );
    }
    if (riskLabel.contains('Moderado') || riskLabel.contains('Medio')) {
      return (
        const Color(0xFFB45309),
        const Color(0xFFFFFBEB),
        AppColors.riskMedium.withValues(alpha: 0.32),
      );
    }
    if (riskLabel.contains('Bajo')) {
      return (
        const Color(0xFF047857),
        const Color(0xFFF0FDF4),
        AppColors.riskLow.withValues(alpha: 0.25),
      );
    }
    return (
      AppColors.textSecondary,
      AppColors.surfaceVariant,
      AppColors.border,
    );
  }

  Color? _bloodPressureTone(double? systolic, double? diastolic) {
    if (systolic == null && diastolic == null) return null;
    if ((systolic ?? 0) >= ClinicalThresholds.severeSystolicCrisis ||
        (diastolic ?? 0) >= ClinicalThresholds.severeDiastolicCrisis) {
      return AppColors.emergencyRed;
    }
    if ((systolic ?? 0) >= ClinicalThresholds.moderateSystolicCrisis ||
        (diastolic ?? 0) >= ClinicalThresholds.moderateDiastolicCrisis) {
      return AppColors.secondary;
    }
    return null;
  }

  Color? _hemoglobinTone(double? hemoglobin) {
    if (hemoglobin == null || hemoglobin <= 0) return null;
    if (hemoglobin < ClinicalThresholds.severeAnemia) {
      return AppColors.emergencyRed;
    }
    if (hemoglobin < ClinicalThresholds.mildAnemia) {
      return AppColors.secondary;
    }
    return null;
  }

  Color? _bmiTone(double? bmi) {
    if (bmi == null || bmi <= 0) return null;
    if (bmi < 18.5 || bmi >= 30.0) return AppColors.secondary;
    return null;
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
        ? AppColors.primary.withValues(alpha: 0.09)
        : AppColors.surface;
    final fgColor = selected ? AppColors.primaryDark : AppColors.textSecondary;
    final chevronColor = selected ? AppColors.primaryDark : AppColors.textMuted;

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
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: fgColor),
              const SizedBox(width: 5),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: fgColor,
                  ),
                ),
              ),
              const SizedBox(width: 3),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 15,
                color: chevronColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminRiskPill extends StatelessWidget {
  final String label;
  final Color foreground;
  final Color background;
  final Color borderColor;

  const _AdminRiskPill({
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
        color: foreground,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _AdminSectionTitle extends StatelessWidget {
  final String text;

  const _AdminSectionTitle(this.text);

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

class _AdminMetricItem {
  final String label;
  final String value;
  final Color? emphasisColor;

  const _AdminMetricItem({
    required this.label,
    required this.value,
    this.emphasisColor,
  });
}

class _AdminMetricGrid extends StatelessWidget {
  final List<_AdminMetricItem> items;

  const _AdminMetricGrid({required this.items});

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
              Expanded(child: _AdminMetricCell(item: left)),
              const VerticalDivider(
                width: 1,
                thickness: 1,
                color: AppColors.border,
              ),
              Expanded(
                child: right != null
                    ? _AdminMetricCell(item: right)
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

class _AdminMetricCell extends StatelessWidget {
  final _AdminMetricItem item;

  const _AdminMetricCell({required this.item});

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

class _AdminProbabilityBar extends StatelessWidget {
  final String label;
  final double? probability;
  final double threshold;
  final Color accentColor;

  const _AdminProbabilityBar({
    required this.label,
    required this.probability,
    required this.threshold,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = probability?.clamp(0.0, 1.0);
    final isElevated = clamped != null && clamped >= threshold;
    final barColor = isElevated ? accentColor : AppColors.textMuted;
    final displayText = probability == null
        ? 'No informado'
        : '${(probability! * 100).toStringAsFixed(1)} %';

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
              displayText,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isElevated ? accentColor : AppColors.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        if (clamped != null) ...[
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
      ],
    );
  }
}
