import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/patient_assessment.dart';
import '../providers/triage_provider.dart';
import 'triage_result_page.dart';

class TriageFormPage extends StatefulWidget {
  const TriageFormPage({super.key});

  @override
  State<TriageFormPage> createState() => _TriageFormPageState();
}

class _TriageFormPageState extends State<TriageFormPage> {
  final _formKey = GlobalKey<FormState>();

  // Text Controllers
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

  // Categorical Selections
  String _departamento = 'La Guajira';
  String _municipio = 'Riohacha';
  String _etnia = 'Wayuu';
  String _zona = 'Rural dispersa';
  String _afiliacion = 'Subsidiado';

  // Antecedents
  bool _antecedentePreeclampsia = false;
  bool _antecedenteDiabetes = false;
  bool _partoInstitucionalPrevio = true;

  final List<String> _departamentos = ['La Guajira', 'Cesar'];
  final Map<String, List<String>> _municipiosPorDepto = {
    'La Guajira': [
      'Riohacha',
      'Uribia',
      'Manaure',
      'Maicao',
      'San Juan del Cesar',
      'Dibulla',
      'Fonseca',
      'Albania',
    ],
    'Cesar': [
      'Valledupar',
      'Pueblo Bello',
      'Agustín Codazzi',
      'La Paz',
      'Aguachica',
      'Bosconia',
      'Curumaní',
    ],
  };

  final List<String> _etnias = [
    'Wayuu',
    'No Indígena',
    'Arhuaco',
    'Wiwa',
    'Afrocolombiana',
    'Otro',
  ];

  final List<String> _zonas = [
    'Rural dispersa',
    'Rural nucleada',
    'Urbana',
  ];

  final List<String> _afiliaciones = [
    'Subsidiado',
    'Contributivo',
    'No Asegurado',
  ];

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
        // Caso Normal / Estable
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
        // Emergencia Hipertensiva en Alta Guajira (Criterio Inflexible)
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
        // Riesgo Moderado en Serranía
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

  void _submitForm() async {
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
      distanciaKm: double.parse(_distanciaController.text.trim()),
      tiempoTrasladoHoras: double.parse(_tiempoController.text.trim()),
      hemoglobina: double.parse(_hemoglobinaController.text.trim()),
      presionSistolica: double.parse(_sistolicaController.text.trim()),
      presionDiastolica: double.parse(_diastolicaController.text.trim()),
      imc: double.parse(_imcController.text.trim()),
      antecedentePreeclampsia: _antecedentePreeclampsia,
      antecedenteDiabetes: _antecedenteDiabetes,
      partoInstitucionalPrevio: _partoInstitucionalPrevio,
      afiliacionSgsss: _afiliacion,
      fechaEvaluacion: DateTime.now(),
    );

    final provider = context.read<TriageProvider>();
    await provider.evaluate(patient);

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const TriageResultPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Triage Materno'),
        actions: [
          // Offline Status indicator
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.bolt_rounded, size: 14, color: AppColors.primary),
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
          const SizedBox(width: 8),

