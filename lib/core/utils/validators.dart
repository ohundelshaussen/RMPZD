import 'package:flutter/widgets.dart';

FormFieldValidator<String> requiredInt(int min, int max) {
  return (value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Requerido';

    final number = int.tryParse(text);
    if (number == null) return 'Ingrese un número entero válido';
    if (number < min || number > max) {
      return 'Ingrese un valor entre $min y $max';
    }
    return null;
  };
}

FormFieldValidator<String> requiredDouble(num min, num max) {
  return (value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Requerido';

    final number = double.tryParse(text.replaceAll(',', '.'));
    if (number == null || !number.isFinite) {
      return 'Ingrese un número válido';
    }
    if (number < min || number > max) {
      return 'Ingrese un valor entre ${_formatLimit(min)} y ${_formatLimit(max)}';
    }
    return null;
  };
}

FormFieldValidator<String> lessThanController(
  TextEditingController otherController, {
  required String message,
}) {
  return (value) {
    final number = _parseDouble(value);
    final otherNumber = _parseDouble(otherController.text);
    if (number == null || otherNumber == null) return null;
    return number < otherNumber ? null : message;
  };
}

FormFieldValidator<String> combineValidators(
  List<FormFieldValidator<String>> validators,
) {
  return (value) {
    for (final validator in validators) {
      final error = validator(value);
      if (error != null) return error;
    }
    return null;
  };
}

double? _parseDouble(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return null;
  final number = double.tryParse(text.replaceAll(',', '.'));
  return number != null && number.isFinite ? number : null;
}

String _formatLimit(num value) {
  return value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();
}
