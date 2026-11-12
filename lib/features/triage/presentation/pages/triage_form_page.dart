import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/colombia_locations.dart';
import '../../domain/entities/patient_assessment.dart';
import '../providers/triage_provider.dart';
import '../widgets/clinical_history_section.dart';
import '../widgets/demo_case_selector.dart';
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

  final _idController = TextEditingController(text: 'MP-01509');
  final _edadController = TextEditingController(text: '24');
  final _semanasController = TextEditingController(text: '28');
  final _controlesController = TextEditingController(text: '3');
  final _distanciaController = TextEditingController(text: '18.5');
  final _tiempoController = TextEditingController(text: '1.8');
  final _hemoglobinaController = TextEditingController(text: '11.2');
  final _sistolicaController = TextEditingController(text: '120');
  final _diastolicaController = TextEditingController(text: '75');
  final _imcController = TextEditingController(text: '25.4');

  String _departamento = 'La Guajira';
  String _municipio = 'Riohacha';
  String _etnia = 'Wayuu';
  String _zona = 'Rural dispersa';
  String _afiliacion = 'Subsidiado';

  bool _antecedentePreeclampsia = false;
  bool _antecedenteDiabetes = false;
  bool _partoInstitucionalPrevio = true;

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

  void _loadPreset(int presetType) {
    setState(() {
      if (presetType == 1) {
        _idController.text = 'MP-DEMO-BAJO';
        _departamento = 'Cesar';
        _municipio = 'Valledupar';
        _etnia = 'No Indígena';
        _zona = 'Urbana';
        _edadController.text = '26';
        _semanasController.text = '24';
        _controlesController.text = '5';
        _distanciaController.text = '3.0';
        _tiempoController.text = '0.4';
        _hemoglobinaController.text = '12.8';
        _sistolicaController.text = '115';
        _diastolicaController.text = '72';
        _imcController.text = '23.2';
        _antecedentePreeclampsia = false;
        _antecedenteDiabetes = false;
        _partoInstitucionalPrevio = true;
        _afiliacion = 'Contributivo';
      } else if (presetType == 2) {
        _idController.text = 'MP-DEMO-CRISIS';
        _departamento = 'La Guajira';
        _municipio = 'Uribia';
        _etnia = 'Wayuu';
        _zona = 'Rural dispersa';
        _edadController.text = '33';
        _semanasController.text = '34';
        _controlesController.text = '1';
        _distanciaController.text = '78.0';
        _tiempoController.text = '4.5';
        _hemoglobinaController.text = '8.1';
        _sistolicaController.text = '165';
        _diastolicaController.text = '112';
        _imcController.text = '31.5';
        _antecedentePreeclampsia = true;
        _antecedenteDiabetes = false;
        _partoInstitucionalPrevio = false;
        _afiliacion = 'Subsidiado';
      } else {
        _idController.text = 'MP-DEMO-MEDIO';
        _departamento = 'Cesar';
        _municipio = 'Pueblo Bello';
        _etnia = 'Arhuaco';
        _zona = 'Rural dispersa';
        _edadController.text = '38';
        _semanasController.text = '20';
        _controlesController.text = '2';
        _distanciaController.text = '42.0';
        _tiempoController.text = '2.8';
        _hemoglobinaController.text = '9.8';
        _sistolicaController.text = '138';
        _diastolicaController.text = '88';
        _imcController.text = '28.9';
        _antecedentePreeclampsia = false;
        _antecedenteDiabetes = true;
        _partoInstitucionalPrevio = false;
        _afiliacion = 'Subsidiado';
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        content: Text(
          presetType == 1
              ? 'Caso 1 cargado: Gestante Estable (Bajo Riesgo)'
              : presetType == 2
              ? 'Caso 2 cargado: Emergencia Hipertensiva Wayuu'
              : 'Caso 3 cargado: Riesgo Moderado en Serranía',
        ),
      ),
    );
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
        actions: [DemoCaseSelector(onSelected: _loadPreset)],
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
