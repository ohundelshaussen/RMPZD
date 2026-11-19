import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmpzd/shared/widgets/app_logo.dart';

void main() {
  for (final screenWidth in [360.0, 800.0]) {
    testWidgets('AppLogo fits within $screenWidth px screens', (tester) async {
      tester.view.physicalSize = Size(screenWidth, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AppLogo())),
      );

      final imageFinder = find.byType(Image);
      final image = tester.widget<Image>(imageFinder);
      expect(image.fit, BoxFit.contain);
      expect(image.filterQuality, FilterQuality.medium);
      expect(image.excludeFromSemantics, isTrue);
      expect(image.width, screenWidth == 360 ? 288 : 340);
      expect(
        find.ancestor(of: imageFinder, matching: find.byType(ClipOval)),
        findsNothing,
      );
      expect(
        find.ancestor(
          of: imageFinder,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.label ==
                    'Logo Materno Perinatal, Zonas Dispersas',
          ),
        ),
        findsOneWidget,
      );
    });
  }
}
