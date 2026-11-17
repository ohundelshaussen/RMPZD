import 'dart:math';

class ConsultationCodeGenerator {
  static const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final Random _random;

  ConsultationCodeGenerator({Random? random})
    : _random = random ?? Random.secure();

  String generate() => List.generate(
    8,
    (_) => alphabet[_random.nextInt(alphabet.length)],
  ).join();

  static String format(String code) =>
      code.length == 8 ? '${code.substring(0, 4)}-${code.substring(4)}' : code;
}
