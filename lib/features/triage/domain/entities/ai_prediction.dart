import 'triage_result.dart';

class AiPrediction {
  final RiskLevel riskLevel;
  final double probAlto;
  final double probMedio;
  final double probBajo;
  final bool riesgoDesenlaceAdverso;
  final double probDesenlaceAdverso;

  const AiPrediction({
    required this.riskLevel,
    required this.probAlto,
    required this.probMedio,
    required this.probBajo,
    required this.riesgoDesenlaceAdverso,
    required this.probDesenlaceAdverso,
  });
}
