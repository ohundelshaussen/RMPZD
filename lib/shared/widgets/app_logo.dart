import 'dart:math' as math;

import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({this.maxWidth = 340, super.key}) : assert(maxWidth > 0);

  final double maxWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final screenWidth = MediaQuery.sizeOf(context).width;
      final availableWidth = constraints.hasBoundedWidth
          ? constraints.maxWidth
          : screenWidth;
      final logoWidth = math.min(
        math.min(screenWidth * 0.8, maxWidth),
        availableWidth,
      );

      return Semantics(
        label: 'Logo Materno Perinatal, Zonas Dispersas',
        image: true,
        child: Center(
          child: Image.asset(
            'assets/images/logo_completo.png',
            width: logoWidth,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
            excludeFromSemantics: true,
            errorBuilder: (context, error, stackTrace) => const Text('RMPZD'),
          ),
        ),
      );
    },
  );
}
