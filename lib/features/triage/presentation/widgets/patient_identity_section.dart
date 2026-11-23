import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import 'form_section_header.dart';

class PatientIdentityData {
  final bool consentimientoDatos;
  final String? nombrePaciente;
  final String? direccionPaciente;
  final double? latitud;
  final double? longitud;
  final double? precisionGpsM;
  final DateTime? ubicacionCapturadaAt;

  const PatientIdentityData({
    this.consentimientoDatos = false,
    this.nombrePaciente,
    this.direccionPaciente,
    this.latitud,
    this.longitud,
    this.precisionGpsM,
    this.ubicacionCapturadaAt,
  });
}

class CapturedLocation {
  final double latitude;
  final double longitude;
  final double accuracyMeters;

  const CapturedLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
  });
}

enum LocationCaptureFailure {
  unsupported,
  permissionDenied,
  permissionDeniedForever,
  serviceDisabled,
  unavailable,
}

class LocationCaptureException implements Exception {
  final LocationCaptureFailure reason;

  const LocationCaptureException(this.reason);
}

abstract interface class LocationCaptureService {
  Future<CapturedLocation> captureCurrentLocation();
  Future<bool> openAppSettings();
  Future<bool> openLocationSettings();
}

class GeolocatorLocationCaptureService implements LocationCaptureService {
  const GeolocatorLocationCaptureService();

  @override
  Future<CapturedLocation> captureCurrentLocation() async {
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) {
      throw const LocationCaptureException(LocationCaptureFailure.unsupported);
    }

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const LocationCaptureException(
          LocationCaptureFailure.serviceDisabled,
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        throw const LocationCaptureException(
          LocationCaptureFailure.permissionDeniedForever,
        );
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.unableToDetermine) {
        throw const LocationCaptureException(
          LocationCaptureFailure.permissionDenied,
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      return CapturedLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
      );
    } on LocationCaptureException {
      rethrow;
    } on LocationServiceDisabledException {
      throw const LocationCaptureException(
        LocationCaptureFailure.serviceDisabled,
      );
    } on PermissionDeniedException {
      throw const LocationCaptureException(
        LocationCaptureFailure.permissionDenied,
      );
    } on TimeoutException {
      rethrow;
    } on PlatformException {
      throw const LocationCaptureException(LocationCaptureFailure.unavailable);
    } on MissingPluginException {
      throw const LocationCaptureException(LocationCaptureFailure.unsupported);
    } on UnsupportedError {
      throw const LocationCaptureException(LocationCaptureFailure.unsupported);
    }
  }

  @override
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  @override
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
}

enum _CaptureStatus { idle, capturing, captured, error }

class PatientIdentitySection extends StatefulWidget {
  final ValueChanged<PatientIdentityData> onChanged;
  final LocationCaptureService? locationService;

  const PatientIdentitySection({
    required this.onChanged,
    this.locationService,
    super.key,
  });

  @override
  State<PatientIdentitySection> createState() => _PatientIdentitySectionState();
}

class _PatientIdentitySectionState extends State<PatientIdentitySection> {
  static const _captureTimeout = Duration(seconds: 20);
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  bool _consent = false;
  _CaptureStatus _captureStatus = _CaptureStatus.idle;
  CapturedLocation? _location;
  DateTime? _locationCapturedAt;
  String? _locationMessage;
  LocationCaptureFailure? _locationFailure;

  LocationCaptureService get _locationService =>
      widget.locationService ?? const GeolocatorLocationCaptureService();

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _emitData() {
    if (!_consent) {
      widget.onChanged(const PatientIdentityData());
      return;
    }
    widget.onChanged(
      PatientIdentityData(
        consentimientoDatos: true,
        nombrePaciente: _nameController.text.trim(),
        direccionPaciente: _addressController.text.trim(),
        latitud: _location?.latitude,
        longitud: _location?.longitude,
        precisionGpsM: _location?.accuracyMeters,
        ubicacionCapturadaAt: _locationCapturedAt,
      ),
    );
  }

  Future<void> _changeConsent(bool? checked) async {
    if (checked == null) return;
    if (!checked) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Retirar consentimiento'),
          content: const Text(
            'Se borrarán el nombre, la dirección y la ubicación del formulario.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Borrar datos'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      _nameController.clear();
      _addressController.clear();
      _location = null;
      _locationCapturedAt = null;
      _locationMessage = null;
      _locationFailure = null;
      setState(() {
        _consent = false;
        _captureStatus = _CaptureStatus.idle;
      });
      _emitData();
      return;
    }
    setState(() => _consent = true);
    _emitData();
  }

