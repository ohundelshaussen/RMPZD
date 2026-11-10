class ClinicalThresholds {
  // Blood Pressure (ACOG / Guías Colombianas de Hipertensión Gestacional)
  static const double severeSystolicCrisis = 160.0;
  static const double severeDiastolicCrisis = 110.0;
  static const double moderateSystolicCrisis = 140.0;
  static const double moderateDiastolicCrisis = 90.0;

  // Anemia (OMS en el embarazo)
  static const double severeAnemia = 7.0; // g/dL
  static const double moderateAnemia = 9.0;
  static const double mildAnemia = 11.0;

  // Preterm critical border
  static const int pretermBorderWeeks = 37;

  // Rural dispersion thresholds
  static const double highDistanceKm = 50.0;
  static const double highTravelHours = 3.0;

  // AI Decision Thresholds (Derived in Phase 2 Experiments)
  static const double aiRiskHighThreshold = 0.25; // MLP Alto probability threshold
  static const double aiAdverseOutcomeThreshold = 0.30; // Logistic regression threshold
}
