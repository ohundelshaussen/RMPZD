import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('patient portal does not import the facilities feature', () async {
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
        imports.any((match) => match.group(1)!.contains('facilities')),
        isFalse,
        reason: file.path,
      );
    }
  });
}
