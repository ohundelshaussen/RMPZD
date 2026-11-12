import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class AssessmentRemoteDataSource {
  Future<void> upsertBatch(List<Map<String, dynamic>> payload);

  bool isNetworkFailure(Object error);

  bool isClientFailure(Object error);
}

class SupabaseAssessmentRemoteDataSource implements AssessmentRemoteDataSource {
  final SupabaseClient? client;

  const SupabaseAssessmentRemoteDataSource({required this.client});

  @override
  Future<void> upsertBatch(List<Map<String, dynamic>> payload) async {
    final supabase = client;
    if (supabase == null) {
      throw StateError('Supabase no está inicializado.');
    }
    await supabase
        .from('assessments')
        .upsert(payload, onConflict: 'id', ignoreDuplicates: true);
  }

  @override
  bool isNetworkFailure(Object error) {
    if (error is SocketException || error is TimeoutException) return true;
    final message = error.toString().toLowerCase();
    return message.contains('socketexception') ||
        message.contains('failed host lookup') ||
        message.contains('network is unreachable') ||
        message.contains('connection refused') ||
        message.contains('connection reset') ||
        message.contains('timed out') ||
        message.contains('clientexception');
  }

  @override
  bool isClientFailure(Object error) {
    if (error is! PostgrestException) return false;
    final code = error.code ?? '';
    return code.startsWith('22') ||
        code.startsWith('23') ||
        code.startsWith('28') ||
        code.startsWith('42') ||
        code.startsWith('PGRST');
  }
}
