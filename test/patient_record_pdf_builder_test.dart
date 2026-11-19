import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:rmpzd/features/patient_portal/data/services/patient_record_pdf_builder.dart';
import 'package:rmpzd/features/patient_portal/domain/entities/patient_record_view.dart';

void main() {
  test(
    'builds a PDF with a masked document and no consultation code',
    () async {
      final builder = PatientRecordPdfBuilder(
        fontLoader: () async => PatientRecordPdfFonts(
          regular: pw.Font.helvetica(),
          bold: pw.Font.helveticaBold(),
        ),
      );
      final bytes = await builder.build(_record, patientDocument: 'CC12345678');
      final content = latin1.decode(bytes, allowInvalid: true);

      expect(latin1.decode(bytes.take(5).toList()), '%PDF-');
      expect(PatientRecordPdfBuilder.maskDocumentId('CC12345678'), '****5678');
      expect(content, isNot(contains('ABCD2345')));
    },
  );

  test(
    'falls back to PDF default fonts when app font assets are unavailable',
    () async {
      final bytes = await const PatientRecordPdfBuilder().build(
        _record,
        patientDocument: '12345678',
      );

      expect(latin1.decode(bytes.take(5).toList()), '%PDF-');
    },
  );
}

final _record = PatientRecordView(
  folio: 'FOLIO-2026-01',
  fechaEvaluacion: DateTime.utc(2026, 11, 16, 14, 30),
  nivelRiesgoPredicho: 'Riesgo Moderado',
  alertaClinicaInmediata: true,
  descripcionAlerta: 'Alerta prioritaria',
  municipio: 'Valledupar',
  departamento: 'Cesar',
  etnia: 'Wayuu',
  zona: 'Rural',
  edadMaterna: 29,
  semanasGestacion: 28,
  numeroControles: 4,
  distanciaKm: 12.0,
  tiempoTrasladoHoras: 1.5,
  hemoglobina: 11.2,
  presionSistolica: 120.0,
  presionDiastolica: 80.0,
  imc: 25.4,
  antecedentePreeclampsia: false,
  antecedenteDiabetes: true,
  partoInstitucionalPrevio: true,
  afiliacionSgsss: 'Subsidiado',
  probabilidadRiesgoAlto: 0.375,
  probabilidadDesenlaceAdverso: 0.5,
);
