import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/colombia_locations.dart';
import '../../../auth/presentation/widgets/account_menu_button.dart';
import '../../../facilities/presentation/providers/facility_provider.dart';
import '../../domain/entities/patient_assessment.dart';
import '../providers/triage_provider.dart';
import '../widgets/clinical_history_section.dart';
import '../widgets/gestation_access_section.dart';
import '../widgets/patient_identity_section.dart';
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
  PatientIdentityData _identityData = const PatientIdentityData();
  int _identityFormGeneration = 0;

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
      nombrePaciente: _identityData.consentimientoDatos
          ? _identityData.nombrePaciente
          : null,
      direccionPaciente: _identityData.consentimientoDatos
          ? _identityData.direccionPaciente
          : null,
      latitud: _identityData.consentimientoDatos ? _identityData.latitud : null,
      longitud: _identityData.consentimientoDatos
          ? _identityData.longitud
          : null,
      precisionGpsM: _identityData.consentimientoDatos
          ? _identityData.precisionGpsM
          : null,
      ubicacionCapturadaAt: _identityData.consentimientoDatos
          ? _identityData.ubicacionCapturadaAt
          : null,
      consentimientoDatos: _identityData.consentimientoDatos,
    );

    final triageProvider = context.read<TriageProvider>();
    await triageProvider.evaluate(patient);
    if (!mounted) return;
    final shouldReset = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const TriageResultPage()),
    );
    if (!mounted) return;
    if (shouldReset == true ||
        triageProvider.isSaved ||
        triageProvider.currentResult == null) {
      _resetForm();
      triageProvider.reset();
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _idController.clear();
    _edadController.clear();
    _semanasController.clear();
    _controlesController.clear();
    _distanciaController.clear();
    _tiempoController.clear();
    _hemoglobinaController.clear();
    _sistolicaController.clear();
    _diastolicaController.clear();
    _imcController.clear();
    setState(() {
      _departamento = 'La Guajira';
      _municipio = 'Riohacha';
      _etnia = 'Wayuu';
      _zona = 'Rural dispersa';
      _afiliacion = 'Subsidiado';
      _antecedentePreeclampsia = false;
      _antecedenteDiabetes = false;
      _partoInstitucionalPrevio = false;
      _identityData = const PatientIdentityData();
      _identityFormGeneration++;
    });
  }

  double _parseDouble(String value) {
    return double.parse(value.trim().replaceAll(',', '.'));
  }

  Future<void> _estimateDistanceToNearestFacility() async {
    final facilityProvider = context.read<FacilityProvider?>();
    final latitude = _identityData.latitud;
    final longitude = _identityData.longitud;
    if (facilityProvider == null || latitude == null || longitude == null) {
      return;
    }

    try {
      final nearest = await facilityProvider.findNearest(
        latitude: latitude,
        longitude: longitude,
        limit: 1,
      );
      if (!mounted) return;
      if (nearest.isEmpty || nearest.first.distanceKm == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No hay centros geocodificados cercanos disponibles.'),
          ),
        );
        return;
      }
      final facility = nearest.first;
      final kmText = facility.distanceKm!.toStringAsFixed(1);
      _distanciaController.text = kmText;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Distancia estimada: $kmText km hacia ${facility.name ?? 'centro más cercano'}',
          ),
        ),
      );
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo calcular la distancia aproximada.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Triage Materno'),
        actions: [
          IconButton(
            tooltip: 'Limpiar formulario',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _resetForm,
          ),
          const AccountMenuButton(),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
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
                        _municipio =
                            municipalitiesByDepartment[department]!.first;
                      });
                    },
                    onMunicipalityChanged: (value) =>
                        setState(() => _municipio = value),
                    onEthnicityChanged: (value) =>
                        setState(() => _etnia = value),
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
                  PatientIdentitySection(
                    key: ValueKey(_identityFormGeneration),
                    initialMunicipality: _municipio,
                    onChanged: (value) {
                      final locationChanged =
                          value.consentimientoDatos !=
                              _identityData.consentimientoDatos ||
                          value.latitud != _identityData.latitud ||
                          value.longitud != _identityData.longitud;
                      _identityData = value;
                      if (locationChanged) setState(() {});
                    },
                  ),
                  if (_identityData.consentimientoDatos &&
                      _identityData.latitud != null &&
                      _identityData.longitud != null &&
                      context.read<FacilityProvider?>() != null) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _estimateDistanceToNearestFacility,
                        icon: const Icon(Icons.straighten_rounded, size: 18),
                        label: const Text(
                          'Estimar distancia al centro más cercano',
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
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
                            : const Icon(
                                Icons.health_and_safety_rounded,
                                size: 20,
                              ),
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
        ),
      ),
    );
  }
}
