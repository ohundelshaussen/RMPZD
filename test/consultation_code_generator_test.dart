import 'package:flutter_test/flutter_test.dart';
import 'package:rmpzd/core/utils/consultation_code_generator.dart';

void main() {
  test('generates unique eight-character consultation codes', () {
    final generator = ConsultationCodeGenerator();
    final codes = List.generate(1000, (_) => generator.generate());
    final allowed = RegExp(r'^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{8}$');

    expect(codes, everyElement(hasLength(8)));
    expect(codes, everyElement(matches(allowed)));
    expect(codes.toSet(), hasLength(1000));
    expect(
      ConsultationCodeGenerator.format(codes.first),
      '${codes.first.substring(0, 4)}-${codes.first.substring(4)}',
    );
    expect(ConsultationCodeGenerator.normalize('abcd-2345'), 'ABCD2345');
    expect(ConsultationCodeGenerator.format('abcd-2345'), 'ABCD-2345');
    expect(ConsultationCodeGenerator.format('SHORT'), 'SHORT');
  });
}
