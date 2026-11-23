import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/app_logo.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../../domain/usecases/lookup_patient_records_usecase.dart';
import '../providers/patient_portal_provider.dart';
import 'patient_record_detail_page.dart';

const _privacyNote =
    'Sus datos se usan únicamente para consultar su resultado y se borran '
    'de este dispositivo al terminar.';

class PatientLookupPage extends StatefulWidget {
  final VoidCallback? onOpenStaffLogin;

  const PatientLookupPage({this.onOpenStaffLogin, super.key});

  @override
  State<PatientLookupPage> createState() => _PatientLookupPageState();
}

class _PatientLookupPageState extends State<PatientLookupPage> {
  final _formKey = GlobalKey<FormState>();
  final _documentController = TextEditingController();
  final _codeController = TextEditingController();
  PatientPortalProvider? _provider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<PatientPortalProvider>();
    if (!identical(_provider, provider)) {
      _provider?.removeListener(_handleProviderChange);
      _provider = provider..addListener(_handleProviderChange);
      provider.recordActivity();
    }
  }

  @override
  void dispose() {
    _provider?.removeListener(_handleProviderChange);
    _provider?.clear(notify: false);
    _documentController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _handleProviderChange() {
    final provider = _provider;
    if (provider == null || !provider.consumeInactivityExpiration()) return;

    _documentController.clear();
    _codeController.clear();
    _formKey.currentState?.reset();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por su seguridad, la consulta se cerró')),
      );
    });
  }

  void _clearConsultation() {
    _provider?.clear();
    _provider?.recordActivity();
    _documentController.clear();
    _codeController.clear();
    _formKey.currentState?.reset();
  }

  Future<void> _submit() async {
    _provider?.recordActivity();
    if (!_formKey.currentState!.validate()) return;

    final document = _documentController.text;
    final result = await context.read<PatientPortalProvider>().lookup(
      document,
      _codeController.text,
    );
    if (!mounted || result is! PatientRecordFound) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PatientRecordDetailPage(
          record: result.record,
          patientDocument: document,
        ),
      ),
    );
    if (mounted) _clearConsultation();
  }

  Future<void> _openStaffLogin() async {
    _clearConsultation();
    _provider?.recordActivity();
    final onOpenStaffLogin = widget.onOpenStaffLogin;
    if (onOpenStaffLogin != null) {
      onOpenStaffLogin();
      return;
    }
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const LoginPage()));
    if (mounted) _provider?.recordActivity();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PatientPortalProvider>();
    return Listener(
      onPointerDown: (_) => provider.recordActivity(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Consulta de resultados'),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  children: [
                    const AppLogo(),
                    const SizedBox(height: 12),
                    const Text(
                      'RMPZD',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 7,
                                horizontal: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.25,
                                  ),
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.person_search_rounded,
                                    size: 16,
                                    color: AppColors.primary,
                                  ),
                                  SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      'Soy Paciente',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(9),
                              onTap: _openStaffLogin,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                  vertical: 7,
                                  horizontal: 8,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.medical_services_outlined,
                                      size: 16,
                                      color: AppColors.textSecondary,
                                    ),
                                    SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        'Personal de Salud',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Consulte su resultado con su número de ID y el código que '
                      'le entregó su médico',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'La consulta de resultados requiere una conexión activa a internet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              controller: _documentController,
                              textCapitalization: TextCapitalization.characters,
                              autocorrect: false,
                              enableSuggestions: false,
                              inputFormatters: [const _UpperCaseTextFormatter()],
                              decoration: const InputDecoration(
                                labelText: 'Número de documento / ID',
                                prefixIcon: Icon(Icons.badge_outlined),
                              ),
                              validator: (value) =>
                                  value == null || value.trim().isEmpty
                                  ? 'Ingrese su número de documento / ID.'
                                  : null,
                              onChanged: (_) => provider.recordActivity(),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _codeController,
                              textCapitalization: TextCapitalization.characters,
                              autocorrect: false,
                              enableSuggestions: false,
                              inputFormatters: [const _UpperCaseTextFormatter()],
                              decoration: const InputDecoration(
                                labelText: 'Código de consulta',
                                hintText: 'XXXX-XXXX',
                                prefixIcon: Icon(Icons.key_rounded),
                              ),
                              validator: (value) {
                                if (!RegExp(
                                  r'^(?:[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{8}|'
                                  r'[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{4}-'
                                  r'[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{4})$',
                                ).hasMatch((value ?? '').trim().toUpperCase())) {
                                  return 'Ingrese el código de 8 caracteres.';
                                }
                                return null;
                              },
                              onChanged: (_) => provider.recordActivity(),
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: provider.isLoading ? null : _submit,
                              child: provider.isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Consultar'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (provider.result case final result?
                        when result is! PatientRecordFound) ...[
                      const SizedBox(height: 10),
                      _ErrorMessage(_errorMessage(result)),
                    ],
                    const SizedBox(height: 8),
                    const Text(
                      _privacyNote,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _errorMessage(LookupPatientRecordsResult result) => switch (result) {
  PatientRecordsNotFound() || PatientLookupIncomplete() =>
    'No encontramos un registro con esos datos. Verifique su ID y el código '
        'que le entregó su médico.',
  PatientLookupBlocked() =>
    'Demasiados intentos. Intente de nuevo en 15 minutos.',
  PatientLookupNoConnection() => 'Necesita conexión a internet para consultar.',
  PatientLookupError() =>
    'No pudimos completar la consulta. Inténtelo más tarde.',
  PatientRecordFound() => '',
};

class _UpperCaseTextFormatter extends TextInputFormatter {
  const _UpperCaseTextFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => newValue.copyWith(text: newValue.text.toUpperCase());
}

class _ErrorMessage extends StatelessWidget {
  final String message;

  const _ErrorMessage(this.message);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF7ED),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.secondary),
    ),
    child: Text(message, textAlign: TextAlign.center),
  );
}
