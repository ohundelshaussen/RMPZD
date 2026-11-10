import '../../../../core/constants/clinical_thresholds.dart';
import '../../domain/entities/clinical_alert.dart';
import '../../domain/entities/patient_assessment.dart';

class ClinicalRulesEngine {
  /// Evalúa signos de alarma y criterios obstétricos inflexibles
  List<ClinicalAlert> evaluate(PatientAssessment patient) {
    final alerts = <ClinicalAlert>[];

    // 1. REGLA ROJA: Crisis Hipertensiva en el Embarazo (ACOG / Guías Minsalud)
    if (patient.presionSistolica >= ClinicalThresholds.severeSystolicCrisis ||
        patient.presionDiastolica >= ClinicalThresholds.severeDiastolicCrisis) {
      alerts.add(const ClinicalAlert(
        title: '¡EMERGENCIA OBSTÉTRICA! Crisis Hipertensiva Severa',
        description:
            'Presión arterial en rango de severidad (≥ 160/110 mmHg). Alto riesgo inminente de eclampsia, ACV o desprendimiento prematuro de placenta.',
        severity: AlertSeverity.immediateEmergency,
        actionRequired:
            'Activar Código Rojo Obstétrico. Remisión médica de urgencia con transporte medicalizado prioritario.',
      ));
    } else if (patient.presionSistolica >= ClinicalThresholds.moderateSystolicCrisis ||
        patient.presionDiastolica >= ClinicalThresholds.moderateDiastolicCrisis) {
      alerts.add(const ClinicalAlert(
        title: 'Hipertensión Gestacional / Sospecha de Preeclampsia',
        description:
            'Presión arterial elevada (≥ 140/90 mmHg). Requiere confirmación con proteinuria y monitoreo hemodinámico.',
        severity: AlertSeverity.warning,
        actionRequired:
            'Remitir a valoración médica hospitalaria en menos de 24 horas y reposo estricto.',
      ));
    }

    // 2. REGLA ROJA: Anemia Severa
    if (patient.hemoglobina > 0 && patient.hemoglobina < ClinicalThresholds.severeAnemia) {
      alerts.add(const ClinicalAlert(
        title: '¡ALERTA CRÍTICA! Anemia Severa Gestacional',
        description:
            'Hemoglobina inferior a 7.0 g/dL. Compromiso severo de la oxigenación fetal y riesgo materno vital ante cualquier sangrado.',
        severity: AlertSeverity.immediateEmergency,
        actionRequired:
            'Remisión inmediata para valoración por gineco-obstetricia y soporte transfusional.',
      ));
    } else if (patient.hemoglobina > 0 && patient.hemoglobina < ClinicalThresholds.moderateAnemia) {
      alerts.add(const ClinicalAlert(
        title: 'Anemia Moderada',
        description: 'Hemoglobina entre 7.0 y 8.9 g/dL.',
        severity: AlertSeverity.warning,
        actionRequired: 'Iniciar micronutrientes / hierro parenteral bajo supervisión médica.',
      ));
    }

    // 3. Vulnerabilidad Logística y Geográfica Extrema (Alta Guajira / Serranía)
    if (patient.distanciaKm >= ClinicalThresholds.highDistanceKm ||
        patient.tiempoTrasladoHoras >= ClinicalThresholds.highTravelHours) {
      if (!patient.partoInstitucionalPrevio || patient.numeroControles <= 1) {
        alerts.add(const ClinicalAlert(
          title: 'Vulnerabilidad Geográfica Extrema en Zona Dispersa',
          description:
              'Distancia > 50 km o tiempo de traslado > 3 horas en paciente con controles insuficientes o sin antecedente institucional.',
          severity: AlertSeverity.warning,
          actionRequired:
              'Coordinar albergue materno o traslado preventivo antes de la semana 36 de gestación.',
        ));
      }
    }

    // 4. Antecedentes obstétricos de alto riesgo
    if (patient.antecedentePreeclampsia) {
      alerts.add(const ClinicalAlert(
        title: 'Antecedente de Preeclampsia Previa',
        description: 'Elevado riesgo de recurrencia en la gestación actual.',
        severity: AlertSeverity.warning,
        actionRequired: 'Monitoreo bisemanal de presión arterial y control prenatal especializado.',
      ));
    }

    return alerts;
  }
}
