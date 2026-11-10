import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opamp_simulator/main.dart';

void main() {
  testWidgets('Virtual lab app smoke test renders title', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const OpAmpSimulatorApp());
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('Operational Amplifier'), findsWidgets);
  });
}
