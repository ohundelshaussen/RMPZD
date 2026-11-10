import 'clinical_alert.dart';

enum RiskLevel {
  bajo,
  medio,
  alto,
}

class TriageResult {
  final RiskLevel riskLevel;
  final double probAlto;
  final double probMedio;
  final double probBajo;
  
  // Predicción binaria de desenlace adverso (complicación obstétrica o mortalidad)
  final bool riesgoDesenlaceAdverso;
  final double probDesenlaceAdverso;

  // Alertas clínicas deterministas
  final List<ClinicalAlert> clinicalAlerts;
  final bool hasImmediateEmergency;

  const TriageResult({
    required this.riskLevel,
    required this.probAlto,
    required this.probMedio,
    required this.probBajo,
    required this.riesgoDesenlaceAdverso,
    required this.probDesenlaceAdverso,
    required this.clinicalAlerts,
    required this.hasImmediateEmergency,
  });

  String get riskLabel {
    switch (riskLevel) {
      case RiskLevel.bajo:
        return 'Bajo Riesgo';
      case RiskLevel.medio:
        return 'Riesgo Moderado';
      case RiskLevel.alto:
        return 'Alto Riesgo Obstétrico';
    }
  }
}
