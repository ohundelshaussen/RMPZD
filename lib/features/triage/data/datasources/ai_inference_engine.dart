import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart' show rootBundle;
import '../../domain/entities/patient_assessment.dart';
import '../../domain/entities/triage_result.dart';

class AiInferenceEngine {
  Map<String, dynamic>? _params;
  bool _isLoaded = false;

  Future<void> initialize() async {
    if (_isLoaded) return;
    try {
      final jsonString =
          await rootBundle.loadString('assets/models/model_parameters.json');
      _params = json.decode(jsonString) as Map<String, dynamic>;
      _isLoaded = true;
    } catch (e) {
      // In tests or if asset loading fails, parameters can be loaded synchronously
      _isLoaded = false;
    }
  }

  /// Ejecuta la inferencia offline del pipeline de IA
  Future<Map<String, dynamic>> predict(PatientAssessment patient) async {
    if (!_isLoaded || _params == null) {
      await initialize();
    }

    if (_params == null) {
      throw StateError('No se pudieron cargar los parámetros del modelo.');
    }

    // 1. Vector numérico (12 características)
    final numMeans = Map<String, double>.from(
      (_params!['numeric_scaler_means'] as Map).map(
        (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
      ),
    );
    final numScales = Map<String, double>.from(
      (_params!['numeric_scaler_scales'] as Map).map(
        (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
      ),
    );

    final rawNumeric = {
      'edad_materna': patient.edadMaterna.toDouble(),
      'semanas_gestacion_control': patient.semanasGestacion.toDouble(),
      'numero_controles_prenatales': patient.numeroControles.toDouble(),
      'distancia_centro_salud_km': patient.distanciaKm,
      'tiempo_traslado_horas': patient.tiempoTrasladoHoras,
      'hemoglobina_g_dl': patient.hemoglobina,
      'presion_sistolica': patient.presionSistolica,
      'presion_diastolica': patient.presionDiastolica,
      'imc': patient.imc,
      'antecedente_preeclampsia': patient.antecedentePreeclampsia ? 1.0 : 0.0,
      'antecedente_diabetes_gestacional':
          patient.antecedenteDiabetes ? 1.0 : 0.0,
      'parto_institucional_previo':
          patient.partoInstitucionalPrevio ? 1.0 : 0.0,
    };

    final scaledNumeric = <double>[];
    for (final col in _params!['numeric_columns']) {
      final val = rawNumeric[col] ?? 0.0;
      final mean = numMeans[col] ?? 0.0;
      final scale = numScales[col] ?? 1.0;
      scaledNumeric.add((val - mean) / (scale == 0 ? 1.0 : scale));
    }

    // 2. Vector categórico (One-Hot Encoding - 20 columnas)
    final rawCategorical = {
      'municipio': patient.municipio.trim(),
      'departamento': patient.departamento.trim(),
      'etnia': patient.etnia.trim(),
      'zona': patient.zona.trim(),
      'afiliacion_sgsss': patient.afiliacionSgsss.trim(),
    };

    final encodedCategorical = <double>[];
    final catCols = List<String>.from(_params!['categorical_columns']);
    final categoriesMap = _params!['categorical_categories'] as Map;

    for (final col in catCols) {
      final possibleCats = List<String>.from(categoriesMap[col]);
      final actualVal = rawCategorical[col] ?? '';
      for (final cat in possibleCats) {
        if (actualVal.toLowerCase() == cat.toLowerCase()) {
          encodedCategorical.add(1.0);
        } else {
          encodedCategorical.add(0.0);
        }
      }
    }

    // 3. Vector completo de 32 dimensiones
    final x = [...scaledNumeric, ...encodedCategorical];

    // 4. Inferencia: Nivel de Riesgo (Multiclase: Alto, Bajo, Medio)
    final riesgoCoef = (_params!['riesgo_coef'] as List)
        .map((row) => (row as List).map((v) => (v as num).toDouble()).toList())
        .toList();
    final riesgoIntercept = (_params!['riesgo_intercept'] as List)
        .map((v) => (v as num).toDouble())
        .toList();
    final riesgoClasses = List<String>.from(_params!['riesgo_classes']);

    final logits = <double>[];
    for (var k = 0; k < riesgoClasses.length; k++) {
      var z = riesgoIntercept[k];
      for (var j = 0; j < x.length; j++) {
        z += riesgoCoef[k][j] * x[j];
      }
      logits.add(z);
    }

    // Softmax
    final maxLogit = logits.reduce(math.max);
    final expList = logits.map((z) => math.exp(z - maxLogit)).toList();
    final sumExp = expList.reduce((a, b) => a + b);
    final probs = expList.map((e) => e / sumExp).toList();

    final probMap = <String, double>{};
    for (var k = 0; k < riesgoClasses.length; k++) {
      probMap[riesgoClasses[k]] = probs[k];
    }

    final pAlto = probMap['Alto'] ?? 0.0;
    final pMedio = probMap['Medio'] ?? 0.0;
    final pBajo = probMap['Bajo'] ?? 0.0;

    // Regla de decisión con umbral calibrado de Fase 2 (0.25 para clase Alto)
    final thresholdAlto =
        (_params!['riesgo_threshold_alto'] as num?)?.toDouble() ?? 0.25;
    RiskLevel assignedLevel;
    if (pAlto >= thresholdAlto) {
      assignedLevel = RiskLevel.alto;
    } else if (pMedio >= pBajo) {
      assignedLevel = RiskLevel.medio;
    } else {
      assignedLevel = RiskLevel.bajo;
    }

    // 5. Inferencia: Desenlace Adverso (Binaria: Normal vs Complicación/Mortalidad)
    final desenlaceCoef = (_params!['desenlace_coef'] as List)[0] as List;
    final desenlaceIntercept =
        ((_params!['desenlace_intercept'] as List)[0] as num).toDouble();
    final thresholdAdverso =
        (_params!['desenlace_threshold_adverso'] as num?)?.toDouble() ?? 0.30;

    var zDes = desenlaceIntercept;
    for (var j = 0; j < x.length; j++) {
      zDes += (desenlaceCoef[j] as num).toDouble() * x[j];
    }
    final pAdverso = 1.0 / (1.0 + math.exp(-zDes));
    final hasAdverseRisk = pAdverso >= thresholdAdverso;

    return {
      'risk_level': assignedLevel,
      'prob_alto': pAlto,
      'prob_medio': pMedio,
      'prob_bajo': pBajo,
      'prob_desenlace_adverso': pAdverso,
      'riesgo_desenlace_adverso': hasAdverseRisk,
    };
  }
}
