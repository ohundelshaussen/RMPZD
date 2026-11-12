import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmpzd/core/utils/validators.dart';

void main() {
  group('requiredInt', () {
    final validator = requiredInt(10, 60);

    test('accepts a valid integer and exact range limits', () {
      expect(validator('35'), isNull);
      expect(validator('10'), isNull);
      expect(validator('60'), isNull);
    });

    test('rejects values outside the range', () {
      expect(validator('9'), 'Ingrese un valor entre 10 y 60');
      expect(validator('61'), 'Ingrese un valor entre 10 y 60');
    });

    test('rejects non-integer text and empty input', () {
      expect(validator('abc'), 'Ingrese un número entero válido');
      expect(validator(''), 'Requerido');
      expect(validator('  '), 'Requerido');
    });
  });

  group('requiredDouble', () {
    final validator = requiredDouble(0, 72);

    test('accepts decimal values with comma or point and exact limits', () {
      expect(validator('12.5'), isNull);
      expect(validator('12,5'), isNull);
      expect(validator('0'), isNull);
      expect(validator('72'), isNull);
    });

    test('rejects values outside the range', () {
      expect(validator('-0,1'), 'Ingrese un valor entre 0 y 72');
      expect(validator('72.1'), 'Ingrese un valor entre 0 y 72');
    });

    test('rejects non-numeric text and empty input', () {
      expect(validator('abc'), 'Ingrese un número válido');
      expect(validator(''), 'Requerido');
      expect(validator('  '), 'Requerido');
    });
  });

  test('validates diastolic pressure is lower than systolic pressure', () {
    final systolicController = TextEditingController(text: '120');
    final validator = combineValidators([
      requiredDouble(30, 160),
      lessThanController(
        systolicController,
        message: 'La presión diastólica debe ser menor que la sistólica',
      ),
    ]);

    expect(validator('80'), isNull);
    expect(
      validator('120'),
      'La presión diastólica debe ser menor que la sistólica',
    );
    expect(
      validator('130'),
      'La presión diastólica debe ser menor que la sistólica',
    );
    expect(validator('20'), 'Ingrese un valor entre 30 y 160');

    systolicController.dispose();
  });
}
