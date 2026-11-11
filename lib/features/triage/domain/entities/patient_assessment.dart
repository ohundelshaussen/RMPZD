class PatientAssessment {
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

  const PatientAssessment({
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
  });
}
