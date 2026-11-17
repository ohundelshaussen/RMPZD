import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;

import '../../domain/entities/patient_record_view.dart';

class PatientRecordPdfFonts {
  final pw.Font regular;
  final pw.Font bold;

  const PatientRecordPdfFonts({required this.regular, required this.bold});
}

typedef PatientRecordPdfFontLoader = Future<PatientRecordPdfFonts> Function();

class PatientRecordPdfBuilder {
  static const regularFontAsset = 'assets/fonts/Roboto-Regular.ttf';
  static const boldFontAsset = 'assets/fonts/Roboto-Bold.ttf';

  final PatientRecordPdfFontLoader? fontLoader;

  const PatientRecordPdfBuilder({this.fontLoader});

  static String maskDocumentId(String document) {
    final trimmed = document.trim();
    if (trimmed.length <= 4) return '****';
    return '****${trimmed.substring(trimmed.length - 4)}';
  }

  Future<Uint8List> build(
    PatientRecordView record, {
    required String patientDocument,
  }) async {
    final fonts = await _loadFonts();
    final regular = fonts.regular;
    final bold = fonts.bold;
    final document = pw.Document();
    final date = record.fechaEvaluacion == null
        ? 'No disponible'
        : DateFormat(
            'dd/MM/yyyy HH:mm',
          ).format(record.fechaEvaluacion!.toLocal());

    document.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
        build: (context) => [
          pw.Text(
            'Resultado de evaluación de riesgo materno-perinatal',
            style: pw.TextStyle(font: bold, fontSize: 20),
          ),
          pw.SizedBox(height: 4),
          pw.Text('RMPZD'),
          pw.Text(
            'Generado: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
          ),
          pw.SizedBox(height: 12),
          _pdfSection('Datos de la evaluación', [
            ('Fecha y hora', date),
            ('Folio', _text(record.folio)),
            (
              'Municipio / departamento',
              '${_text(record.municipio)} / ${_text(record.departamento)}',
            ),
            ('Zona', _text(record.zona)),
            ('Afiliación SGSSS', _text(record.afiliacionSgsss)),
            ('Documento de la paciente', maskDocumentId(patientDocument)),
          ], bold),
          pw.SizedBox(height: 10),
          _riskPanel(record, bold),
          if (record.alertaClinicaInmediata == true) ...[
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: const pdf.PdfColor(1, 0.9, 0.9),
                border: pw.Border.all(color: const pdf.PdfColor(0.7, 0, 0)),
              ),
              child: pw.Text(
                'Alerta clínica inmediata: '
                '${record.descripcionAlerta?.trim().isNotEmpty == true ? record.descripcionAlerta : 'Se reportó una alerta clínica inmediata.'}',
                style: pw.TextStyle(
                  font: bold,
                  color: const pdf.PdfColor(0.7, 0, 0),
                ),
              ),
            ),
          ],
          pw.SizedBox(height: 12),
          _pdfSection('Datos de la gestante', [
            ('Edad materna', _unit(record.edadMaterna, 'años')),
            ('Etnia', _text(record.etnia)),
            ('Semanas de gestación', _unit(record.semanasGestacion, 'semanas')),
            ('Controles prenatales', _text(record.numeroControles)),
            ('IMC', _unit(record.imc, 'kg/m²', decimals: 1)),
          ], bold),
          pw.SizedBox(height: 10),
          _pdfSection('Acceso a servicios', [
            ('Distancia', _unit(record.distanciaKm, 'km', decimals: 1)),
            (
              'Tiempo de traslado',
              _unit(record.tiempoTrasladoHoras, 'horas', decimals: 1),
            ),
            (
              'Parto institucional previo',
              _yesNo(record.partoInstitucionalPrevio),
            ),
          ], bold),
          pw.SizedBox(height: 10),
          _pdfSection('Signos y laboratorio', [
            (
              'Presión arterial',
              '${_number(record.presionSistolica, decimals: 0)}/'
                  '${_number(record.presionDiastolica, decimals: 0)} mmHg',
            ),
            ('Hemoglobina', _unit(record.hemoglobina, 'g/dL', decimals: 1)),
          ], bold),
          pw.SizedBox(height: 10),
          _pdfSection('Antecedentes', [
            (
              'Antecedente de preeclampsia',
              _yesNo(record.antecedentePreeclampsia),
            ),
            ('Antecedente de diabetes', _yesNo(record.antecedenteDiabetes)),
          ], bold),
          pw.SizedBox(height: 10),
          _pdfSection('Estimación del modelo', [
            (
              'Probabilidad de riesgo alto',
              _percentage(record.probabilidadRiesgoAlto),
            ),
            (
              'Probabilidad de desenlace adverso',
              _percentage(record.probabilidadDesenlaceAdverso),
            ),
          ], bold),
          pw.SizedBox(height: 4),
          pw.Text('Es una estimación estadística y no un diagnóstico.'),
          pw.SizedBox(height: 12),
          pw.Text(
            'Este resultado es una orientación y no reemplaza la valoración '
            'de su médico.',
            style: pw.TextStyle(font: bold),
          ),
        ],
      ),
    );

    return document.save();
  }

  Future<PatientRecordPdfFonts> _loadFonts() async {
    try {
      return await (fontLoader ?? _loadAssetFonts)();
    } on Object {
      return PatientRecordPdfFonts(
        regular: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
      );
    }
  }

  Future<PatientRecordPdfFonts> _loadAssetFonts() async {
    final regularData = await rootBundle.load(regularFontAsset);
    final boldData = await rootBundle.load(boldFontAsset);
    return PatientRecordPdfFonts(
      regular: pw.Font.ttf(regularData),
      bold: pw.Font.ttf(boldData),
    );
  }
}

pw.Widget _pdfSection(
  String title,
  List<(String, String)> rows,
  pw.Font bold,
) => pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
    pw.Text(title, style: pw.TextStyle(font: bold, fontSize: 14)),
    pw.SizedBox(height: 5),
    for (final (label, value) in rows)
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 150,
              child: pw.Text(label, style: pw.TextStyle(font: bold)),
            ),
            pw.Expanded(child: pw.Text(value)),
          ],
        ),
      ),
  ],
);

pw.Widget _riskPanel(PatientRecordView record, pw.Font bold) {
  final level = record.nivelRiesgoPredicho?.trim() ?? '';
  final normalized = level.toLowerCase();
  final (pdf.PdfColor color, String guidance) = switch (normalized) {
    'bajo riesgo' => (
      const pdf.PdfColor(0.06, 0.55, 0.36),
      'Su evaluación no mostró señales de alarma. Continúe sus controles prenatales.',
    ),
    'riesgo moderado' => (
      const pdf.PdfColor(0.76, 0.43, 0.02),
      'Se recomienda una valoración y seguimiento cercano en su centro de salud.',
    ),
    'alto riesgo obstétrico' => (
      const pdf.PdfColor(0.75, 0.09, 0.12),
      'Acuda lo antes posible a su centro de salud.',
    ),
    _ => (
      const pdf.PdfColor(0.35, 0.4, 0.45),
      'Consulte este resultado con su médico.',
    ),
  };
  return pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      color: const pdf.PdfColor(0.96, 0.96, 0.96),
      border: pw.Border.all(color: color, width: 2),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          level.isEmpty ? 'Nivel no disponible' : level,
          style: pw.TextStyle(font: bold, color: color, fontSize: 15),
        ),
        pw.SizedBox(height: 4),
        pw.Text(guidance),
      ],
    ),
  );
}

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
