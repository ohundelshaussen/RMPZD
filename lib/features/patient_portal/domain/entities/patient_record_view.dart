class PatientRecordView {
  final String? folio;
  final DateTime? fechaEvaluacion;
  final String? nivelRiesgoPredicho;
  final bool? alertaClinicaInmediata;
  final String? descripcionAlerta;
  final String? municipio;
  final String? departamento;
  final String? etnia;
  final String? zona;
  final int? edadMaterna;
  final int? semanasGestacion;
  final int? numeroControles;
  final double? distanciaKm;
  final double? tiempoTrasladoHoras;
  final double? hemoglobina;
  final double? presionSistolica;
  final double? presionDiastolica;
  final double? imc;
  final bool? antecedentePreeclampsia;
  final bool? antecedenteDiabetes;
  final bool? partoInstitucionalPrevio;
  final String? afiliacionSgsss;
  final double? probabilidadRiesgoAlto;
  final double? probabilidadDesenlaceAdverso;

  const PatientRecordView({
    this.folio,
    this.fechaEvaluacion,
    this.nivelRiesgoPredicho,
    this.alertaClinicaInmediata,
    this.descripcionAlerta,
    this.municipio,
    this.departamento,
    this.etnia,
    this.zona,
    this.edadMaterna,
    this.semanasGestacion,
    this.numeroControles,
    this.distanciaKm,
    this.tiempoTrasladoHoras,
    this.hemoglobina,
    this.presionSistolica,
    this.presionDiastolica,
    this.imc,
    this.antecedentePreeclampsia,
    this.antecedenteDiabetes,
    this.partoInstitucionalPrevio,
    this.afiliacionSgsss,
    this.probabilidadRiesgoAlto,
    this.probabilidadDesenlaceAdverso,
  });

  factory PatientRecordView.fromJson(Map<String, dynamic> json) =>
      PatientRecordView(
        folio: _stringValue(json['folio']),
        fechaEvaluacion: _dateTimeValue(json['fecha_evaluacion']),
        nivelRiesgoPredicho: _stringValue(json['nivel_riesgo_predicho']),
        alertaClinicaInmediata: _boolValue(json['alerta_clinica_inmediata']),
        descripcionAlerta: _stringValue(json['descripcion_alerta']),
        municipio: _stringValue(json['municipio']),
        departamento: _stringValue(json['departamento']),
        etnia: _stringValue(json['etnia']),
        zona: _stringValue(json['zona']),
        edadMaterna: _intValue(json['edad_materna']),
        semanasGestacion: _intValue(json['semanas_gestacion']),
        numeroControles: _intValue(json['numero_controles']),
        distanciaKm: _doubleValue(json['distancia_km']),
        tiempoTrasladoHoras: _doubleValue(json['tiempo_traslado_horas']),
        hemoglobina: _doubleValue(json['hemoglobina']),
        presionSistolica: _doubleValue(json['presion_sistolica']),
        presionDiastolica: _doubleValue(json['presion_diastolica']),
        imc: _doubleValue(json['imc']),
        antecedentePreeclampsia: _boolValue(json['antecedente_preeclampsia']),
        antecedenteDiabetes: _boolValue(json['antecedente_diabetes']),
        partoInstitucionalPrevio: _boolValue(
          json['parto_institucional_previo'],
        ),
        afiliacionSgsss: _stringValue(json['afiliacion_sgsss']),
        probabilidadRiesgoAlto: _doubleValue(json['probabilidad_riesgo_alto']),
        probabilidadDesenlaceAdverso: _doubleValue(
          json['probabilidad_desenlace_adverso'],
        ),
      );
}

String? _stringValue(Object? value) {
  if (value is String) return value;
  if (value is num) return value.toString();
  return null;
}

DateTime? _dateTimeValue(Object? value) {
  if (value is DateTime) return value;
  if (value is! String) return null;
  try {
    return DateTime.parse(value);
  } on FormatException {
    return null;
  }
}

int? _intValue(Object? value) => value is num ? value.toInt() : null;

double? _doubleValue(Object? value) => value is num ? value.toDouble() : null;

bool? _boolValue(Object? value) => value is bool ? value : null;