  Future<void> _captureLocation() async {
    setState(() {
      _captureStatus = _CaptureStatus.capturing;
      _locationMessage = null;
      _locationFailure = null;
    });

    try {
      final location = await _locationService.captureCurrentLocation().timeout(
        _captureTimeout,
      );
      if (location.latitude < -90 ||
          location.latitude > 90 ||
          location.longitude < -180 ||
          location.longitude > 180 ||
          !location.latitude.isFinite ||
          !location.longitude.isFinite ||
          !location.accuracyMeters.isFinite) {
        throw const LocationCaptureException(
          LocationCaptureFailure.unavailable,
        );
      }
      if (!mounted) return;
      setState(() {
        _location = location;
        _locationCapturedAt = DateTime.now().toUtc();
        _captureStatus = _CaptureStatus.captured;
      });
      _emitData();
    } on TimeoutException {
      _showLocationError('Tiempo agotado. Intente capturar de nuevo.');
    } on LocationCaptureException catch (error) {
      final (message, failure) = switch (error.reason) {
        LocationCaptureFailure.unsupported => (
          'La ubicación no está disponible en este dispositivo.',
          null,
        ),
        LocationCaptureFailure.permissionDenied => (
          'Permiso de ubicación denegado. Puede volver a intentarlo.',
          error.reason,
        ),
        LocationCaptureFailure.permissionDeniedForever => (
          'Permiso denegado permanentemente. Abra los ajustes para permitirlo.',
          error.reason,
        ),
        LocationCaptureFailure.serviceDisabled => (
          'El GPS está apagado. Active los servicios de ubicación.',
          error.reason,
        ),
        LocationCaptureFailure.unavailable => (
          'No fue posible obtener la ubicación. Intente de nuevo.',
          error.reason,
        ),
      };
      _showLocationError(message, failure: failure);
    }
  }

  void _showLocationError(String message, {LocationCaptureFailure? failure}) {
    if (!mounted) return;
    setState(() {
      _captureStatus = _CaptureStatus.error;
      _locationMessage = message;
      _locationFailure = failure;
      _location = null;
      _locationCapturedAt = null;
    });
    _emitData();
  }

  Future<void> _openSettings() async {
    try {
      final opened = switch (_locationFailure) {
        LocationCaptureFailure.permissionDeniedForever =>
          await _locationService.openAppSettings(),
        LocationCaptureFailure.serviceDisabled =>
          await _locationService.openLocationSettings(),
        _ => false,
      };
      if (!opened && mounted) {
        setState(() => _locationMessage = 'No se pudieron abrir los ajustes.');
      }
    } on PlatformException {
      if (mounted) {
        setState(() => _locationMessage = 'No se pudieron abrir los ajustes.');
      }
    } on MissingPluginException {
      if (mounted) {
        setState(
          () => _locationMessage = 'Los ajustes no están disponibles aquí.',
        );
      }
    } on UnsupportedError {
      if (mounted) {
        setState(
          () => _locationMessage = 'Los ajustes no están disponibles aquí.',
        );
      }
    }
  }

  String? _validateName(String? value) {
    if (!_consent) return null;
    final name = value?.trim() ?? '';
    if (name.length < 2) return 'Ingrese al menos 2 caracteres.';
    if (name.length > 200) return 'Máximo 200 caracteres.';
    if (!RegExp(r'[A-Za-zÀ-ÖØ-öø-ÿ]').hasMatch(name)) {
      return 'Ingrese un nombre válido, no solo números.';
    }
    return null;
  }

  String? _validateAddress(String? value) {
    if (!_consent) return null;
    final address = value?.trim() ?? '';
    if (address.isEmpty) return 'La dirección es obligatoria.';
    if (address.length > 300) return 'Máximo 300 caracteres.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final disabledColor = Theme.of(context).disabledColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FormSectionHeader('Identificación y ubicación'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _consent,
                  onChanged: _changeConsent,
                  title: const Text(
                    'La paciente autoriza el registro de su nombre, dirección y ubicación para su atención y seguimiento.',
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  enabled: _consent,
                  maxLength: 200,
                  validator: _validateName,
                  onChanged: (_) => _emitData(),
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nombre completo de la paciente',
                    prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressController,
                  enabled: _consent,
                  maxLength: 300,
                  maxLines: 2,
                  validator: _validateAddress,
                  onChanged: (_) => _emitData(),
                  decoration: const InputDecoration(
                    labelText:
                        'Dirección o descripción de la vivienda (vereda, corregimiento, barrio, referencias)',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.home_outlined, size: 20),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed:
                      !_consent || _captureStatus == _CaptureStatus.capturing
                      ? null
                      : _captureLocation,
                  icon: _captureStatus == _CaptureStatus.capturing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location_rounded),
                  label: Text(
                    _captureStatus == _CaptureStatus.capturing
                        ? 'Capturando ubicación...'
                        : _captureStatus == _CaptureStatus.captured
                        ? 'Capturar de nuevo'
                        : 'Capturar ubicación actual',
                  ),
                ),
                if (_captureStatus == _CaptureStatus.captured &&
                    _location != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Latitud: ${_location!.latitude.toStringAsFixed(5)} · '
                    'Longitud: ${_location!.longitude.toStringAsFixed(5)}',
                  ),
                  Text(
                    'Precisión: ${_location!.accuracyMeters.toStringAsFixed(1)} m',
                  ),
                  if (_location!.accuracyMeters > 100)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        'Precisión baja, intente al aire libre',
                        style: TextStyle(color: Colors.deepOrange),
                      ),
                    ),
                ] else if (_captureStatus == _CaptureStatus.error &&
                    _locationMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _locationMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  if (_locationFailure ==
                          LocationCaptureFailure.permissionDeniedForever ||
                      _locationFailure ==
                          LocationCaptureFailure.serviceDisabled)
                    TextButton(
                      onPressed: _openSettings,
                      child: Text(
                        _locationFailure ==
                                LocationCaptureFailure.permissionDeniedForever
                            ? 'Abrir ajustes de la aplicación'
                            : 'Abrir ajustes de ubicación',
                      ),
                    ),
                ] else if (!_consent) ...[
                  Text(
                    'Opcional: puede guardar la evaluación sin ubicación.',
                    style: TextStyle(color: disabledColor),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
