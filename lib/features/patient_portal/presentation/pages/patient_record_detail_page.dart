import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/services/patient_record_pdf_builder.dart';
import '../../domain/entities/patient_record_view.dart';
import '../../domain/usecases/lookup_patient_records_usecase.dart';
import '../providers/patient_portal_provider.dart';

class PatientRecordDetailPage extends StatefulWidget {
  final PatientRecordView record;
  final String patientDocument;
  final PatientRecordPdfBuilder pdfBuilder;

  const PatientRecordDetailPage({
    required this.record,
    required this.patientDocument,
    this.pdfBuilder = const PatientRecordPdfBuilder(),
    super.key,
  });

  @override
  State<PatientRecordDetailPage> createState() =>
      _PatientRecordDetailPageState();
}

class _PatientRecordDetailPageState extends State<PatientRecordDetailPage> {
  bool _isGeneratingPdf = false;

  Future<void> _downloadPdf() async {
    final portalProvider = context.read<PatientPortalProvider>();
    portalProvider.recordActivity();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Compartir resultado'),
        content: const Text(
          'El documento contiene información de salud. Compártalo solo con '
          'quien usted decida.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (portalProvider.result is! PatientRecordFound) return;
    portalProvider.recordActivity();

    setState(() => _isGeneratingPdf = true);
    try {
      final bytes = await widget.pdfBuilder.build(
        widget.record,
        patientDocument: widget.patientDocument,
      );
      if (!mounted || portalProvider.result is! PatientRecordFound) return;
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'resultado_${_safeFolio(widget.record.folio)}.pdf',
      );
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo generar o compartir el PDF. Inténtelo de nuevo.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  void _finishConsultation() {
    context.read<PatientPortalProvider>().clear();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) =>
          context.read<PatientPortalProvider>().recordActivity(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Detalle de la evaluación',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _RiskPanel(record: widget.record),
              if (widget.record.alertaClinicaInmediata == true) ...[
                const SizedBox(height: 12),
                _ImmediateAlert(record: widget.record),
              ],
              const SizedBox(height: 16),
              _DataSection(
                title: 'Datos de la evaluación',
                values: [
                  _DetailValue(
                    'Fecha y hora',
                    _dateTime(widget.record.fechaEvaluacion),
                  ),
                  _DetailValue('Folio', _text(widget.record.folio)),
                  _DetailValue(
                    'Municipio / departamento',
                    '${_text(widget.record.municipio)} / '
                        '${_text(widget.record.departamento)}',
                  ),
                  _DetailValue('Zona', _text(widget.record.zona)),
                  _DetailValue(
                    'Afiliación SGSSS',
                    _text(widget.record.afiliacionSgsss),
                  ),
                ],
              ),
              _DataSection(
                title: 'Datos de la gestante',
                values: [
                  _DetailValue(
                    'Edad',
                    _unit(widget.record.edadMaterna, 'años'),
                  ),
                  _DetailValue('Etnia', _text(widget.record.etnia)),
                  _DetailValue(
                    'Semanas de gestación',
                    _unit(widget.record.semanasGestacion, 'semanas'),
                  ),
                  _DetailValue(
                    'Controles prenatales',
                    _text(widget.record.numeroControles),
                  ),
                  _DetailValue(
                    'IMC',
                    _unit(widget.record.imc, 'kg/m²', decimals: 1),
                  ),
                ],
              ),
              _DataSection(
                title: 'Acceso a servicios',
                values: [
                  _DetailValue(
                    'Distancia',
                    _unit(widget.record.distanciaKm, 'km', decimals: 1),
                  ),
                  _DetailValue(
                    'Tiempo de traslado',
                    _unit(
                      widget.record.tiempoTrasladoHoras,
                      'horas',
                      decimals: 1,
                    ),
                  ),
                  _DetailValue(
                    'Parto institucional previo',
                    _yesNo(widget.record.partoInstitucionalPrevio),
                  ),
                ],
              ),
              _DataSection(
                title: 'Signos y laboratorio',
                values: [
                  _DetailValue(
                    'Presión arterial',
                    '${_number(widget.record.presionSistolica, decimals: 0)}/'
                        '${_number(widget.record.presionDiastolica, decimals: 0)} mmHg',
                  ),
                  _DetailValue(
                    'Hemoglobina',
                    _unit(widget.record.hemoglobina, 'g/dL', decimals: 1),
                  ),
                ],
              ),
              _DataSection(
                title: 'Antecedentes',
                values: [
                  _DetailValue(
                    'Preeclampsia',
                    _yesNo(widget.record.antecedentePreeclampsia),
                  ),
                  _DetailValue(
                    'Diabetes',
                    _yesNo(widget.record.antecedenteDiabetes),
                  ),
                ],
              ),
              _DataSection(
                title: 'Estimación del modelo',
                note: 'Es una estimación estadística y no un diagnóstico',
                values: [
                  _DetailValue(
                    'Probabilidad de riesgo alto',
                    _percentage(widget.record.probabilidadRiesgoAlto),
                  ),
                  _DetailValue(
                    'Probabilidad de desenlace adverso',
                    _percentage(widget.record.probabilidadDesenlaceAdverso),
                  ),
                ],
              ),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Text(
                    'Este resultado es una orientación y no reemplaza la '
                    'valoración de su médico.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _isGeneratingPdf ? null : _downloadPdf,
                icon: _isGeneratingPdf
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.picture_as_pdf_outlined),
                label: Text(
                  _isGeneratingPdf ? 'Generando PDF…' : 'Descargar PDF',
                ),
              ),
              OutlinedButton(
                onPressed: _finishConsultation,
                child: const Text('Terminar consulta'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RiskPanel extends StatelessWidget {
  final PatientRecordView record;

  const _RiskPanel({required this.record});

  @override
  Widget build(BuildContext context) {
    final level = record.nivelRiesgoPredicho?.trim() ?? '';
    final style = _riskStyle(level);
    return Card(
      color: style.$1.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(style.$2, color: style.$1, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    level.isEmpty ? 'Nivel no disponible' : level,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: style.$1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(style.$3),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImmediateAlert extends StatelessWidget {
  final PatientRecordView record;

  const _ImmediateAlert({required this.record});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFFEE2E2),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.emergencyRed),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.emergency_rounded,
          color: AppColors.emergencyRed,
          semanticLabel: 'Alerta clínica inmediata',
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            record.descripcionAlerta?.trim().isNotEmpty == true
                ? record.descripcionAlerta!
                : 'Se reportó una alerta clínica inmediata.',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.emergencyRed,
            ),
          ),
        ),
      ],
    ),
  );
}

class _DataSection extends StatelessWidget {
  final String title;
  final List<_DetailValue> values;
  final String? note;