          // Preset Selector Menu
          PopupMenuButton<int>(
            icon: const Icon(Icons.tune_rounded, color: AppColors.textPrimary),
            tooltip: 'Cargar casos para demostración',
            onSelected: _loadPreset,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 1,
                child: Text('Caso 1: Bajo Riesgo (Urbano)'),
              ),
              const PopupMenuItem(
                value: 2,
                child: Text('Caso 2: Emergencia Hipertensiva (Wayuu)'),
              ),
              const PopupMenuItem(
                value: 3,
                child: Text('Caso 3: Riesgo Moderado (Arhuaco)'),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Sección 1: Territorio y Población
              _buildSectionHeader('Territorio y Enfoque Diferencial'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _idController,
                        decoration: const InputDecoration(
                          labelText: 'Identificador / ID de Gestante',
                          prefixIcon: Icon(Icons.badge_outlined, size: 20),
                        ),
                        validator: (v) => v!.isEmpty ? 'Requerido' : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              key: ValueKey('depto_$_departamento'),
                              initialValue: _departamento,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Departamento'),
                              items: _departamentos
                                  .map((d) => DropdownMenuItem(value: d, child: Text(d, overflow: TextOverflow.ellipsis)))
                                  .toList(),
                              onChanged: (val) {
                                setState(() {
                                  _departamento = val!;
                                  _municipio = _municipiosPorDepto[_departamento]!.first;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              key: ValueKey('muni_$_municipio'),
                              initialValue: _municipio,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Municipio'),
                              items: _municipiosPorDepto[_departamento]!
                                  .map((m) => DropdownMenuItem(value: m, child: Text(m, overflow: TextOverflow.ellipsis)))
                                  .toList(),
                              onChanged: (val) => setState(() => _municipio = val!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              key: ValueKey('etnia_$_etnia'),
                              initialValue: _etnia,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Etnia'),
                              items: _etnias
                                  .map((e) => DropdownMenuItem(value: e, child: Text(e, overflow: TextOverflow.ellipsis)))
                                  .toList(),
                              onChanged: (val) => setState(() => _etnia = val!),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              key: ValueKey('zona_$_zona'),
                              initialValue: _zona,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Zona'),
                              items: _zonas
                                  .map((z) => DropdownMenuItem(value: z, child: Text(z, overflow: TextOverflow.ellipsis)))
                                  .toList(),
                              onChanged: (val) => setState(() => _zona = val!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        key: ValueKey('afiliacion_$_afiliacion'),
                        initialValue: _afiliacion,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Régimen de Salud (SGSSS)'),
                        items: _afiliaciones
                            .map((a) => DropdownMenuItem(value: a, child: Text(a, overflow: TextOverflow.ellipsis)))
                            .toList(),
                        onChanged: (val) => setState(() => _afiliacion = val!),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Sección 2: Signos Vitales y Laboratorio
              _buildSectionHeader('Signos Vitales y Laboratorio'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _sistolicaController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'PA Sistólica',
                                suffixText: 'mmHg',
                              ),
                              validator: (v) => v!.isEmpty ? 'Requerido' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _diastolicaController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'PA Diastólica',
                                suffixText: 'mmHg',
                              ),
                              validator: (v) => v!.isEmpty ? 'Requerido' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _hemoglobinaController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Hemoglobina',
                                suffixText: 'g/dL',
                              ),
                              validator: (v) => v!.isEmpty ? 'Requerido' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _imcController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'IMC',
                                suffixText: 'kg/m²',
                              ),
                              validator: (v) => v!.isEmpty ? 'Requerido' : null,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Sección 3: Datos de Gestación y Acceso
              _buildSectionHeader('Gestación y Acceso al Servicio'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _edadController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Edad Materna',
                                suffixText: 'años',
                              ),
                              validator: (v) => v!.isEmpty ? 'Requerido' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _semanasController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Semanas Gest.',
                                suffixText: 'sem',
                              ),
                              validator: (v) => v!.isEmpty ? 'Requerido' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _controlesController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Controles Realizados',
                              ),
                              validator: (v) => v!.isEmpty ? 'Requerido' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _distanciaController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Distancia Centro',
                                suffixText: 'km',
                              ),
                              validator: (v) => v!.isEmpty ? 'Requerido' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _tiempoController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Tiempo Estimado de Traslado',
                          suffixText: 'horas',
                        ),
                        validator: (v) => v!.isEmpty ? 'Requerido' : null,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Sección 4: Antecedentes Clínicos
              _buildSectionHeader('Antecedentes Clínicos'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
                      _buildSwitchRow(
                        title: 'Antecedente de Preeclampsia',
                        value: _antecedentePreeclampsia,
                        onChanged: (v) => setState(() => _antecedentePreeclampsia = v),
                      ),
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      _buildSwitchRow(
                        title: 'Antecedente de Diabetes Gestacional',
                        value: _antecedenteDiabetes,
                        onChanged: (v) => setState(() => _antecedenteDiabetes = v),
                      ),
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      _buildSwitchRow(
                        title: 'Parto Institucional Previo',
                        value: _partoInstitucionalPrevio,
                        onChanged: (v) => setState(() => _partoInstitucionalPrevio = v),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Botón de Evaluación
              Consumer<TriageProvider>(
                builder: (context, provider, _) {
                  return ElevatedButton.icon(
                    icon: provider.isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.health_and_safety_rounded, size: 20),
                    label: Text(
                      provider.isLoading ? 'Evaluando...' : 'EVALUAR RIESGO OBSTÉTRICO',
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildSwitchRow({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Switch.adaptive(
            value: value,
            activeTrackColor: AppColors.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
