import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/patient_record_view.dart';
import '../../domain/usecases/lookup_patient_records_usecase.dart';

class PatientPortalRemoteDataSource implements PatientRecordsLookup {
  final SupabaseClient? client;

  const PatientPortalRemoteDataSource({required this.client});

  @override
  Future<LookupPatientRecordsResult> lookup({
    required String document,
    required String code,
  }) async {
    final supabase = client;
    if (supabase == null) return const PatientLookupError();

    try {
      final response = await supabase.rpc(
        'consultar_mis_registros',
        params: {
          'p_documento': document.trim(),
          'p_codigo': code.replaceAll('-', '').trim().toUpperCase(),
        },
      );
      if (response is! Map) return const PatientLookupError();

      if (response['ok'] == false) {
        return switch (response['motivo']) {
          'no_encontrado' => const PatientRecordsNotFound(),
          'bloqueado' => const PatientLookupBlocked(),
          'datos_incompletos' => const PatientLookupIncomplete(),
          _ => const PatientLookupError(),
        };
      }
      if (response['ok'] != true || response['registro'] is! Map) {
        return const PatientLookupError();
      }

      final record = PatientRecordView.fromJson(
        Map<String, dynamic>.from(response['registro'] as Map),
      );
      return PatientRecordFound(record);
    } on PostgrestException {
      return const PatientLookupError();
    } on FormatException {
      return const PatientLookupError();
    } catch (error) {
      if (_isNetworkFailure(error)) return const PatientLookupNoConnection();
      return const PatientLookupError();
    }
  }

  bool _isNetworkFailure(Object error) {
    if (error is SocketException ||
        error is TimeoutException ||
        error is HttpException) {
      return true;
    }
    final message = error.toString().toLowerCase();
    return message.contains('socketexception') ||
        message.contains('clientexception') ||
        message.contains('failed host lookup') ||
        message.contains('network is unreachable') ||
        message.contains('connection refused') ||
        message.contains('connection reset') ||
        message.contains('timed out');
  }
}
