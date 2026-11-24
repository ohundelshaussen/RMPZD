import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('patient portal does not persist records in local storage', () async {
    final portal = Directory('lib/features/patient_portal');
    final dartFiles = portal
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    for (final file in dartFiles) {
      final source = await file.readAsString();
      final imports = RegExp(
        r"""^\s*(?:import|export)\s+['"]([^'"]+)['"]""",
        multiLine: true,
      ).allMatches(source);
      expect(
        imports.any((match) {
          final target = match.group(1)!;
          return target.contains('assessment_local_datasource') ||
              target.contains('database_helper') ||
              target.contains('triage/data');
        }),
        isFalse,
        reason: file.path,
      );
    }
  });
}
