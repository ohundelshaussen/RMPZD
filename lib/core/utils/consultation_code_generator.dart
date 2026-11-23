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

  static String normalize(String code) =>
      code.replaceAll(RegExp(r'[-\s]'), '').trim().toUpperCase();

  static String format(String code) {
    final normalized = normalize(code);
    return normalized.length == 8
        ? '${normalized.substring(0, 4)}-${normalized.substring(4)}'
        : code.trim();
  }
}
