import 'package:flutter_test/flutter_test.dart';
import 'package:opamp_simulator/main.dart';

void main() {
  testWidgets('Virtual lab app smoke test renders title', (WidgetTester tester) async {
    await tester.pumpWidget(const OpAmpSimulatorApp());
    await tester.pumpAndSettle();

    expect(find.textContaining('Operational Amplifier'), findsWidgets);
  });
}
