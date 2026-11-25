class PhoneNumber {
  static String digitsForAssessment(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    return value.trim().startsWith('+57') && digits.startsWith('57')
        ? digits.substring(2)
        : digits;
  }

  static bool isValidAssessmentNumber(String value) {
    final length = digitsForAssessment(value).length;
    return length >= 7 && length <= 15;
  }

  static String toDialString(String value) =>
      value.replaceAll(RegExp(r'[\s().-]'), '');
}
