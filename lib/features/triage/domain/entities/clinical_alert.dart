enum AlertSeverity {
  immediateEmergency, // Crisis hipertensiva o hemorragia / Remisión URGENTE
  warning,           // Moderada, requiere seguimiento cercano
  informational,     // Parámetros estables
}

class ClinicalAlert {
  final String title;
  final String description;
  final AlertSeverity severity;
  final String actionRequired;

  const ClinicalAlert({
    required this.title,
    required this.description,
    required this.severity,
    required this.actionRequired,
  });
}
