import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/clinical_thresholds.dart';
import '../../../facilities/presentation/providers/nearest_facilities_provider.dart';
import '../../../facilities/presentation/services/facility_link_launcher.dart';
import '../../../facilities/presentation/widgets/nearest_facilities_section.dart';
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
    final record = widget.record;
    final hasFacilities =
        context.read<NearestFacilitiesProvider?>() != null &&
        context.read<FacilityLinkLauncher?>() != null &&
        (record.municipio != null || record.departamento != null);

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
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: [
                  _RiskPanel(record: record),
                  if (record.alertaClinicaInmediata == true) ...[
                    const SizedBox(height: 12),
                    _ImmediateAlert(record: record),
                  ],
                  const SizedBox(height: 16),
                  _ClinicalReportSheet(record: record),
                  if (hasFacilities) ...[
                    const SizedBox(height: 16),
                    NearestFacilitiesSection(
                      latitude: null,
                      longitude: null,
                      department: record.departamento,
                      municipality: record.municipio,
                      highRisk:
                          (record.alertaClinicaInmediata == true) ||
                          (record.nivelRiesgoPredicho
                                  ?.toLowerCase()
                                  .contains('alto') ??
                              false),
                      initiallyExpanded: false,
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(top: 1),
                          child: Icon(
                            Icons.info_outline_rounded,
                            size: 15,
                            color: AppColors.textMuted,
                          ),
                        ),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Este resultado es una orientación y no reemplaza la '
                            'valoración de su médico.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
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
                  const SizedBox(height: 10),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _finishConsultation,
                    child: const Text('Terminar consulta'),
                  ),
                ],
              ),
            ),
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
    final (accent, textTone, icon, guidance) = _riskStyle(level);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: textTone, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  level.isEmpty ? 'Nivel no disponible' : level,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: textTone,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  guidance,
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.4,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImmediateAlert extends StatelessWidget {
  final PatientRecordView record;

  const _ImmediateAlert({required this.record});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: const Color(0xFFFEF2F2),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.emergencyRed.withValues(alpha: 0.35)),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(11),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: AppColors.emergencyRed),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 1),
                      child: Icon(
                        Icons.emergency_rounded,
                        size: 20,
                        color: AppColors.emergencyRed,
                        semanticLabel: 'Alerta clínica inmediata',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        record.descripcionAlerta?.trim().isNotEmpty == true
                            ? record.descripcionAlerta!
                            : 'Se reportó una alerta clínica inmediata.',
                        style: const TextStyle(
                          fontSize: 13.5,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                          color: AppColors.emergencyRed,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ClinicalReportSheet extends StatelessWidget {
  final PatientRecordView record;

  const _ClinicalReportSheet({required this.record});

  @override
  Widget build(BuildContext context) {
    final bpTone = _bloodPressureTone(
      record.presionSistolica,
      record.presionDiastolica,
    );
    final hbTone = _hemoglobinTone(record.hemoglobina);
    final bmiTone = _bmiTone(record.imc);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _SectionLabel('Signos y laboratorio'),
                const SizedBox(height: 12),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _VitalMetricCell(
                          label: 'Presión arterial',
                          value:
                              '${_number(record.presionSistolica, decimals: 0)}/'
                              '${_number(record.presionDiastolica, decimals: 0)} mmHg',
                          emphasisColor: bpTone,
                        ),
                      ),
                      const VerticalDivider(
                        width: 24,
                        thickness: 1,
                        color: AppColors.border,
                      ),
                      Expanded(
                        child: _VitalMetricCell(
                          label: 'Hemoglobina',
                          value: _unit(
                            record.hemoglobina,
                            'g/dL',
                            decimals: 1,
                          ),
                          emphasisColor: hbTone,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _SectionLabel('Estimación del modelo'),
                const SizedBox(height: 12),
                _ProbabilityRow(
                  label: 'Probabilidad de riesgo alto',
                  probability: record.probabilidadRiesgoAlto,
                  displayValue: _percentage(record.probabilidadRiesgoAlto),
                  threshold: ClinicalThresholds.aiRiskHighThreshold,
                  highColor: AppColors.riskHigh,
                ),
                const SizedBox(height: 12),
                _ProbabilityRow(
                  label: 'Probabilidad de desenlace adverso',
                  probability: record.probabilidadDesenlaceAdverso,
                  displayValue: _percentage(
                    record.probabilidadDesenlaceAdverso,
                  ),
                  threshold: ClinicalThresholds.aiAdverseOutcomeThreshold,
                  highColor: AppColors.secondary,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Es una estimación estadística y no un diagnóstico',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: AppColors.border),
          _QuietDataSection(
            title: 'Datos de la gestante',
            values: [
              _DetailValue('Edad', _unit(record.edadMaterna, 'años')),
              _DetailValue('Etnia', _text(record.etnia)),
              _DetailValue(
                'Semanas de gestación',
                _unit(record.semanasGestacion, 'semanas'),
              ),
              _DetailValue(
                'Controles prenatales',
                _text(record.numeroControles),
              ),
              _DetailValue(
                'IMC',
                _unit(record.imc, 'kg/m²', decimals: 1),
                emphasisColor: bmiTone,
              ),
            ],
          ),
          const Divider(height: 1, thickness: 1, color: AppColors.border),
          _QuietDataSection(
            title: 'Antecedentes',
            values: [
              _DetailValue(
                'Preeclampsia',
                _yesNo(record.antecedentePreeclampsia),
                emphasisColor: record.antecedentePreeclampsia == true
                    ? AppColors.secondary
                    : null,
              ),
              _DetailValue(
                'Diabetes',
                _yesNo(record.antecedenteDiabetes),
                emphasisColor: record.antecedenteDiabetes == true
                    ? AppColors.secondary
                    : null,
              ),
            ],
          ),
          const Divider(height: 1, thickness: 1, color: AppColors.border),
          _QuietDataSection(
            title: 'Acceso a servicios',
            values: [
              _DetailValue(
                'Distancia',
                _unit(record.distanciaKm, 'km', decimals: 1),
              ),
              _DetailValue(
                'Tiempo de traslado',
                _unit(record.tiempoTrasladoHoras, 'horas', decimals: 1),
              ),
              _DetailValue(
                'Parto institucional previo',
                _yesNo(record.partoInstitucionalPrevio),
              ),
            ],
          ),
          const Divider(height: 1, thickness: 1, color: AppColors.border),
          _QuietDataSection(
            title: 'Datos de la evaluación',
            values: [
              _DetailValue('Fecha y hora', _dateTime(record.fechaEvaluacion)),
              _DetailValue('Folio', _text(record.folio), monospace: true),
              _DetailValue(
                'Municipio / departamento',
                '${_text(record.municipio)} / ${_text(record.departamento)}',
              ),
              _DetailValue('Zona', _text(record.zona)),
              _DetailValue('Afiliación SGSSS', _text(record.afiliacionSgsss)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

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

class _VitalMetricCell extends StatelessWidget {
  final String label;
  final String value;
  final Color? emphasisColor;

  const _VitalMetricCell({
    required this.label,
    required this.value,
    this.emphasisColor,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          if (emphasisColor != null) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: emphasisColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      Text(
        value,
        softWrap: true,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: emphasisColor ?? AppColors.textPrimary,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    ],
  );
}

class _ProbabilityRow extends StatelessWidget {
  final String label;
  final double? probability;
  final String displayValue;
  final double threshold;
  final Color highColor;

  const _ProbabilityRow({
    required this.label,
    required this.probability,
    required this.displayValue,
    required this.threshold,
    required this.highColor,
  });

  @override
  Widget build(BuildContext context) {
    final value = probability?.clamp(0.0, 1.0);
    final isElevated = value != null && value >= threshold;
    final barColor = isElevated ? highColor : AppColors.textMuted;

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
            const SizedBox(width: 12),
            Text(
              displayValue,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: isElevated ? highColor : AppColors.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        if (value != null) ...[
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 5,
              backgroundColor: AppColors.surfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(
                barColor.withValues(alpha: isElevated ? 0.85 : 0.45),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _QuietDataSection extends StatelessWidget {
  final String title;
  final List<_DetailValue> values;

  const _QuietDataSection({required this.title, required this.values});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(title),
        const SizedBox(height: 10),
        for (var index = 0; index < values.length; index++) ...[
          _DetailItem(value: values[index]),
          if (index < values.length - 1) const SizedBox(height: 8),
        ],
      ],
    ),
  );
}

class _DetailItem extends StatelessWidget {
  final _DetailValue value;

  const _DetailItem({required this.value});

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Text(
          value.label,
          style: const TextStyle(
            fontSize: 12.5,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      const SizedBox(width: 12),
      Flexible(
        child: Text(
          value.value,
          textAlign: TextAlign.end,
          softWrap: true,
          style: TextStyle(
            fontSize: 13,
            fontFamily: value.monospace ? 'monospace' : null,
            fontWeight: FontWeight.w600,
            color: value.emphasisColor ?? AppColors.textPrimary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    ],
  );
}

class _DetailValue {
  final String label;
  final String value;
  final Color? emphasisColor;
  final bool monospace;

  const _DetailValue(
    this.label,
    this.value, {
    this.emphasisColor,
    this.monospace = false,
  });
}

(Color, Color, IconData, String) _riskStyle(String level) =>
    switch (level.toLowerCase()) {
      'bajo riesgo' => (
        AppColors.riskLow,
        const Color(0xFF047857),
        Icons.check_circle_outline_rounded,
        'Su evaluación no mostró señales de alarma. Continúe sus controles prenatales.',
      ),
      'riesgo moderado' => (
        AppColors.riskMedium,
        const Color(0xFFB45309),
        Icons.warning_amber_rounded,
        'Se recomienda una valoración y seguimiento cercano en su centro de salud.',
      ),
      'alto riesgo obstétrico' => (
        AppColors.riskHigh,
        AppColors.emergencyRed,
        Icons.error_outline_rounded,
        'Acuda lo antes posible a su centro de salud.',
      ),
      _ => (
        AppColors.textSecondary,
        AppColors.textPrimary,
        Icons.info_outline_rounded,
        'Consulte este resultado con su médico.',
      ),
    };

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
