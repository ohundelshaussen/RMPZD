import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/remote_assessment.dart';
import '../../domain/repositories/admin_records_repository.dart';
import '../providers/admin_records_provider.dart';

class AdminRecordsPage extends StatefulWidget {
  const AdminRecordsPage({super.key});

  @override
  State<AdminRecordsPage> createState() => _AdminRecordsPageState();
}

class _AdminRecordsPageState extends State<AdminRecordsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AdminRecordsProvider>().loadInitial();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminRecordsProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Registros')),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _filterDropdown<String>(
            label: 'Médico',
            value: filters.doctorId,
            values: provider.doctors,
            onChanged: (value) => provider.setFilters(
              _copyFilters(filters, doctorId: value, clearDoctor: value == null),
            ),
          ),
          _filterDropdown<String>(
            label: 'Nivel de riesgo',
            value: filters.riskLevel,
            values: {for (final value in provider.riskLevels) value: value},
            onChanged: (value) => provider.setFilters(
              _copyFilters(filters, riskLevel: value, clearRisk: value == null),
            ),
          ),
          _filterDropdown<String>(
            label: 'Departamento',
            value: filters.department,
            values: {for (final value in provider.departments) value: value},
            onChanged: (value) => provider.setFilters(
              _copyFilters(
                filters,
                department: value,
                clearDepartment: value == null,
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => _selectDateRange(provider, filters),
            icon: const Icon(Icons.date_range_outlined),
            label: Text(_dateRangeLabel(filters)),
          ),
          if (filters.doctorId != null ||
              filters.riskLevel != null ||
              filters.department != null ||
              filters.fromDate != null ||
              filters.toDate != null)
            TextButton(
              onPressed: () => provider.setFilters(
                const AdminAssessmentFilters(),
              ),
              child: const Text('Limpiar'),
            ),
        ],
      ),
    );
  }

  Widget _filterDropdown<T>({
    required String label,
    required T? value,
    required Map<T, String> values,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButton<T>(
      hint: Text(label),
      value: values.containsKey(value) ? value : null,
      underline: const SizedBox.shrink(),
      items: [
        DropdownMenuItem<T>(value: null, child: Text('Todos: $label')),
        for (final entry in values.entries)
          DropdownMenuItem<T>(value: entry.key, child: Text(entry.value)),
      ],
      onChanged: onChanged,
    );
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
                provider.isOffline ? Icons.wifi_off_rounded : Icons.error_outline,
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
      return const Center(child: Text('No hay registros para estos filtros.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
        return _recordCard(context, record);
      },
    );
  }

  Widget _recordCard(BuildContext context, RemoteAssessment record) {
    final date = record.evaluationDate;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showDetails(context, record),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      record.patientId ?? 'Paciente sin identificador',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    record.riskLevel ?? 'Riesgo no informado',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${record.municipality ?? 'Municipio no informado'}, '
                '${record.department ?? 'departamento no informado'}',
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    record.hasImmediateAlert
                        ? Icons.warning_amber_rounded
                        : Icons.check_circle_outline,
                    size: 18,
                    color: record.hasImmediateAlert
                        ? AppColors.emergencyRed
                        : AppColors.riskLow,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      record.hasImmediateAlert
                          ? 'Alerta clínica inmediata'
                          : 'Sin alerta clínica inmediata',
                    ),
                  ),
                  Text(
                    date == null
                        ? 'Fecha no informada'
                        : DateFormat('dd/MM/yyyy').format(date),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text('Médico: ${record.doctorName ?? 'No informado'}'),
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

  void _showDetails(BuildContext context, RemoteAssessment record) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          maxChildSize: 0.95,
          builder: (context, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Detalle de ${record.patientId ?? 'evaluación'}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              for (final entry in record.fields.entries)
                _detailField(entry.key, entry.value),
              _detailField('médico', record.doctorName ?? 'No informado'),
              if (record.doctorEmail != null)
                _detailField('correo del médico', record.doctorEmail),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailField(String key, Object? value) {
    final label = key.replaceAll('_', ' ');
    final displayValue = value == null
        ? 'No informado'
        : value is bool
        ? (value ? 'Sí' : 'No')
        : value.toString();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(flex: 3, child: Text(displayValue)),
        ],
      ),
    );
  }

  String _dateRangeLabel(AdminAssessmentFilters filters) {
    if (filters.fromDate == null || filters.toDate == null) {
      return 'Fechas';
    }
    final format = DateFormat('dd/MM/yy');
    return '${format.format(filters.fromDate!)} – ${format.format(filters.toDate!)}';
  }

  AdminAssessmentFilters _copyFilters(
    AdminAssessmentFilters filters, {
    String? doctorId,
    String? riskLevel,
    String? department,
    DateTime? fromDate,
    DateTime? toDate,
    bool clearDoctor = false,
    bool clearRisk = false,
    bool clearDepartment = false,
  }) {
    return AdminAssessmentFilters(
      doctorId: clearDoctor ? null : doctorId ?? filters.doctorId,
      riskLevel: clearRisk ? null : riskLevel ?? filters.riskLevel,
      department: clearDepartment ? null : department ?? filters.department,
      fromDate: fromDate ?? filters.fromDate,
      toDate: toDate ?? filters.toDate,
    );
  }
}
