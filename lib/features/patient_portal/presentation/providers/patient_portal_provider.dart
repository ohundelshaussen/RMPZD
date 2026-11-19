import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/usecases/lookup_patient_records_usecase.dart';

class PatientPortalProvider extends ChangeNotifier {
  static const inactivityLimit = Duration(minutes: 3);

  final LookupPatientRecordsUseCase lookupPatientRecords;

  PatientPortalProvider({required this.lookupPatientRecords});

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  LookupPatientRecordsResult? _result;
  LookupPatientRecordsResult? get result => _result;

  bool _inactivityExpired = false;
  bool get inactivityExpired => _inactivityExpired;

  int _requestId = 0;
  Timer? _inactivityTimer;

  Future<LookupPatientRecordsResult?> lookup(
    String document,
    String code,
  ) async {
    recordActivity();
    final requestId = ++_requestId;
    _isLoading = true;
    _result = null;
    notifyListeners();
    try {
      final result = await lookupPatientRecords.execute(
        document: document.trim(),
        code: code.replaceAll('-', '').trim().toUpperCase(),
      );
      if (requestId == _requestId) _result = result;
      return requestId == _requestId ? result : null;
    } finally {
      if (requestId == _requestId) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void recordActivity() {
    _inactivityTimer?.cancel();
    _inactivityExpired = false;
    _inactivityTimer = Timer(inactivityLimit, _expireForInactivity);
  }

  bool consumeInactivityExpiration() {
    if (!_inactivityExpired) return false;
    _inactivityExpired = false;
    return true;
  }

  void _expireForInactivity() {
    _inactivityTimer = null;
    _requestId++;
    _isLoading = false;
    _result = null;
    _inactivityExpired = true;
    notifyListeners();
  }

  void clear({bool notify = true}) {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    _requestId++;
    _isLoading = false;
    _result = null;
    _inactivityExpired = false;
    if (notify) notifyListeners();
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    super.dispose();
  }
}
