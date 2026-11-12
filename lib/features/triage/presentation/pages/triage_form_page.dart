import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/colombia_locations.dart';
import '../../domain/entities/patient_assessment.dart';
import '../providers/triage_provider.dart';
import '../widgets/clinical_history_section.dart';
import '../widgets/gestation_access_section.dart';
import '../widgets/territory_section.dart';
import '../widgets/vital_signs_section.dart';
import 'triage_result_page.dart';

class TriageFormPage extends StatefulWidget {
  const TriageFormPage({super.key});

  @override
  State<TriageFormPage> createState() => _TriageFormPageState();
}

class _TriageFormPageState extends State<TriageFormPage> {
  final _formKey = GlobalKey<FormState>();

  final _idController = TextEditingController();
  final _edadController = TextEditingController();
  final _semanasController = TextEditingController();
  final _controlesController = TextEditingController();
  final _distanciaController = TextEditingController();
  final _tiempoController = TextEditingController();
  final _hemoglobinaController = TextEditingController();
  final _sistolicaController = TextEditingController();
  final _diastolicaController = TextEditingController();
  final _imcController = TextEditingController();

  String _departamento = 'La Guajira';
  String _municipio = 'Riohacha';
  String _etnia = 'Wayuu';
  String _zona = 'Rural dispersa';
  String _afiliacion = 'Subsidiado';

  bool _antecedentePreeclampsia = false;
  bool _antecedenteDiabetes = false;
  bool _partoInstitucionalPrevio = false;

  @override
  void dispose() {
    _idController.dispose();
    _edadController.dispose();
    _semanasController.dispose();
    _controlesController.dispose();
    _distanciaController.dispose();
    _tiempoController.dispose();
    _hemoglobinaController.dispose();
    _sistolicaController.dispose();
    _diastolicaController.dispose();
    _imcController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final patient = PatientAssessment(
      patientId: _idController.text.trim(),
      municipio: _municipio,
      departamento: _departamento,
      etnia: _etnia,
      zona: _zona,
      edadMaterna: int.parse(_edadController.text.trim()),
      semanasGestacion: int.parse(_semanasController.text.trim()),
      numeroControles: int.parse(_controlesController.text.trim()),
      distanciaKm: _parseDouble(_distanciaController.text),
      tiempoTrasladoHoras: _parseDouble(_tiempoController.text),
      hemoglobina: _parseDouble(_hemoglobinaController.text),
      presionSistolica: _parseDouble(_sistolicaController.text),
      presionDiastolica: _parseDouble(_diastolicaController.text),
      imc: _parseDouble(_imcController.text),
      antecedentePreeclampsia: _antecedentePreeclampsia,
      antecedenteDiabetes: _antecedenteDiabetes,
      partoInstitucionalPrevio: _partoInstitucionalPrevio,
      afiliacionSgsss: _afiliacion,
      fechaEvaluacion: DateTime.now(),
    );

    await context.read<TriageProvider>().evaluate(patient);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TriageResultPage()),
    );
  }

  double _parseDouble(String value) {
    return double.parse(value.trim().replaceAll(',', '.'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Triage Materno'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bolt_rounded, size: 16, color: AppColors.primary),
                SizedBox(width: 4),
                Text(
                  'Offline IA',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TerritorySection(
                patientIdController: _idController,
                department: _departamento,
                municipality: _municipio,
                ethnicity: _etnia,
                zone: _zona,
                affiliation: _afiliacion,
                onDepartmentChanged: (department) {
                  setState(() {
                    _departamento = department;
                    _municipio = municipalitiesByDepartment[department]!.first;
                  });
                },
                onMunicipalityChanged: (value) =>
                    setState(() => _municipio = value),
                onEthnicityChanged: (value) => setState(() => _etnia = value),
                onZoneChanged: (value) => setState(() => _zona = value),
                onAffiliationChanged: (value) =>
                    setState(() => _afiliacion = value),
              ),
              VitalSignsSection(
                systolicController: _sistolicaController,
                diastolicController: _diastolicaController,
                hemoglobinController: _hemoglobinaController,
                bmiController: _imcController,
              ),
              GestationAccessSection(
                ageController: _edadController,
                weeksController: _semanasController,
                visitsController: _controlesController,
                distanceController: _distanciaController,
                travelTimeController: _tiempoController,
              ),
              ClinicalHistorySection(
                preeclampsia: _antecedentePreeclampsia,
                diabetes: _antecedenteDiabetes,
                institutionalBirth: _partoInstitucionalPrevio,
                onPreeclampsiaChanged: (value) =>
                    setState(() => _antecedentePreeclampsia = value),
                onDiabetesChanged: (value) =>
                    setState(() => _antecedenteDiabetes = value),
                onInstitutionalBirthChanged: (value) =>
                    setState(() => _partoInstitucionalPrevio = value),
              ),
              Consumer<TriageProvider>(
                builder: (context, provider, _) {
                  return ElevatedButton.icon(
                    icon: provider.isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.health_and_safety_rounded, size: 20),
                    label: Text(
                      provider.isLoading
                          ? 'Evaluando...'
                          : 'EVALUAR RIESGO OBSTÉTRICO',
                    ),
                    onPressed: provider.isLoading ? null : _submitForm,
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