  const _DataSection({required this.title, required this.values, this.note});

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < values.length; index++) ...[
            _DetailItem(value: values[index]),
            if (index < values.length - 1)
              const Divider(height: 16, color: AppColors.border),
          ],
          if (note case final text?) ...[
            const SizedBox(height: 10),
            Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class _DetailItem extends StatelessWidget {
  final _DetailValue value;

  const _DetailItem({required this.value});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value.label,
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 2),
      Text(value.value, softWrap: true),
    ],
  );
}

class _DetailValue {
  final String label;
  final String value;

  const _DetailValue(this.label, this.value);
}

(Color, IconData, String) _riskStyle(String level) => switch (level
    .toLowerCase()) {
  'bajo riesgo' => (
    AppColors.riskLow,
    Icons.check_circle_outline_rounded,
    'Su evaluación no mostró señales de alarma. Continúe sus controles prenatales.',
  ),
  'riesgo moderado' => (
    AppColors.riskMedium,
    Icons.warning_amber_rounded,
    'Se recomienda una valoración y seguimiento cercano en su centro de salud.',
  ),
  'alto riesgo obstétrico' => (
    AppColors.riskHigh,
    Icons.error_outline_rounded,
    'Acuda lo antes posible a su centro de salud.',
  ),
  _ => (
    AppColors.textSecondary,
    Icons.info_outline_rounded,
    'Consulte este resultado con su médico.',
  ),
};

String _safeFolio(String? folio) {
  final sanitized = (folio ?? '').replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  return sanitized.isEmpty ? 'evaluacion' : sanitized;
}

String _dateTime(DateTime? value) => value == null
    ? 'No disponible'
    : DateFormat('dd/MM/yyyy HH:mm').format(value.toLocal());

String _text(Object? value) => value?.toString() ?? 'No disponible';

String _number(num? value, {required int decimals}) =>
    value?.toDouble().toStringAsFixed(decimals) ?? 'No disponible';

String _unit(num? value, String unit, {int decimals = 0}) => value == null
    ? 'No disponible'
    : '${_number(value, decimals: decimals)} $unit';

String _yesNo(bool? value) => switch (value) {
  true => 'Sí',
  false => 'No',
  null => 'No disponible',
};

String _percentage(double? value) =>
    value == null ? 'No disponible' : '${(value * 100).toStringAsFixed(1)} %';
