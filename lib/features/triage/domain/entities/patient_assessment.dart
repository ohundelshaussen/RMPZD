class PatientAssessment {
  final int? id;
  final String patientId;
  final String municipio;
  final String departamento;
  final String etnia;
  final String zona;
  final int edadMaterna;
  final int semanasGestacion;
  final int numeroControles;
  final double distanciaKm;
  final double tiempoTrasladoHoras;
  final double hemoglobina;
  final double presionSistolica;
  final double presionDiastolica;
  final double imc;
  final bool antecedentePreeclampsia;
  final bool antecedenteDiabetes;
  final bool partoInstitucionalPrevio;
  final String afiliacionSgsss;
  final DateTime fechaEvaluacion;
  final bool sincronizado;

  const PatientAssessment({
    this.id,
    required this.patientId,
    required this.municipio,
    required this.departamento,
    required this.etnia,
    required this.zona,
    required this.edadMaterna,
    required this.semanasGestacion,
    required this.numeroControles,
    required this.distanciaKm,
    required this.tiempoTrasladoHoras,
    required this.hemoglobina,
    required this.presionSistolica,
    required this.presionDiastolica,
    required this.imc,
    required this.antecedentePreeclampsia,
    required this.antecedenteDiabetes,
    required this.partoInstitucionalPrevio,
    required this.afiliacionSgsss,
    required this.fechaEvaluacion,
    this.sincronizado = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patient_id': patientId,
      'municipio': municipio,
      'departamento': departamento,
      'etnia': etnia,
      'zona': zona,
      'edad_materna': edadMaterna,
      'semanas_gestacion': semanasGestacion,
      'numero_controles': numeroControles,
      'distancia_km': distanciaKm,
      'tiempo_traslado_horas': tiempoTrasladoHoras,
      'hemoglobina': hemoglobina,
      'presion_sistolica': presionSistolica,
      'presion_diastolica': presionDiastolica,
      'imc': imc,
      'antecedente_preeclampsia': antecedentePreeclampsia ? 1 : 0,
      'antecedente_diabetes': antecedenteDiabetes ? 1 : 0,
      'parto_institucional_previo': partoInstitucionalPrevio ? 1 : 0,
      'afiliacion_sgsss': afiliacionSgsss,
      'fecha_evaluacion': fechaEvaluacion.toIso8601String(),
      'sincronizado': sincronizado ? 1 : 0,
    };
  }

  factory PatientAssessment.fromMap(Map<String, dynamic> map) {
    return PatientAssessment(
      id: map['id'] as int?,
      patientId: map['patient_id'] as String,
      municipio: map['municipio'] as String,
      departamento: map['departamento'] as String,
      etnia: map['etnia'] as String,
      zona: map['zona'] as String,
      edadMaterna: map['edad_materna'] as int,
      semanasGestacion: map['semanas_gestacion'] as int,
      numeroControles: map['numero_controles'] as int,
      distanciaKm: (map['distancia_km'] as num).toDouble(),
      tiempoTrasladoHoras: (map['tiempo_traslado_horas'] as num).toDouble(),
      hemoglobina: (map['hemoglobina'] as num).toDouble(),
      presionSistolica: (map['presion_sistolica'] as num).toDouble(),
      presionDiastolica: (map['presion_diastolica'] as num).toDouble(),
      imc: (map['imc'] as num).toDouble(),
      antecedentePreeclampsia: (map['antecedente_preeclampsia'] as int) == 1,
      antecedenteDiabetes: (map['antecedente_diabetes'] as int) == 1,
      partoInstitucionalPrevio: (map['parto_institucional_previo'] as int) == 1,
      afiliacionSgsss: map['afiliacion_sgsss'] as String,
      fechaEvaluacion: DateTime.parse(map['fecha_evaluacion'] as String),
      sincronizado: (map['sincronizado'] as int? ?? 0) == 1,
    );
  }
}
