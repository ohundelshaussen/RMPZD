import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rmpzd/features/monitoring/data/datasources/case_remote_data_source.dart';

void main() {
  group('SupabaseCaseRemoteDataSource actions', () {
    late _FakeCaseRpcClient rpc;
    late SupabaseCaseRemoteDataSource source;

    setUp(() {
      rpc = _FakeCaseRpcClient();
      source = SupabaseCaseRemoteDataSource(client: null, rpcClient: rpc);
    });

    test(
      'calls the matching RPC with exact arguments for each action',
      () async {
        await source.takeCase('case-1');
        await source.releaseCase('case-2');
        await source.registerEvent(
          caseId: 'case-3',
          type: 'remision',
          note: 'Enviar a valoración',
          centerId: 'center-4',
        );
        await source.closeCase(
          caseId: 'case-5',
          result: 'atendida',
          note: 'Atención completada',
        );

        expect(rpc.calls.map((call) => call.function), [
          'tomar_caso',
          'liberar_caso',
          'registrar_evento_caso',
          'cerrar_caso',
        ]);
        expect(rpc.calls[0].params, {'p_caso_id': 'case-1'});
        expect(rpc.calls[1].params, {'p_caso_id': 'case-2'});
        expect(rpc.calls[2].params, {
          'p_caso_id': 'case-3',
          'p_tipo': 'remision',
          'p_nota': 'Enviar a valoración',
          'p_centro_id': 'center-4',
        });
        expect(rpc.calls[3].params, {
          'p_caso_id': 'case-5',
          'p_resultado': 'atendida',
          'p_nota': 'Atención completada',
        });
      },
    );

    test('maps all known RPC motives to Spanish messages', () async {
      const expectedMessages = {
        'ya_tomado': 'Otro monitor ya tomó este caso',
        'estado_invalido': 'El caso cambió de estado; actualice la lista',
        'no_autorizado': 'No tiene permiso para esta acción',
        'no_encontrado': 'No se encontró el caso; actualice la lista',
        'nota_larga': 'La nota supera 1000 caracteres',
        'nota_vacia': 'La nota no puede estar vacía',
        'tipo_invalido': 'El tipo de evento no es válido',
        'centro_requerido': 'Seleccione un centro para registrar la remisión',
        'resultado_invalido': 'El resultado del cierre no es válido',
      };

      for (final entry in expectedMessages.entries) {
        rpc.response = {'ok': false, 'motivo': entry.key};
        await expectLater(
          source.takeCase('case-1'),
          throwsA(
            isA<MonitoringActionException>()
                .having((error) => error.motivo, 'motivo', entry.key)
                .having((error) => error.message, 'message', entry.value),
          ),
        );
      }
    });

    test(
      'rejects malformed RPC responses instead of treating them as success',
      () {
        rpc.response = {'motivo': 'ya_tomado'};

        expect(source.takeCase('case-1'), throwsA(isA<StateError>()));
      },
    );
  });

  test('lib contains no direct writes to casos_monitoreo', () {
    final lib = Directory('lib');
    final tableAlias = RegExp(
      r"""static\s+const\s+_table\s*=\s*['"]casos_monitoreo['"]""",
    );
    final tableQuery = RegExp(
      r"""\.from\(\s*(?:['"]casos_monitoreo['"]|_table)\s*\)""",
    );
    final mutation = RegExp(r"\.(?:insert|update|upsert|delete)\s*\(");
    final violations = <String>[];

    for (final entity in lib.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final contents = entity.readAsStringSync();
      if (!tableAlias.hasMatch(contents) &&
          !RegExp(
            r"""\.from\(\s*['"]casos_monitoreo['"]\s*\)""",
          ).hasMatch(contents)) {
        continue;
      }
      for (final query in tableQuery.allMatches(contents)) {
        final terminator = contents.indexOf(';', query.end);
        final statement = contents.substring(
          query.end,
          terminator == -1 ? contents.length : terminator,
        );
        if (mutation.hasMatch(statement)) {
          violations.add(entity.path);
        }
      }
    }

    expect(violations, isEmpty, reason: 'Direct writes found in: $violations');
  });
}

class _FakeCaseRpcClient implements CaseRpcClient {
  final List<({String function, Map<String, dynamic> params})> calls = [];
  Object? response = {'ok': true};

  @override
  Future<Object?> call(
    String function, {
    required Map<String, dynamic> params,
  }) async {
    calls.add((function: function, params: Map<String, dynamic>.of(params)));
    return response;
  }
}
