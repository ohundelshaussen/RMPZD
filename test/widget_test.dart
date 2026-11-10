import 'package:flutter_test/flutter_test.dart';
import 'package:rmpzd/main.dart';

void main() {
  testWidgets('RMPZD App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const RmpzdApp());
    expect(find.text('Triage Materno Comunitario'), findsOneWidget);
  });
}
