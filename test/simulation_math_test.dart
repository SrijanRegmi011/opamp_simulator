import 'package:flutter_test/flutter_test.dart';
import 'package:opamp_simulator/main.dart';

void main() {
  group('OpAmpController Logic and Mathematics', () {
    test('Default inverting gain and parameters', () {
      final ctrl = OpAmpController();
      expect(ctrl.mode, OpAmpMode.inverting);
      expect(ctrl.r1, 2000.0);
      expect(ctrl.rf, 20000.0);
      expect(ctrl.vin, 1.0);
      expect(ctrl.theoreticalGain, -10.0);
      expect(ctrl.expectedOutputVoltage, -10.0);
    });

    test('Non-inverting gain calculation', () {
      final ctrl = OpAmpController();
      ctrl.setMode(OpAmpMode.nonInverting);
      ctrl.setR1(5000.0);
      ctrl.setRf(20000.0);
      ctrl.setVin(2.0);
      // Av = 1 + (20/5) = 5
      expect(ctrl.theoreticalGain, 5.0);
      expect(ctrl.expectedOutputVoltage, 10.0);
    });

    test('Saturation voltage clamping at ±13.5V', () {
      final ctrl = OpAmpController();
      ctrl.autoWireCircuit();
      expect(ctrl.isCircuitConnected, true);

      // High Vin causing saturation
      ctrl.setVin(2.5); // Theoretical Vo = -25V
      expect(ctrl.theoreticalGain, -10.0);
      expect(ctrl.expectedOutputVoltage, -25.0);
      expect(ctrl.outputVoltage, -13.5);
      expect(ctrl.isSaturated, true);

      // Negative Vin causing positive saturation
      ctrl.setVin(-2.5); // Theoretical Vo = +25V
      expect(ctrl.outputVoltage, 13.5);
      expect(ctrl.isSaturated, true);
    });

    test('Auto-wire satisfies all expected connections', () {
      final ctrl = OpAmpController();
      expect(ctrl.wires.isEmpty, true);
      expect(ctrl.isCircuitConnected, false);

      ctrl.autoWireCircuit();
      final report = ctrl.verifyCircuit();
      expect(report.isComplete, true);
      expect(report.missingConnections.isEmpty, true);
      expect(ctrl.isCircuitConnected, true);
    });

    test('Observation table logging and CSV generation', () {
      final ctrl = OpAmpController();
      ctrl.autoWireCircuit();
      ctrl.setVin(1.0);
      ctrl.addReadingToTable();

      expect(ctrl.readings.length, 1);
      final r = ctrl.readings.first;
      expect(r.serialNo, 1);
      expect(r.vin, 1.0);
      expect(r.expectedVout, -10.0);
      expect(r.measuredVout, -10.0);

      final csv = ctrl.generateCsv();
      expect(csv.contains('Vin (V)'), true);
      expect(csv.contains('-10.00'), true);
    });
  });
}
