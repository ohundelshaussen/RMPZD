import 'package:flutter_test/flutter_test.dart';
import 'package:rmpzd/features/triage/data/datasources/ai_inference_engine.dart';
import 'package:rmpzd/features/triage/domain/entities/ai_prediction.dart';
import 'package:rmpzd/features/triage/domain/entities/patient_assessment.dart';
import 'package:rmpzd/features/triage/domain/entities/triage_result.dart';

void main() {
  testWidgets('predicts three fixed inputs consistently', (tester) async {
    final engine = AiInferenceEngine();
    final patients = [
      _patient(),
      _patient(
        age: 33,
        weeks: 34,
        visits: 1,
        distance: 78,
        travelTime: 4.5,
        hemoglobin: 8.1,
        systolic: 165,
        diastolic: 112,
        bmi: 31.5,
        preeclampsia: true,
        institutionalBirth: false,
        municipality: 'Uribia',
        department: 'La Guajira',
        ethnicity: 'Wayuu',
        zone: 'Rural dispersa',
      ),
      _patient(
        age: 38,
        weeks: 20,
        visits: 2,
        distance: 42,
        travelTime: 2.8,
        hemoglobin: 9.8,
        systolic: 138,
        diastolic: 88,
        bmi: 28.9,
        diabetes: true,
        institutionalBirth: false,
        municipality: 'Pueblo Bello',
        ethnicity: 'Arhuaco',
      ),
    ];

    final predictions = [
      for (final patient in patients) await engine.predict(patient),
    ];
    expect(predictions, everyElement(isA<AiPrediction>()));
    for (final prediction in predictions) {
      expect(
        prediction.probAlto + prediction.probMedio + prediction.probBajo,
        closeTo(1, 1e-10),
      );
    }

    expect(predictions[0].riskLevel, RiskLevel.medio);
    expect(predictions[0].probAlto, closeTo(0.11877575410556117, 1e-12));
    expect(predictions[0].probMedio, closeTo(0.4879826327682368, 1e-12));
    expect(predictions[0].probBajo, closeTo(0.39324161312620215, 1e-12));
    expect(
      predictions[0].probDesenlaceAdverso,
      closeTo(0.1604579408848204, 1e-12),
    );
    expect(predictions[0].riesgoDesenlaceAdverso, isFalse);

    expect(predictions[1].riskLevel, RiskLevel.alto);
    expect(predictions[1].probAlto, closeTo(0.8687739690996161, 1e-12));
    expect(predictions[1].probMedio, closeTo(0.13038558280286963, 1e-12));
    expect(predictions[1].probBajo, closeTo(0.0008404480975141527, 1e-12));
    expect(
      predictions[1].probDesenlaceAdverso,
      closeTo(0.9572235802724557, 1e-12),
    );
    expect(predictions[1].riesgoDesenlaceAdverso, isTrue);

    expect(predictions[2].riskLevel, RiskLevel.medio);
    expect(predictions[2].probAlto, closeTo(0.2454486077776309, 1e-12));
    expect(predictions[2].probMedio, closeTo(0.6406159186205194, 1e-12));
    expect(predictions[2].probBajo, closeTo(0.1139354736018498, 1e-12));
    expect(
      predictions[2].probDesenlaceAdverso,
      closeTo(0.8837224033063374, 1e-12),
    );
    expect(predictions[2].riesgoDesenlaceAdverso, isTrue);
  });
}

PatientAssessment _patient({
  int age = 24,
  int weeks = 28,
  int visits = 3,
  double distance = 18.5,
  double travelTime = 1.8,
  double hemoglobin = 11.2,
  double systolic = 120,
  double diastolic = 75,
  double bmi = 25.4,
  bool preeclampsia = false,
  bool diabetes = false,
  bool institutionalBirth = true,
  String municipality = 'Valledupar',
  String department = 'Cesar',
  String ethnicity = 'No Indígena',
  String zone = 'Urbana',
}) {
  return PatientAssessment(
    patientId: 'MP-TEST',
    municipio: municipality,
    departamento: department,
    etnia: ethnicity,
    zona: zone,
    edadMaterna: age,
    semanasGestacion: weeks,
    numeroControles: visits,
    distanciaKm: distance,
    tiempoTrasladoHoras: travelTime,
    hemoglobina: hemoglobin,
    presionSistolica: systolic,
    presionDiastolica: diastolic,
    imc: bmi,
    antecedentePreeclampsia: preeclampsia,
    antecedenteDiabetes: diabetes,
    partoInstitucionalPrevio: institutionalBirth,
    afiliacionSgsss: ethnicity == 'Wayuu' ? 'Subsidiado' : 'Contributivo',
    fechaEvaluacion: DateTime(2026),
  );
}
