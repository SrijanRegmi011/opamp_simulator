import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:opamp_simulator/services/api_service.dart';

void main() {
  runApp(const OpAmpSimulatorApp());
}

// =============================================================================
// SECTION 1: ROOT APPLICATION & THEME SYSTEM (DAY & NIGHT MODES)
// =============================================================================

class OpAmpSimulatorApp extends StatefulWidget {
  const OpAmpSimulatorApp({super.key});

  @override
  State<OpAmpSimulatorApp> createState() => _OpAmpSimulatorAppState();
}

class _OpAmpSimulatorAppState extends State<OpAmpSimulatorApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Virtual Labs: Operational Amplifier',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Segoe UI',
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF4F6F9),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFFD9531E), // Terracotta Orange
          secondary: Color(0xFF1E40AF), // Deep Blue
          surface: Colors.white,
          surfaceContainerHighest: Color(0xFFEEF2F6),
          onSurface: Color(0xFF1E293B),
        ),
        dividerColor: const Color(0xFFE2E8F0),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Segoe UI',
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B1120),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFF97316),
          secondary: Color(0xFF38BDF8),
          surface: Color(0xFF1E293B),
          surfaceContainerHighest: Color(0xFF334155),
          onSurface: Color(0xFFF8FAFC),
        ),
        dividerColor: const Color(0xFF334155),
      ),
      home: LabPortalShell(
        themeMode: _themeMode,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}

// =============================================================================
// SECTION 2: DATA MODELS & RANDOMIZED QUIZ GENERATOR
// =============================================================================

enum OpAmpMode {
  inverting('Inverting Amplifier', 'Av = - (Rf / R1)'),
  nonInverting('Non-Inverting Amplifier', 'Av = 1 + (Rf / R1)');

  final String label;
  final String formula;
  const OpAmpMode(this.label, this.formula);
}

enum ComponentType {
  ic741('IC 741 Op-Amp'),
  resistorR1('Input Resistor R1'),
  resistorRf('Feedback Resistor Rf'),
  voltageSource('DC Source Vin'),
  powerSupply('DC Dual Supply (±15V)'),
  ground('Earth Ground (GND)'),
  voltmeter('Digital Voltmeter (Vo)');

  final String displayName;
  const ComponentType(this.displayName);
}

class TerminalPin {
  final int id;
  final String label;
  final Offset localOffset;
  final Color baseColor;

  const TerminalPin({
    required this.id,
    required this.label,
    required this.localOffset,
    this.baseColor = const Color(0xFFB45309),
  });
}

class DraggableComponent {
  final String id;
  final ComponentType type;
  final String label;
  Offset position;
  final Size size;
  final List<TerminalPin> terminals;

  DraggableComponent({
    required this.id,
    required this.type,
    required this.label,
    required this.position,
    required this.size,
    required this.terminals,
  });

  DraggableComponent copyWith({Offset? position}) {
    return DraggableComponent(
      id: id,
      type: type,
      label: label,
      position: position ?? this.position,
      size: size,
      terminals: terminals,
    );
  }
}

class CircuitWire {
  final int id;
  final int fromPin;
  final int toPin;
  final Color color;

  const CircuitWire({
    required this.id,
    required this.fromPin,
    required this.toPin,
    required this.color,
  });

  bool connects(int pinA, int pinB) {
    return (fromPin == pinA && toPin == pinB) || (fromPin == pinB && toPin == pinA);
  }
}

class ExpectedConnection {
  final int step;
  final int pinA;
  final int pinB;
  final String nameA;
  final String nameB;
  final String purpose;

  const ExpectedConnection({
    required this.step,
    required this.pinA,
    required this.pinB,
    required this.nameA,
    required this.nameB,
    required this.purpose,
  });
}

class CircuitVerificationReport {
  final bool isComplete;
  final List<ExpectedConnection> missingConnections;

  const CircuitVerificationReport({
    required this.isComplete,
    required this.missingConnections,
  });
}

class LabReading {
  final int serialNo;
  final double vin;
  final double r1;
  final double rf;
  final double expectedVout;
  final double measuredVout;
  final double errorPercent;
  final bool isSaturated;

  const LabReading({
    required this.serialNo,
    required this.vin,
    required this.r1,
    required this.rf,
    required this.expectedVout,
    required this.measuredVout,
    required this.errorPercent,
    required this.isSaturated,
  });
}

class QuizQuestion {
  final int id;
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  const QuizQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });
}

// -----------------------------------------------------------------------------
// DYNAMIC & PARAMETRIC QUIZ GENERATOR
// -----------------------------------------------------------------------------

class DynamicQuizGenerator {
  static final math.Random _rng = math.Random();

  static List<QuizQuestion> generateFreshPretest() {
    final list = <QuizQuestion>[];
    int qId = 1;

    // Pick 8 random questions from conceptual pool
    final conceptual = List<QuizQuestion>.from(_staticPretestPool)..shuffle(_rng);
    list.addAll(conceptual.take(7).map((q) => QuizQuestion(
      id: qId++,
      question: q.question,
      options: q.options,
      correctIndex: q.correctIndex,
      explanation: q.explanation,
    )));

    // Generate 3 parametric calculation questions with dynamic numbers
    list.add(_generateInvertingGainCalculationQuestion(qId++));
    list.add(_generateNonInvertingGainCalculationQuestion(qId++));
    list.add(_generateSaturationCheckQuestion(qId++));

    return list;
  }

  static List<QuizQuestion> generateFreshPosttest() {
    final list = <QuizQuestion>[];
    int qId = 1;

    final conceptual = List<QuizQuestion>.from(_staticPosttestPool)..shuffle(_rng);
    list.addAll(conceptual.take(7).map((q) => QuizQuestion(
      id: qId++,
      question: q.question,
      options: q.options,
      correctIndex: q.correctIndex,
      explanation: q.explanation,
    )));

    list.add(_generateInvertingGainCalculationQuestion(qId++));
    list.add(_generateSlewRateCalculationQuestion(qId++));
    list.add(_generateBandwidthCalculationQuestion(qId++));

    return list;
  }

  static QuizQuestion _generateInvertingGainCalculationQuestion(int id) {
    final r1Vals = [1.0, 2.0, 5.0, 10.0];
    final rfVals = [10.0, 20.0, 30.0, 50.0];
    final r1 = r1Vals[_rng.nextInt(r1Vals.length)];
    final rf = rfVals[_rng.nextInt(rfVals.length)];
    final vin = (_rng.nextInt(6) + 1) * 0.5; // 0.5 to 3.0 V

    final gain = -(rf / r1);
    final vout = gain * vin;

    final correctStr = '${vout.toStringAsFixed(1)} V';
    final options = <String>[
      correctStr,
      '${(-vout).toStringAsFixed(1)} V',
      '${(vout * 1.5).toStringAsFixed(1)} V',
      '${(vout * 0.5).toStringAsFixed(1)} V',
    ]..shuffle(_rng);

    return QuizQuestion(
      id: id,
      question: 'Calculate the output voltage (Vout) for an Inverting Amplifier with R1 = ${r1.toInt()} kΩ, Rf = ${rf.toInt()} kΩ, and Vin = ${vin.toStringAsFixed(1)} V.',
      options: options,
      correctIndex: options.indexOf(correctStr),
      explanation: 'Av = - (Rf / R1) = - (${rf.toInt()} / ${r1.toInt()}) = ${gain.toStringAsFixed(1)}. Therefore Vout = Av · Vin = ${gain.toStringAsFixed(1)} × ${vin.toStringAsFixed(1)} V = $correctStr.',
    );
  }

  static QuizQuestion _generateNonInvertingGainCalculationQuestion(int id) {
    final r1Vals = [2.0, 5.0, 10.0];
    final rfVals = [10.0, 20.0, 40.0];
    final r1 = r1Vals[_rng.nextInt(r1Vals.length)];
    final rf = rfVals[_rng.nextInt(rfVals.length)];
    final vin = (_rng.nextInt(4) + 1) * 0.5;

    final gain = 1.0 + (rf / r1);
    final vout = gain * vin;
    final correctStr = '${vout.toStringAsFixed(1)} V';
    final options = <String>[
      correctStr,
      '${(-vout).toStringAsFixed(1)} V',
      '${((gain - 1) * vin).toStringAsFixed(1)} V',
      '${(vout * 2).toStringAsFixed(1)} V',
    ]..shuffle(_rng);

    return QuizQuestion(
      id: id,
      question: 'In a Non-Inverting Op-Amp circuit, R1 = ${r1.toInt()} kΩ and Rf = ${rf.toInt()} kΩ. What is the output voltage when Vin = ${vin.toStringAsFixed(1)} V?',
      options: options,
      correctIndex: options.indexOf(correctStr),
      explanation: 'Av = 1 + (Rf / R1) = 1 + (${rf.toInt()}/${r1.toInt()}) = ${gain.toStringAsFixed(1)}. Vout = Av · Vin = ${gain.toStringAsFixed(1)} × ${vin.toStringAsFixed(1)} V = $correctStr.',
    );
  }

  static QuizQuestion _generateSaturationCheckQuestion(int id) {
    const vin = 2.5;
    const r1 = 1.0;
    const rf = 10.0;
    const vSat = 13.5;

    const correctStr = '-$vSat V (clamped at negative saturation)';
    final options = <String>[
      correctStr,
      '-25.0 V',
      '+$vSat V',
      '0.0 V',
    ]..shuffle(_rng);

    return QuizQuestion(
      id: id,
      question: 'An inverting amplifier has Av = -${(rf / r1).toInt()} and power supply rails ±15V (Vsat = ±${vSat}V). What is the actual output voltage when Vin = +$vin V?',
      options: options,
      correctIndex: options.indexOf(correctStr),
      explanation: 'Theoretical Vout = -10 × $vin V = -25.0 V. Because |-25V| exceeds Vsat (${vSat}V), the op-amp output clamps flat at the negative power rail limit of -$vSat V.',
    );
  }

  static QuizQuestion _generateSlewRateCalculationQuestion(int id) {
    const correctStr = '7.96 kHz';
    final options = <String>[
      correctStr,
      '15.9 kHz',
      '50.0 kHz',
      '1.0 MHz',
    ]..shuffle(_rng);

    return QuizQuestion(
      id: id,
      question: 'For an op-amp with slew rate SR = 0.5 V/μs, what is the maximum full-power undistorted sine wave frequency (fmax) for peak output amplitude Vp = 10 V?',
      options: options,
      correctIndex: options.indexOf(correctStr),
      explanation: 'fmax = SR / (2π · Vp) = (0.5 × 10⁶ V/s) / (2π × 10 V) ≈ 7,958 Hz ≈ 7.96 kHz.',
    );
  }

  static QuizQuestion _generateBandwidthCalculationQuestion(int id) {
    const correctStr = '100 kHz';
    final options = <String>[
      correctStr,
      '10 kHz',
      '500 kHz',
      '1 MHz',
    ]..shuffle(_rng);

    return QuizQuestion(
      id: id,
      question: 'If an op-amp has a unity Gain-Bandwidth Product (GBWP) of 1 MHz, what is its closed-loop bandwidth when configured for a voltage gain of Av = 10?',
      options: options,
      correctIndex: options.indexOf(correctStr),
      explanation: 'Bandwidth = GBWP / Av = 1,000,000 Hz / 10 = 100,000 Hz = 100 kHz.',
    );
  }

  static final List<QuizQuestion> _staticPretestPool = [
    const QuizQuestion(
      id: 101,
      question: 'What are the ideal values of open-loop gain (Aol) and input impedance (Rin) of an Op-Amp?',
      options: ['Aol = 0, Rin = 0', 'Aol = ∞, Rin = ∞', 'Aol = 100, Rin = 1 kΩ', 'Aol = ∞, Rin = 0'],
      correctIndex: 1,
      explanation: 'An ideal op-amp has infinite open-loop gain (Aol = ∞) and infinite input impedance (Rin = ∞) to avoid loading the source.',
    ),
    const QuizQuestion(
      id: 102,
      question: 'Why does the inverting terminal act as a "Virtual Ground" in an inverting amplifier?',
      options: [
        'It is physically connected to ground with a copper wire.',
        'Because non-inverting terminal is grounded and open-loop gain is extremely large, forcing Vdiff = V1 - V2 ≈ 0V.',
        'The power supply is disconnected.',
        'The feedback resistor has infinite resistance.',
      ],
      correctIndex: 1,
      explanation: 'With negative feedback, Vdiff = Vout / Aol ≈ 0. Since V1 is grounded (0V), terminal V2 is held at 0V by feedback.',
    ),
    const QuizQuestion(
      id: 103,
      question: 'Which pin of the standard 8-pin DIP IC 741 serves as the inverting input?',
      options: ['Pin 2', 'Pin 3', 'Pin 6', 'Pin 7'],
      correctIndex: 0,
      explanation: 'Pin 2 is Inverting Input (-), Pin 3 is Non-Inverting (+), Pin 6 is Output, Pin 7 is +Vcc, and Pin 4 is -Vee.',
    ),
    const QuizQuestion(
      id: 104,
      question: 'What does Slew Rate (SR) of an operational amplifier signify?',
      options: [
        'The maximum rate of change of output voltage per unit time (V/μs).',
        'The maximum DC voltage the op-amp can withstand.',
        'The resistance between input terminals.',
        'The ratio of differential gain to common-mode gain.',
      ],
      correctIndex: 0,
      explanation: 'Slew rate is the maximum rate at which the op-amp output voltage can swing in response to a step input (0.5 V/μs for 741).',
    ),
    const QuizQuestion(
      id: 105,
      question: 'What is Common-Mode Rejection Ratio (CMRR)?',
      options: [
        'The ratio of differential gain (Ad) to common-mode gain (Acm).',
        'The ratio of input resistance to output resistance.',
        'The ratio of feedback resistor to input resistor.',
        'The supply voltage divided by offset voltage.',
      ],
      correctIndex: 0,
      explanation: 'CMRR = Ad / Acm. It measures the op-amp\'s ability to reject unwanted common-mode noise.',
    ),
    const QuizQuestion(
      id: 106,
      question: 'What is the function of pins 1 and 5 (Offset Null) on the IC 741 op-amp?',
      options: [
        'To connect external frequency compensation capacitor.',
        'To balance internal transistor mismatch and zero the output offset voltage using a potentiometer.',
        'To adjust the slew rate of the amplifier.',
        'To provide high-voltage auxiliary power rails.',
      ],
      correctIndex: 1,
      explanation: 'Pins 1 and 5 connect to the emitters of the input pair to balance slight transistor mismatches to trim output offset to 0V.',
    ),
    const QuizQuestion(
      id: 107,
      question: 'What is the purpose of the internal 30 pF capacitor inside the IC 741?',
      options: [
        'To filter out 50/60 Hz power supply ripple.',
        'To provide dominant-pole frequency compensation, ensuring unity-gain stability without oscillation.',
        'To store electrical charge for short-circuit protection.',
        'To boost output slew rate.',
      ],
      correctIndex: 1,
      explanation: 'The internal 30 pF capacitor provides Miller compensation that introduces a dominant low-frequency pole around 5 Hz for unconditional stability.',
    ),
  ];

  static final List<QuizQuestion> _staticPosttestPool = [
    const QuizQuestion(
      id: 201,
      question: 'What is the phase difference between input and output in an inverting amplifier?',
      options: ['0° (in-phase)', '90°', '180° (out-of-phase)', '270°'],
      correctIndex: 2,
      explanation: 'An inverting amplifier produces an exact 180° phase inversion, represented by the negative sign in Av = -Rf/R1.',
    ),
    const QuizQuestion(
      id: 202,
      question: 'What happens to the circuit if feedback resistor Rf is disconnected (open circuit)?',
      options: [
        'Gain becomes unity (Av = 1).',
        'The circuit operates in open loop with massive gain (~200,000), causing immediate output saturation clipping.',
        'Output voltage stays constant at 0V.',
        'Input impedance drops to zero.',
      ],
      correctIndex: 1,
      explanation: 'Without Rf, the negative feedback path is broken. The circuit functions as an open-loop comparator.',
    ),
    const QuizQuestion(
      id: 203,
      question: 'A voltage follower (unity gain buffer) is obtained from a non-inverting amplifier by choosing:',
      options: [
        'Rf = 0 (short circuit) and R1 = ∞ (open circuit)',
        'Rf = ∞ and R1 = 0',
        'Rf = 10 kΩ and R1 = 10 kΩ',
        'Rf = 0 and R1 = 0',
      ],
      correctIndex: 0,
      explanation: 'In a voltage follower, Rf = 0 and R1 = ∞, yielding Av = 1 + (0 / ∞) = 1. It provides high input and low output impedance.',
    ),
    const QuizQuestion(
      id: 204,
      question: 'What is the input impedance seen by the signal source Vin in an inverting amplifier?',
      options: ['60 kΩ', '50 kΩ', 'Equal to input resistor R1', 'Infinite'],
      correctIndex: 2,
      explanation: 'Because the inverting terminal is held at virtual ground (0V), the input impedance seen by Vin is equal to R1.',
    ),
    const QuizQuestion(
      id: 205,
      question: 'What happens to the "Virtual Ground" at terminal V2 when the op-amp output enters saturation?',
      options: [
        'Virtual ground is maintained perfectly at 0.00V.',
        'Virtual ground is lost because the output can no longer adjust to balance the inputs; V2 departs from 0V.',
        'Terminal V2 drops to -15V.',
        'Op-Amp burns out.',
      ],
      correctIndex: 1,
      explanation: 'When saturated at ±Vsat, negative feedback fails and the virtual ground condition collapses.',
    ),
    const QuizQuestion(
      id: 206,
      question: 'To minimize DC offset voltage caused by input bias currents, a compensation resistor (Rcomp) connected between non-inverting input and ground should equal:',
      options: ['Rcomp = R1 + Rf', 'Rcomp = R1 ∥ Rf = (R1 × Rf) / (R1 + Rf)', 'Rcomp = Rf - R1', 'Rcomp = 0 Ω'],
      correctIndex: 1,
      explanation: 'To equalize DC resistance seen by both inputs so bias currents cancel differentially, Rcomp = R1 ∥ Rf.',
    ),
  ];
}

// =============================================================================
// SECTION 3: STATE MANAGEMENT CONTROLLER (SIMULATION & ANIMATION)
// =============================================================================

class StudentReportData {
  String studentName = 'Rajiv Ghimire';
  String rollNo = 'ECE-2026-042';
  String branch = 'Electronics & Communication Engineering';
  String college = 'Virtual Institute of Technology';
  String batch = 'Batch A1 (Semester IV)';
  DateTime experimentDate = DateTime.now();
}

class OpAmpController extends ChangeNotifier {
  OpAmpMode _mode = OpAmpMode.inverting;

  // Circuit Component Values
  double _r1 = 2000.0; // 2 kΩ
  double _rf = 20000.0; // 20 kΩ
  double _vin = 1.0; // 1.0 V
  final double _vcc = 15.0; // +15V rail
  final double _vee = -15.0; // -15V rail
  final double _vDrop = 1.5; // Vsat = 13.5V

  // Animated Waveform Simulation State
  bool _isSimulationRunning = true;
  double _timeOffset = 0.0;
  double _timebaseSpeed = 1.0;
  Timer? _animTimer;

  // Layout & UI State
  bool _isSidebarCollapsed = false;
  Color _selectedWireColor = const Color(0xFFDC2626);
  bool _showExpectedOverlay = false;
  bool _showTransferPlot = true;
  int _activePlotTab = 0; // 0 = Transfer Plot, 1 = Oscilloscope

  // Interactive Drag & Drop Workbench Layout
  late Map<String, DraggableComponent> _components;
  final List<CircuitWire> _wires = [];
  int _nextWireId = 1;

  // Dynamic Quizzes
  List<QuizQuestion> _pretestList = [];
  List<QuizQuestion> _posttestList = [];

  // Observation Table & Lab Report
  final List<LabReading> _readings = [];
  int _nextReadingId = 1;
  final StudentReportData reportData = StudentReportData();

  OpAmpController() {
    _initDefaultComponentLayout();
    shufflePretest();
    shufflePosttest();
    _startAnimationTicker();
  }

  @override
  void dispose() {
    _animTimer?.cancel();
    super.dispose();
  }

  // Getters
  OpAmpMode get mode => _mode;
  double get r1 => _r1;
  double get rf => _rf;
  double get vin => _vin;
  double get vcc => _vcc;
  double get vee => _vee;
  double get vSat => _vcc - _vDrop;
  bool get isSidebarCollapsed => _isSidebarCollapsed;
  bool get isSimulationRunning => _isSimulationRunning;
  double get timeOffset => _timeOffset;
  double get timebaseSpeed => _timebaseSpeed;
  Color get selectedWireColor => _selectedWireColor;
  bool get showExpectedOverlay => _showExpectedOverlay;
  bool get showTransferPlot => _showTransferPlot;
  int get activePlotTab => _activePlotTab;
  List<DraggableComponent> get components => _components.values.toList();
  List<CircuitWire> get wires => List.unmodifiable(_wires);
  List<QuizQuestion> get pretestList => _pretestList;
  List<QuizQuestion> get posttestList => _posttestList;
  List<LabReading> get readings => List.unmodifiable(_readings);

  // Timebase Animation (Moving Waveforms)
  void _startAnimationTicker() {
    _animTimer?.cancel();
    _animTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      if (_isSimulationRunning) {
        _timeOffset += 0.05 * _timebaseSpeed;
        if (_timeOffset > 1000.0) _timeOffset = 0.0;
        notifyListeners();
      }
    });
  }

  void toggleSimulationRunning() {
    _isSimulationRunning = !_isSimulationRunning;
    notifyListeners();
  }

  void setTimebaseSpeed(double speed) {
    _timebaseSpeed = speed;
    notifyListeners();
  }

  void resetWaveform() {
    _timeOffset = 0.0;
    notifyListeners();
  }

  void toggleSidebar() {
    _isSidebarCollapsed = !_isSidebarCollapsed;
    notifyListeners();
  }

  void shufflePretest() {
    _pretestList = DynamicQuizGenerator.generateFreshPretest();
    notifyListeners();
  }

  void shufflePosttest() {
    _posttestList = DynamicQuizGenerator.generateFreshPosttest();
    notifyListeners();
  }

  void _initDefaultComponentLayout() {
    _components = {
      'ic741': DraggableComponent(
        id: 'ic741',
        type: ComponentType.ic741,
        label: 'IC 741 Op-Amp',
        position: const Offset(440, 240),
        size: const Size(130, 110),
        terminals: const [
          TerminalPin(id: 1, label: '1: Null', localOffset: Offset(-55, -40)),
          TerminalPin(id: 2, label: '2: Inv (-)', localOffset: Offset(-55, -14), baseColor: Color(0xFFDC2626)),
          TerminalPin(id: 3, label: '3: Non-Inv (+)', localOffset: Offset(-55, 14), baseColor: Color(0xFF2563EB)),
          TerminalPin(id: 4, label: '4: -Vee', localOffset: Offset(-55, 40), baseColor: Color(0xFF475569)),
          TerminalPin(id: 5, label: '5: Null', localOffset: Offset(55, 40)),
          TerminalPin(id: 6, label: '6: Vo', localOffset: Offset(55, 14), baseColor: Color(0xFF16A34A)),
          TerminalPin(id: 7, label: '7: +Vcc', localOffset: Offset(55, -14), baseColor: Color(0xFFDC2626)),
          TerminalPin(id: 8, label: '8: NC', localOffset: Offset(55, -40)),
        ],
      ),
      'r1': DraggableComponent(
        id: 'r1',
        type: ComponentType.resistorR1,
        label: 'Resistor R1',
        position: const Offset(230, 226),
        size: const Size(110, 48),
        terminals: const [
          TerminalPin(id: 9, label: 'R1-A', localOffset: Offset(-45, 0)),
          TerminalPin(id: 10, label: 'R1-B', localOffset: Offset(45, 0)),
        ],
      ),
      'rf': DraggableComponent(
        id: 'rf',
        type: ComponentType.resistorRf,
        label: 'Feedback Rf',
        position: const Offset(440, 95),
        size: const Size(110, 48),
        terminals: const [
          TerminalPin(id: 11, label: 'Rf-A', localOffset: Offset(-45, 0)),
          TerminalPin(id: 12, label: 'Rf-B', localOffset: Offset(45, 0)),
        ],
      ),
      'vin': DraggableComponent(
        id: 'vin',
        type: ComponentType.voltageSource,
        label: 'DC Source Vin',
        position: const Offset(90, 226),
        size: const Size(110, 75),
        terminals: const [
          TerminalPin(id: 13, label: 'Vin (+)', localOffset: Offset(42, -15), baseColor: Color(0xFFDC2626)),
          TerminalPin(id: 14, label: 'Vin (-)', localOffset: Offset(42, 18), baseColor: Color(0xFF1E293B)),
        ],
      ),
      'pwr': DraggableComponent(
        id: 'pwr',
        type: ComponentType.powerSupply,
        label: 'Dual Supply (±15V)',
        position: const Offset(440, 390),
        size: const Size(140, 70),
        terminals: const [
          TerminalPin(id: 15, label: '+15V', localOffset: Offset(-42, 14), baseColor: Color(0xFFDC2626)),
          TerminalPin(id: 16, label: '-15V', localOffset: Offset(42, 14), baseColor: Color(0xFF2563EB)),
          TerminalPin(id: 17, label: 'COM', localOffset: Offset(0, 14), baseColor: Color(0xFF1E293B)),
        ],
      ),
      'gnd': DraggableComponent(
        id: 'gnd',
        type: ComponentType.ground,
        label: 'Earth Ground',
        position: const Offset(230, 350),
        size: const Size(80, 60),
        terminals: const [
          TerminalPin(id: 18, label: 'GND', localOffset: Offset(0, -10), baseColor: Color(0xFF16A34A)),
        ],
      ),
      'dmm': DraggableComponent(
        id: 'dmm',
        type: ComponentType.voltmeter,
        label: 'Voltmeter (Vo)',
        position: const Offset(660, 240),
        size: const Size(120, 80),
        terminals: const [
          TerminalPin(id: 19, label: 'V (+)', localOffset: Offset(-45, -14), baseColor: Color(0xFFDC2626)),
          TerminalPin(id: 20, label: 'COM (-)', localOffset: Offset(-45, 18), baseColor: Color(0xFF1E293B)),
        ],
      ),
    };
  }

  Offset? getTerminalGlobalPosition(int pinId) {
    for (final comp in _components.values) {
      for (final t in comp.terminals) {
        if (t.id == pinId) return comp.position + t.localOffset;
      }
    }
    return null;
  }

  void updateComponentPosition(String id, Offset pos) {
    if (_components.containsKey(id)) {
      _components[id] = _components[id]!.copyWith(position: pos);
      notifyListeners();
    }
  }

  void resetComponentLayout() {
    _initDefaultComponentLayout();
    notifyListeners();
  }

  void addWire(int fromPin, int toPin) {
    if (fromPin == toPin) return;
    if (_wires.any((w) => w.connects(fromPin, toPin))) return;
    _wires.add(CircuitWire(
      id: _nextWireId++,
      fromPin: fromPin,
      toPin: toPin,
      color: _selectedWireColor,
    ));
    notifyListeners();
  }

  void clearWires() {
    _wires.clear();
    notifyListeners();
  }

  void setWireColor(Color c) {
    _selectedWireColor = c;
    notifyListeners();
  }

  void toggleExpectedOverlay() {
    _showExpectedOverlay = !_showExpectedOverlay;
    notifyListeners();
  }

  void toggleTransferPlot() {
    _showTransferPlot = !_showTransferPlot;
    notifyListeners();
  }

  void setActivePlotTab(int index) {
    _activePlotTab = index;
    notifyListeners();
  }

  void setMode(OpAmpMode newMode) {
    if (_mode != newMode) {
      _mode = newMode;
      _wires.clear();
      notifyListeners();
    }
  }

  void setR1(double val) {
    _r1 = val.clamp(1000.0, 50000.0);
    notifyListeners();
  }

  void setRf(double val) {
    _rf = val.clamp(2000.0, 100000.0);
    notifyListeners();
  }

  void setVin(double val) {
    _vin = val.clamp(-15.0, 15.0);
    notifyListeners();
  }

  void stepVin(double delta) => setVin(_vin + delta);

  void multiplyVinByTwo() {
    double next = _vin * 2;
    if (next.abs() > 15.0) next = 15.0 * (_vin >= 0 ? 1 : -1);
    if (next == 0) next = 1.0;
    setVin(next);
  }

  void divideVinByTwo() {
    double next = _vin / 2;
    if (next.abs() < 0.1) next = 0.0;
    setVin(next);
  }

  List<ExpectedConnection> get expectedConnections {
    if (_mode == OpAmpMode.inverting) {
      return const [
        ExpectedConnection(step: 1, pinA: 13, pinB: 9, nameA: 'Vin (+)', nameB: 'R1-A', purpose: 'Feed input signal to R1'),
        ExpectedConnection(step: 2, pinA: 10, pinB: 2, nameA: 'R1-B', nameB: 'Pin 2 (Inv -)', purpose: 'Connect R1 to inverting terminal'),
        ExpectedConnection(step: 3, pinA: 2, pinB: 11, nameA: 'Pin 2 (Inv -)', nameB: 'Rf-A', purpose: 'Connect feedback resistor Rf input'),
        ExpectedConnection(step: 4, pinA: 6, pinB: 12, nameA: 'Pin 6 (Vo)', nameB: 'Rf-B', purpose: 'Close feedback loop to output'),
        ExpectedConnection(step: 5, pinA: 3, pinB: 18, nameA: 'Pin 3 (Non-Inv +)', nameB: 'GND', purpose: 'Ground non-inverting terminal'),
        ExpectedConnection(step: 6, pinA: 14, pinB: 18, nameA: 'Vin (-)', nameB: 'GND', purpose: 'Ground source return path'),
        ExpectedConnection(step: 7, pinA: 7, pinB: 15, nameA: 'Pin 7 (+Vcc)', nameB: '+15V', purpose: 'Power supply positive rail'),
        ExpectedConnection(step: 8, pinA: 4, pinB: 16, nameA: 'Pin 4 (-Vee)', nameB: '-15V', purpose: 'Power supply negative rail'),
        ExpectedConnection(step: 9, pinA: 6, pinB: 19, nameA: 'Pin 6 (Vo)', nameB: 'Voltmeter (+)', purpose: 'Connect output to voltmeter'),
        ExpectedConnection(step: 10, pinA: 20, pinB: 18, nameA: 'Voltmeter (-)', nameB: 'GND', purpose: 'Ground voltmeter return path'),
      ];
    } else {
      return const [
        ExpectedConnection(step: 1, pinA: 13, pinB: 3, nameA: 'Vin (+)', nameB: 'Pin 3 (Non-Inv +)', purpose: 'Feed input to non-inverting terminal'),
        ExpectedConnection(step: 2, pinA: 14, pinB: 18, nameA: 'Vin (-)', nameB: 'GND', purpose: 'Ground input reference'),
        ExpectedConnection(step: 3, pinA: 9, pinB: 18, nameA: 'R1-A', nameB: 'GND', purpose: 'Ground lower feedback resistor R1'),
        ExpectedConnection(step: 4, pinA: 10, pinB: 2, nameA: 'R1-B', nameB: 'Pin 2 (Inv -)', purpose: 'Connect divider junction to inverting terminal'),
        ExpectedConnection(step: 5, pinA: 2, pinB: 11, nameA: 'Pin 2 (Inv -)', nameB: 'Rf-A', purpose: 'Connect Rf to inverting junction'),
        ExpectedConnection(step: 6, pinA: 6, pinB: 12, nameA: 'Pin 6 (Vo)', nameB: 'Rf-B', purpose: 'Connect Rf to amplifier output'),
        ExpectedConnection(step: 7, pinA: 7, pinB: 15, nameA: 'Pin 7 (+Vcc)', nameB: '+15V', purpose: 'Power supply positive rail'),
        ExpectedConnection(step: 8, pinA: 4, pinB: 16, nameA: 'Pin 4 (-Vee)', nameB: '-15V', purpose: 'Power supply negative rail'),
        ExpectedConnection(step: 9, pinA: 6, pinB: 19, nameA: 'Pin 6 (Vo)', nameB: 'Voltmeter (+)', purpose: 'Connect output to voltmeter'),
        ExpectedConnection(step: 10, pinA: 20, pinB: 18, nameA: 'Voltmeter (-)', nameB: 'GND', purpose: 'Ground voltmeter return path'),
      ];
    }
  }

  bool _arePinsConnected(int pinA, int pinB) {
    if (pinA == pinB) return true;
    final parent = <int, int>{};
    int find(int i) {
      if (!parent.containsKey(i)) parent[i] = i;
      if (parent[i] == i) return i;
      return parent[i] = find(parent[i]!);
    }
    void union(int i, int j) {
      final rootI = find(i);
      final rootJ = find(j);
      if (rootI != rootJ) parent[rootI] = rootJ;
    }
    union(17, 18);
    for (final wire in _wires) {
      union(wire.fromPin, wire.toPin);
    }
    return find(pinA) == find(pinB);
  }

  bool isConnectionSatisfied(ExpectedConnection ec) => _arePinsConnected(ec.pinA, ec.pinB);

  bool get isCircuitConnected {
    for (final exp in expectedConnections) {
      if (!isConnectionSatisfied(exp)) return false;
    }
    return true;
  }

  CircuitVerificationReport verifyCircuit() {
    final missing = <ExpectedConnection>[];
    for (final exp in expectedConnections) {
      if (!isConnectionSatisfied(exp)) {
        missing.add(exp);
      }
    }
    return CircuitVerificationReport(
      isComplete: missing.isEmpty,
      missingConnections: missing,
    );
  }

  void autoWireCircuit() {
    _wires.clear();
    for (final exp in expectedConnections) {
      _wires.add(CircuitWire(
        id: _nextWireId++,
        fromPin: exp.pinA,
        toPin: exp.pinB,
        color: _getColorForWire(exp.pinA, exp.pinB),
      ));
    }
    notifyListeners();
  }

  Color _getColorForWire(int pA, int pB) {
    if (pA == 15 || pB == 15 || pA == 7 || pB == 7) return const Color(0xFFDC2626);
    if (pA == 16 || pB == 16 || pA == 4 || pB == 4) return const Color(0xFF2563EB);
    if (pA == 18 || pB == 18 || pA == 17 || pB == 17 || pA == 14 || pB == 14 || pA == 20 || pB == 20) {
      return const Color(0xFF1E293B);
    }
    if (pA == 6 || pB == 6 || pA == 19 || pB == 19) return const Color(0xFF16A34A);
    return const Color(0xFFD97706);
  }

  double get theoreticalGain {
    if (_r1 <= 0) return 0.0;
    return _mode == OpAmpMode.inverting ? -(_rf / _r1) : 1.0 + (_rf / _r1);
  }

  double get expectedOutputVoltage => theoreticalGain * _vin;

  double get outputVoltage {
    if (!isCircuitConnected) return 0.0;
    final exp = expectedOutputVoltage;
    if (exp > vSat) return vSat;
    if (exp < -vSat) return -vSat;
    return exp;
  }

  bool get isSaturated => isCircuitConnected && (expectedOutputVoltage.abs() > vSat);

  void addReadingToTable() {
    if (!isCircuitConnected) return;
    final expVo = expectedOutputVoltage;
    final measVo = outputVoltage;
    final err = expVo != 0.0 ? ((measVo - expVo).abs() / expVo.abs()) * 100 : 0.0;

    _readings.add(LabReading(
      serialNo: _nextReadingId++,
      vin: _vin,
      r1: _r1,
      rf: _rf,
      expectedVout: expVo,
      measuredVout: measVo,
      errorPercent: double.parse(err.toStringAsFixed(1)),
      isSaturated: isSaturated,
    ));
    notifyListeners();
  }

  void clearTable() {
    _readings.clear();
    _nextReadingId = 1;
    notifyListeners();
  }

  String generateCsv() {
    final buffer = StringBuffer();
    buffer.writeln('S.No,Mode,Vin (V),R1 (kOhm),Rf (kOhm),Theoretical Gain,Expected Vo (V),Measured Vo (V),Error (%),State');
    for (final r in _readings) {
      final state = r.isSaturated ? 'Saturated' : 'Linear';
      final gain = (_mode == OpAmpMode.inverting ? -(r.rf / r.r1) : (1 + r.rf / r.r1)).toStringAsFixed(2);
      buffer.writeln(
        '${r.serialNo},${_mode.label},${r.vin.toStringAsFixed(2)},${(r.r1 / 1000).toStringAsFixed(1)},${(r.rf / 1000).toStringAsFixed(1)},$gain,${r.expectedVout.toStringAsFixed(2)},${r.measuredVout.toStringAsFixed(2)},${r.errorPercent.toStringAsFixed(1)}%,$state',
      );
    }
    return buffer.toString();
  }
}

// =============================================================================
// SECTION 4: REALISTIC WORKBENCH & ANIMATED CANVAS PAINTER
// =============================================================================

class RealisticWorkbenchCanvas extends StatefulWidget {
  final OpAmpController ctrl;
  final bool isDark;
  const RealisticWorkbenchCanvas({super.key, required this.ctrl, required this.isDark});

  @override
  State<RealisticWorkbenchCanvas> createState() => _RealisticWorkbenchCanvasState();
}

class _RealisticWorkbenchCanvasState extends State<RealisticWorkbenchCanvas> {
  int? _selectedStartPin;
  Offset? _rubberBandPos;
  int? _hoveredPin;
  String? _draggingComponentId;
  Offset? _dragStartOffset;

  TerminalPin? _findTerminalAt(Offset localPos, double hitRadius) {
    for (final comp in widget.ctrl.components) {
      for (final t in comp.terminals) {
        final pinPos = comp.position + t.localOffset;
        if ((pinPos - localPos).distance <= hitRadius) return t;
      }
    }
    return null;
  }

  String? _findComponentAt(Offset localPos) {
    for (final comp in widget.ctrl.components.reversed) {
      final rect = Rect.fromCenter(
        center: comp.position,
        width: comp.size.width,
        height: comp.size.height,
      );
      if (rect.contains(localPos)) return comp.id;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.ctrl;

    return Container(
      height: 520,
      width: double.infinity,
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: widget.isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1), width: 1.5),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: MouseRegion(
          onHover: (e) {
            final t = _findTerminalAt(e.localPosition, 16.0);
            if (t?.id != _hoveredPin) {
              setState(() => _hoveredPin = t?.id);
            }
          },
          child: GestureDetector(
            onPanStart: (details) {
              final pos = details.localPosition;
              final pin = _findTerminalAt(pos, 18.0);
              if (pin != null) {
                setState(() {
                  _selectedStartPin = pin.id;
                  _rubberBandPos = pos;
                  _draggingComponentId = null;
                });
              } else {
                final compId = _findComponentAt(pos);
                if (compId != null) {
                  setState(() {
                    _draggingComponentId = compId;
                    _dragStartOffset = pos - ctrl._components[compId]!.position;
                    _selectedStartPin = null;
                    _rubberBandPos = null;
                  });
                }
              }
            },
            onPanUpdate: (details) {
              final pos = details.localPosition;
              if (_selectedStartPin != null) {
                setState(() => _rubberBandPos = pos);
              } else if (_draggingComponentId != null && _dragStartOffset != null) {
                final newCenter = pos - _dragStartOffset!;
                final clampedX = newCenter.dx.clamp(60.0, 780.0);
                final clampedY = newCenter.dy.clamp(40.0, 480.0);
                ctrl.updateComponentPosition(_draggingComponentId!, Offset(clampedX, clampedY));
              }
            },
            onPanEnd: (_) {
              if (_selectedStartPin != null && _rubberBandPos != null) {
                final targetPin = _findTerminalAt(_rubberBandPos!, 22.0);
                if (targetPin != null && targetPin.id != _selectedStartPin) {
                  ctrl.addWire(_selectedStartPin!, targetPin.id);
                }
              }
              setState(() {
                _selectedStartPin = null;
                _rubberBandPos = null;
                _draggingComponentId = null;
                _dragStartOffset = null;
              });
            },
            onTapUp: (details) {
              final pin = _findTerminalAt(details.localPosition, 20.0);
              if (pin != null) {
                if (_selectedStartPin == null) {
                  setState(() => _selectedStartPin = pin.id);
                } else if (_selectedStartPin != pin.id) {
                  ctrl.addWire(_selectedStartPin!, pin.id);
                  setState(() => _selectedStartPin = null);
                } else {
                  setState(() => _selectedStartPin = null);
                }
              } else {
                setState(() => _selectedStartPin = null);
              }
            },
            child: CustomPaint(
              painter: _WorkbenchPainter(
                ctrl: ctrl,
                isDark: widget.isDark,
                selectedStartPin: _selectedStartPin,
                rubberBandPos: _rubberBandPos,
                hoveredPin: _hoveredPin,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkbenchPainter extends CustomPainter {
  final OpAmpController ctrl;
  final bool isDark;
  final int? selectedStartPin;
  final Offset? rubberBandPos;
  final int? hoveredPin;

  _WorkbenchPainter({
    required this.ctrl,
    required this.isDark,
    required this.selectedStartPin,
    required this.rubberBandPos,
    required this.hoveredPin,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawEngineeringGrid(canvas, size);

    if (ctrl.showExpectedOverlay) {
      _drawExpectedGuides(canvas);
    }

    for (final comp in ctrl.components) {
      _drawComponent(canvas, comp);
    }

    for (final wire in ctrl.wires) {
      final pA = ctrl.getTerminalGlobalPosition(wire.fromPin);
      final pB = ctrl.getTerminalGlobalPosition(wire.toPin);
      if (pA != null && pB != null) {
        _drawRealisticPatchCord(canvas, pA, pB, wire.color);
      }
    }

    if (selectedStartPin != null && rubberBandPos != null) {
      final startPos = ctrl.getTerminalGlobalPosition(selectedStartPin!);
      if (startPos != null) {
        _drawRealisticPatchCord(canvas, startPos, rubberBandPos!, ctrl.selectedWireColor, isTemporary: true);
      }
    }

    for (final comp in ctrl.components) {
      for (final t in comp.terminals) {
        final pos = comp.position + t.localOffset;
        final isSelected = selectedStartPin == t.id;
        final isHovered = hoveredPin == t.id;
        _drawTerminalSocket(canvas, pos, t, isSelected: isSelected, isHovered: isHovered);
      }
    }
  }

  void _drawEngineeringGrid(Canvas canvas, Size size) {
    final dotPaint = Paint()..color = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    for (double x = 15; x < size.width; x += 20) {
      for (double y = 15; y < size.height; y += 20) {
        canvas.drawCircle(Offset(x, y), 0.85, dotPaint);
      }
    }
  }

  void _drawExpectedGuides(Canvas canvas) {
    final guidePaint = Paint()
      ..color = const Color(0xFF0284C7).withOpacity(0.55)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    for (final exp in ctrl.expectedConnections) {
      final pA = ctrl.getTerminalGlobalPosition(exp.pinA);
      final pB = ctrl.getTerminalGlobalPosition(exp.pinB);
      if (pA != null && pB != null) {
        final mid = Offset((pA.dx + pB.dx) / 2, (pA.dy + pB.dy) / 2 + 25);
        final path = Path()..moveTo(pA.dx, pA.dy)..quadraticBezierTo(mid.dx, mid.dy, pB.dx, pB.dy);
        for (final metric in path.computeMetrics()) {
          double dist = 0.0;
          while (dist < metric.length) {
            final len = math.min(6.0, metric.length - dist);
            canvas.drawPath(metric.extractPath(dist, dist + len), guidePaint);
            dist += 12.0;
          }
        }
      }
    }
  }

  void _drawComponent(Canvas canvas, DraggableComponent comp) {
    switch (comp.type) {
      case ComponentType.ic741:
        _drawIc741Module(canvas, comp);
        break;
      case ComponentType.resistorR1:
        _drawResistorModule(canvas, comp, ctrl.r1, 'R1');
        break;
      case ComponentType.resistorRf:
        _drawResistorModule(canvas, comp, ctrl.rf, 'Rf');
        break;
      case ComponentType.voltageSource:
        _drawVoltageSourceModule(canvas, comp, ctrl.vin);
        break;
      case ComponentType.powerSupply:
        _drawPowerSupplyModule(canvas, comp);
        break;
      case ComponentType.ground:
        _drawGroundModule(canvas, comp);
        break;
      case ComponentType.voltmeter:
        _drawVoltmeterModule(canvas, comp, ctrl.outputVoltage, ctrl.isCircuitConnected);
        break;
    }
  }

  void _drawIc741Module(Canvas canvas, DraggableComponent comp) {
    final rect = Rect.fromCenter(center: comp.position, width: comp.size.width, height: comp.size.height);
    final baseRRect = RRect.fromRectAndRadius(rect, const Radius.circular(6));
    canvas.drawRRect(baseRRect, Paint()..color = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9));
    canvas.drawRRect(baseRRect, Paint()..color = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)..style = PaintingStyle.stroke..strokeWidth = 1.2);

    final chipRect = Rect.fromCenter(center: comp.position, width: 88, height: 95);
    canvas.drawRRect(RRect.fromRectAndRadius(chipRect, const Radius.circular(4)), Paint()..color = const Color(0xFF0F172A));

    final notchPath = Path()..addArc(Rect.fromCenter(center: Offset(comp.position.dx, chipRect.top), width: 14, height: 14), 0, math.pi);
    canvas.drawPath(notchPath, Paint()..color = const Color(0xFF334155));

    _drawText(canvas, 'μA741CN', Offset(comp.position.dx, comp.position.dy - 22), isBold: true, fontSize: 10, color: const Color(0xFF94A3B8));
    _drawText(canvas, 'DIP-8 OP-AMP', Offset(comp.position.dx, comp.position.dy - 10), isBold: false, fontSize: 8, color: const Color(0xFF64748B));

    final triP1 = Offset(comp.position.dx - 18, comp.position.dy + 8);
    final triP2 = Offset(comp.position.dx - 18, comp.position.dy + 34);
    final triP3 = Offset(comp.position.dx + 18, comp.position.dy + 21);
    final triPath = Path()..moveTo(triP1.dx, triP1.dy)..lineTo(triP2.dx, triP2.dy)..lineTo(triP3.dx, triP3.dy)..close();

    canvas.drawPath(triPath, Paint()..color = const Color(0xFF1E293B));
    canvas.drawPath(triPath, Paint()..color = const Color(0xFF38BDF8)..style = PaintingStyle.stroke..strokeWidth = 1.4);
    _drawText(canvas, '-', Offset(comp.position.dx - 11, comp.position.dy + 14), isBold: true, fontSize: 12, color: Colors.white);
    _drawText(canvas, '+', Offset(comp.position.dx - 11, comp.position.dy + 26), isBold: true, fontSize: 12, color: Colors.white);
  }

  void _drawResistorModule(Canvas canvas, DraggableComponent comp, double ohms, String name) {
    final rect = Rect.fromCenter(center: comp.position, width: comp.size.width, height: comp.size.height);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(5)), Paint()..color = isDark ? const Color(0xFF1E293B) : Colors.white);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(5)), Paint()..color = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)..style = PaintingStyle.stroke);

    final leadPaint = Paint()..color = const Color(0xFF94A3B8)..strokeWidth = 2.2;
    canvas.drawLine(Offset(comp.position.dx - 45, comp.position.dy), Offset(comp.position.dx - 22, comp.position.dy), leadPaint);
    canvas.drawLine(Offset(comp.position.dx + 22, comp.position.dy), Offset(comp.position.dx + 45, comp.position.dy), leadPaint);

    final bodyRect = Rect.fromCenter(center: comp.position, width: 44, height: 18);
    canvas.drawRRect(RRect.fromRectAndRadius(bodyRect, const Radius.circular(4)), Paint()..color = const Color(0xFFE2D9C8));

    final bands = _getResistorBands(ohms);
    for (int i = 0; i < bands.length; i++) {
      final bx = comp.position.dx - 14 + i * 8;
      canvas.drawLine(Offset(bx, comp.position.dy - 8), Offset(bx, comp.position.dy + 8), Paint()..color = bands[i]..strokeWidth = 2.5);
    }
    _drawText(canvas, '$name = ${(ohms / 1000).toStringAsFixed(1)} kΩ', Offset(comp.position.dx, comp.position.dy - 16), isBold: true, fontSize: 10, color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B));
  }

  List<Color> _getResistorBands(double ohms) {
    final k = (ohms / 1000).toInt();
    if (k == 1) return const [Color(0xFF8B4513), Colors.black, Color(0xFFEF4444), Color(0xFFD4AF37)];
    if (k == 2) return const [Color(0xFFEF4444), Colors.black, Color(0xFFEF4444), Color(0xFFD4AF37)];
    if (k == 5) return const [Color(0xFF22C55E), Colors.black, Color(0xFFEF4444), Color(0xFFD4AF37)];
    if (k == 10) return const [Color(0xFF8B4513), Colors.black, Color(0xFFF97316), Color(0xFFD4AF37)];
    if (k == 20) return const [Color(0xFFEF4444), Colors.black, Color(0xFFF97316), Color(0xFFD4AF37)];
    if (k == 50) return const [Color(0xFF22C55E), Colors.black, Color(0xFFF97316), Color(0xFFD4AF37)];
    return const [Color(0xFF8B4513), Colors.black, Color(0xFFFBBF24), Color(0xFFD4AF37)];
  }

  void _drawVoltageSourceModule(Canvas canvas, DraggableComponent comp, double vin) {
    final rect = Rect.fromCenter(center: comp.position, width: comp.size.width, height: comp.size.height);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(5)), Paint()..color = const Color(0xFF1E293B));
    _drawText(canvas, 'DC SOURCE', Offset(comp.position.dx - 12, comp.position.dy - 24), isBold: true, fontSize: 9, color: const Color(0xFF94A3B8));

    final lcdRect = Rect.fromCenter(center: Offset(comp.position.dx - 14, comp.position.dy + 4), width: 62, height: 26);
    canvas.drawRRect(RRect.fromRectAndRadius(lcdRect, const Radius.circular(3)), Paint()..color = const Color(0xFF0F172A));
    _drawText(canvas, '${vin >= 0 ? '+' : ''}${vin.toStringAsFixed(1)} V', Offset(comp.position.dx - 14, comp.position.dy + 4), isBold: true, fontSize: 12, color: const Color(0xFF10B981));
  }

  void _drawPowerSupplyModule(Canvas canvas, DraggableComponent comp) {
    final rect = Rect.fromCenter(center: comp.position, width: comp.size.width, height: comp.size.height);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(5)), Paint()..color = const Color(0xFF334155));
    _drawText(canvas, 'DUAL DC POWER SUPPLY', Offset(comp.position.dx, comp.position.dy - 20), isBold: true, fontSize: 9, color: const Color(0xFFF1F5F9));
    _drawText(canvas, '+15V    COM    -15V', Offset(comp.position.dx, comp.position.dy - 6), isBold: true, fontSize: 8, color: const Color(0xFF94A3B8));
  }

  void _drawGroundModule(Canvas canvas, DraggableComponent comp) {
    final rect = Rect.fromCenter(center: comp.position, width: comp.size.width, height: comp.size.height);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(5)), Paint()..color = isDark ? const Color(0xFF1E293B) : Colors.white);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(5)), Paint()..color = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)..style = PaintingStyle.stroke);

    _drawText(canvas, 'EARTH GND', Offset(comp.position.dx, comp.position.dy - 18), isBold: true, fontSize: 8, color: const Color(0xFF64748B));
    final gy = comp.position.dy + 14;
    final p = Paint()..color = isDark ? const Color(0xFF94A3B8) : const Color(0xFF1E293B)..strokeWidth = 1.8;
    canvas.drawLine(Offset(comp.position.dx, comp.position.dy + 4), Offset(comp.position.dx, gy), p);
    canvas.drawLine(Offset(comp.position.dx - 14, gy), Offset(comp.position.dx + 14, gy), p);
    canvas.drawLine(Offset(comp.position.dx - 9, gy + 4), Offset(comp.position.dx + 9, gy + 4), p);
    canvas.drawLine(Offset(comp.position.dx - 4, gy + 8), Offset(comp.position.dx + 4, gy + 8), p);
  }

  void _drawVoltmeterModule(Canvas canvas, DraggableComponent comp, double vo, bool isConnected) {
    final rect = Rect.fromCenter(center: comp.position, width: comp.size.width, height: comp.size.height);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(5)), Paint()..color = const Color(0xFF1E293B));
    _drawText(canvas, 'DIGITAL VOLTMETER', Offset(comp.position.dx + 12, comp.position.dy - 24), isBold: true, fontSize: 9, color: const Color(0xFF94A3B8));

    final scrRect = Rect.fromCenter(center: Offset(comp.position.dx + 12, comp.position.dy + 4), width: 75, height: 28);
    canvas.drawRRect(RRect.fromRectAndRadius(scrRect, const Radius.circular(3)), Paint()..color = const Color(0xFF0F172A));

    final text = isConnected ? '${vo.toStringAsFixed(2)} V' : '--.-- V';
    final col = !isConnected ? const Color(0xFF64748B) : (vo.abs() >= 13.4 ? const Color(0xFFEF4444) : const Color(0xFF38BDF8));
    _drawText(canvas, text, Offset(comp.position.dx + 12, comp.position.dy + 4), isBold: true, fontSize: 13, color: col);
  }

  void _drawRealisticPatchCord(Canvas canvas, Offset pA, Offset pB, Color color, {bool isTemporary = false}) {
    final dist = (pB - pA).distance;
    final sag = math.min(65.0, 15.0 + dist * 0.15);
    final mid = Offset((pA.dx + pB.dx) / 2, math.max(pA.dy, pB.dy) + sag);

    final path = Path()..moveTo(pA.dx, pA.dy)..quadraticBezierTo(mid.dx, mid.dy, pB.dx, pB.dy);

    final shadowPath = Path()..moveTo(pA.dx + 2, pA.dy + 4)..quadraticBezierTo(mid.dx + 2, mid.dy + 6, pB.dx + 2, pB.dy + 4);
    canvas.drawPath(
      shadowPath,
      Paint()..color = Colors.black.withOpacity(0.18)..strokeWidth = 4.0..style = PaintingStyle.stroke..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );

    canvas.drawPath(path, Paint()..color = color..strokeWidth = isTemporary ? 3.0 : 4.0..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);
    canvas.drawPath(path, Paint()..color = Colors.white.withOpacity(0.35)..strokeWidth = 1.2..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);

    _drawBananaPlug(canvas, pA, color);
    _drawBananaPlug(canvas, pB, color);
  }

  void _drawBananaPlug(Canvas canvas, Offset pos, Color color) {
    canvas.drawCircle(pos, 4.5, Paint()..color = const Color(0xFFCBD5E1));
    canvas.drawCircle(pos, 3.2, Paint()..color = color);
  }

  void _drawTerminalSocket(Canvas canvas, Offset pos, TerminalPin pin, {bool isSelected = false, bool isHovered = false}) {
    canvas.drawCircle(pos, 8.5, Paint()..color = const Color(0xFFB45309));
    canvas.drawCircle(pos, 7.0, Paint()..color = const Color(0xFFFBBF24));
    canvas.drawCircle(pos, 4.0, Paint()..color = const Color(0xFF0F172A));

    _drawText(
      canvas,
      pin.label,
      Offset(pos.dx, pos.dy + 12),
      fontSize: 8.5,
      isBold: true,
      color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
    );

    if (isSelected || isHovered) {
      canvas.drawCircle(
        pos,
        12.0,
        Paint()
          ..color = (isSelected ? const Color(0xFFEF4444) : const Color(0xFF38BDF8)).withOpacity(0.45)
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke,
      );
    }
  }

  void _drawText(Canvas canvas, String text, Offset pos, {double fontSize = 10, bool isBold = false, Color color = const Color(0xFF1E293B)}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontFamily: 'Segoe UI', color: color)),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _WorkbenchPainter oldDelegate) => true;
}

// =============================================================================
// SECTION 5: ANIMATED OSCILLOSCOPE & DUAL PLOTTER
// =============================================================================

class EngineeringPlotterWidget extends StatelessWidget {
  final OpAmpController ctrl;
  final bool isDark;
  const EngineeringPlotterWidget({super.key, required this.ctrl, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.show_chart, size: 18, color: Color(0xFF1E40AF)),
                  const SizedBox(width: 8),
                  Text('Oscilloscope Display', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : const Color(0xFF1E293B))),
                ],
              ),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildTabButton('Transfer Curve (Vo vs Vin)', 0),
                  _buildTabButton('Dual-Trace Oscilloscope', 1),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Oscilloscope Animation Controls
          if (ctrl.activePlotTab == 1)
            Row(
              children: [
                IconButton(
                  icon: Icon(ctrl.isSimulationRunning ? Icons.pause_circle_filled : Icons.play_circle_fill, color: const Color(0xFF10B981), size: 24),
                  tooltip: ctrl.isSimulationRunning ? 'Pause Waveform' : 'Play Waveform',
                  onPressed: ctrl.toggleSimulationRunning,
                ),
                IconButton(
                  icon: const Icon(Icons.restart_alt, size: 20),
                  tooltip: 'Reset Phase',
                  onPressed: ctrl.resetWaveform,
                ),
                const SizedBox(width: 8),
                const Text('Speed: ', style: TextStyle(fontSize: 11)),
                ...[0.5, 1.0, 2.0].map((s) {
                  final isSel = (ctrl.timebaseSpeed - s).abs() < 0.1;
                  return Padding(
                    padding: const EdgeInsets.only(right: 4.0),
                    child: InkWell(
                      onTap: () => ctrl.setTimebaseSpeed(s),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSel ? const Color(0xFF1E40AF) : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text('${s}x', style: TextStyle(fontSize: 10, color: isSel ? Colors.white : null)),
                      ),
                    ),
                  );
                }),
              ],
            ),
          const SizedBox(height: 8),
          SizedBox(
            height: 290,
            width: double.infinity,
            child: ctrl.activePlotTab == 0
                ? CustomPaint(
                    painter: _TransferCharacteristicsPainter(
                      mode: ctrl.mode,
                      gain: ctrl.theoreticalGain,
                      vSat: ctrl.vSat,
                      currentVin: ctrl.vin,
                      currentVout: ctrl.outputVoltage,
                      readings: ctrl.readings,
                      timeOffset: ctrl.timeOffset,
                      isDark: isDark,
                    ),
                  )
                : CustomPaint(
                    painter: _AnimatedOscilloscopePainter(
                      mode: ctrl.mode,
                      vin: ctrl.vin,
                      vout: ctrl.outputVoltage,
                      vSat: ctrl.vSat,
                      timeOffset: ctrl.timeOffset,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, int index) {
    final isSelected = ctrl.activePlotTab == index;
    return InkWell(
      onTap: () => ctrl.setActivePlotTab(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E40AF) : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569))),
        ),
      ),
    );
  }
}

class _TransferCharacteristicsPainter extends CustomPainter {
  final OpAmpMode mode;
  final double gain;
  final double vSat;
  final double currentVin;
  final double currentVout;
  final List<LabReading> readings;
  final double timeOffset;
  final bool isDark;

  _TransferCharacteristicsPainter({
    required this.mode,
    required this.gain,
    required this.vSat,
    required this.currentVin,
    required this.currentVout,
    required this.readings,
    required this.timeOffset,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const padL = 45.0;
    const padR = 25.0;
    const padT = 25.0;
    const padB = 35.0;

    final w = size.width - padL - padR;
    final h = size.height - padT - padB;

    final gridPaint = Paint()..color = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)..strokeWidth = 1.0;
    final axisPaint = Paint()..color = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)..strokeWidth = 1.6;

    double toX(double v) => padL + ((v + 15.0) / 30.0) * w;
    double toY(double v) => padT + ((15.0 - v) / 30.0) * h;

    for (int v = -15; v <= 15; v += 5) {
      canvas.drawLine(Offset(toX(v.toDouble()), padT), Offset(toX(v.toDouble()), padT + h), gridPaint);
      canvas.drawLine(Offset(padL, toY(v.toDouble())), Offset(padL + w, toY(v.toDouble())), gridPaint);
      if (v != 0) {
        _drawText(canvas, '$v', Offset(toX(v.toDouble()), toY(0) + 10), fontSize: 9, color: const Color(0xFF94A3B8));
        _drawText(canvas, '$v', Offset(toX(0) - 14, toY(v.toDouble())), fontSize: 9, color: const Color(0xFF94A3B8));
      }
    }

    canvas.drawLine(Offset(padL, toY(0)), Offset(padL + w, toY(0)), axisPaint);
    canvas.drawLine(Offset(toX(0), padT), Offset(toX(0), padT + h), axisPaint);

    _drawText(canvas, 'Vin (V)', Offset(padL + w - 10, toY(0) + 14), isBold: true, fontSize: 10, color: isDark ? Colors.white : const Color(0xFF1E293B));
    _drawText(canvas, 'Vout (V)', Offset(toX(0) + 24, padT + 8), isBold: true, fontSize: 10, color: isDark ? Colors.white : const Color(0xFF1E293B));

    final satPaint = Paint()..color = const Color(0xFFEF4444).withOpacity(0.5)..strokeWidth = 1.2..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(padL, toY(vSat)), Offset(padL + w, toY(vSat)), satPaint);
    canvas.drawLine(Offset(padL, toY(-vSat)), Offset(padL + w, toY(-vSat)), satPaint);
    _drawText(canvas, '+Vsat (+13.5V)', Offset(padL + 45, toY(vSat) - 8), fontSize: 9, color: const Color(0xFFEF4444));
    _drawText(canvas, '-Vsat (-13.5V)', Offset(padL + 45, toY(-vSat) + 8), fontSize: 9, color: const Color(0xFFEF4444));

    final curvePath = Path();
    bool first = true;
    for (double vinVal = -15.0; vinVal <= 15.0; vinVal += 0.2) {
      double theoVo = gain * vinVal;
      if (theoVo > vSat) theoVo = vSat;
      if (theoVo < -vSat) theoVo = -vSat;
      final px = toX(vinVal);
      final py = toY(theoVo);
      if (first) {
        curvePath.moveTo(px, py);
        first = false;
      } else {
        curvePath.lineTo(px, py);
      }
    }

    canvas.drawPath(curvePath, Paint()..color = const Color(0xFF2563EB)..strokeWidth = 2.4..style = PaintingStyle.stroke);

    for (final r in readings) {
      final px = toX(r.vin);
      final py = toY(r.measuredVout);
      canvas.drawCircle(Offset(px, py), 4.5, Paint()..color = const Color(0xFFD97706));
      canvas.drawCircle(Offset(px, py), 2.5, Paint()..color = Colors.white);
    }

    // Animated Sweep Indicator tracking moving sinusoidal input
    final sweepVin = currentVin * math.sin(timeOffset);
    double sweepVout = gain * sweepVin;
    if (sweepVout > vSat) sweepVout = vSat;
    if (sweepVout < -vSat) sweepVout = -vSat;

    final curX = toX(sweepVin);
    final curY = toY(sweepVout);
    canvas.drawCircle(Offset(curX, curY), 7.0, Paint()..color = const Color(0xFFDC2626));
    canvas.drawCircle(Offset(curX, curY), 3.5, Paint()..color = Colors.white);
  }

  void _drawText(Canvas canvas, String text, Offset pos, {double fontSize = 10, bool isBold = false, Color color = const Color(0xFF1E293B)}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color)),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _AnimatedOscilloscopePainter extends CustomPainter {
  final OpAmpMode mode;
  final double vin;
  final double vout;
  final double vSat;
  final double timeOffset;

  _AnimatedOscilloscopePainter({
    required this.mode,
    required this.vin,
    required this.vout,
    required this.vSat,
    required this.timeOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF0F172A));

    final gridPaint = Paint()..color = const Color(0xFF1E293B)..strokeWidth = 1.0;
    for (double x = 0; x < size.width; x += 30) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 30) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final midY = size.height / 2;
    canvas.drawLine(Offset(0, midY), Offset(size.width, midY), Paint()..color = const Color(0xFF334155)..strokeWidth = 1.4);

    final ch1Path = Path();
    final ch2Path = Path();

    final ampIn = vin.abs() * 8.0;
    final ampOut = vout.abs() * 8.0;
    final phaseInvert = (mode == OpAmpMode.inverting);

    for (double x = 0; x <= size.width; x += 2) {
      final rad = (x / 40.0) * 2 * math.pi + timeOffset;
      final yIn = midY - ampIn * math.sin(rad);

      double yOutVal = (phaseInvert ? -1 : 1) * ampOut * math.sin(rad);
      if (yOutVal > vSat * 8.0) yOutVal = vSat * 8.0;
      if (yOutVal < -vSat * 8.0) yOutVal = -vSat * 8.0;

      final yOut = midY - yOutVal;

      if (x == 0) {
        ch1Path.moveTo(x, yIn);
        ch2Path.moveTo(x, yOut);
      } else {
        ch1Path.lineTo(x, yIn);
        ch2Path.lineTo(x, yOut);
      }
    }

    canvas.drawPath(ch1Path, Paint()..color = const Color(0xFFFBBF24)..strokeWidth = 2.0..style = PaintingStyle.stroke);
    canvas.drawPath(ch2Path, Paint()..color = const Color(0xFF4ADE80)..strokeWidth = 2.4..style = PaintingStyle.stroke);

    final tp1 = TextPainter(text: const TextSpan(text: 'CH1: Vin(t) [Amber]', style: TextStyle(color: Color(0xFFFBBF24), fontSize: 10, fontWeight: FontWeight.bold)), textDirection: TextDirection.ltr)..layout();
    tp1.paint(canvas, const Offset(12, 10));

    final tp2 = TextPainter(text: const TextSpan(text: 'CH2: Vout(t) [Green - Live Flowing]', style: TextStyle(color: Color(0xFF4ADE80), fontSize: 10, fontWeight: FontWeight.bold)), textDirection: TextDirection.ltr)..layout();
    tp2.paint(canvas, const Offset(150, 10));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// =============================================================================
// SECTION 6: INTERACTIVE THEORY, APPARATUS & RESEARCH PAPERS
// =============================================================================

class InteractiveTheoryExplorer extends StatefulWidget {
  final OpAmpController ctrl;
  const InteractiveTheoryExplorer({super.key, required this.ctrl});

  @override
  State<InteractiveTheoryExplorer> createState() => _InteractiveTheoryExplorerState();
}

class _InteractiveTheoryExplorerState extends State<InteractiveTheoryExplorer> {
  int _selectedPin = 2; // Pin 2 by default

  final Map<int, Map<String, String>> _pinDetails = const {
    1: {'name': 'Offset Null 1', 'desc': 'Connected to the emitter of the input differential transistor. Used with pin 5 and a 10 kΩ trim pot to zero input offset voltage.'},
    2: {'name': 'Inverting Input (-)', 'desc': 'Signal terminal that produces a 180° phase inversion. In negative feedback, acts as Virtual Ground (0V).'},
    3: {'name': 'Non-Inverting Input (+)', 'desc': 'High-impedance direct input (> 2 MΩ). Produces in-phase output (0° phase shift).'},
    4: {'name': 'Negative Power Supply (-Vee)', 'desc': 'Connected to the -15V DC rail. Sets the negative saturation boundary (-Vsat ≈ -13.5V).'},
    5: {'name': 'Offset Null 2', 'desc': 'Second offset balance pin. Combined with pin 1 and potentiometer to cancel manufacturing BJT mismatches.'},
    6: {'name': 'Output (Vo)', 'desc': 'Push-pull Class AB amplifier terminal. Low output impedance (~75 Ω). Clamps flat at ±Vsat under excessive input.'},
    7: {'name': 'Positive Power Supply (+Vcc)', 'desc': 'Connected to the +15V DC rail. Sets the positive saturation boundary (+Vsat ≈ +13.5V).'},
    8: {'name': 'NC (No Connection)', 'desc': 'Unconnected pin left floating for physical package symmetry.'},
  };

  @override
  Widget build(BuildContext context) {
    final pinInfo = _pinDetails[_selectedPin]!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Interactive IC 741 DIP-8 Pinout Explorer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Tap any pin below to inspect its internal circuit function, voltage tolerance, and connection rules:', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ...[1, 2, 3, 4].map(_buildPinButton),
              const SizedBox(width: 20),
              ...[8, 7, 6, 5].map(_buildPinButton),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFFD9531E),
                  child: Text('$_selectedPin', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pin $_selectedPin: ${pinInfo['name']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                      const SizedBox(height: 4),
                      Text(pinInfo['desc']!, style: const TextStyle(fontSize: 12, color: Color(0xFFCBD5E1), height: 1.4)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinButton(int pin) {
    final isSel = _selectedPin == pin;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: InkWell(
        onTap: () => setState(() => _selectedPin = pin),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isSel ? const Color(0xFFD9531E) : const Color(0xFF334155),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: isSel ? Colors.white : Colors.transparent, width: 1.5),
          ),
          child: Text('Pin $pin', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
        ),
      ),
    );
  }
}

class ApplicationsAndResearchView extends StatelessWidget {
  const ApplicationsAndResearchView({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Container(
            color: Theme.of(context).colorScheme.surface,
            padding: const EdgeInsets.all(32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Applications & Academic Research Papers',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w400,
                    fontFamily: 'Segoe UI',
                    decoration: TextDecoration.underline,
                    decorationThickness: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'In professional engineering laboratory reports, real-world application analysis and academic literature citations are essential to connect experimental bench results with industry technology:',
                  style: TextStyle(fontSize: 15, color: Color(0xFF64748B), height: 1.5),
                ),
                const SizedBox(height: 24),

                // 4 Real-World Applications
                _buildAppCard(
                  title: '1. High-Fidelity Audio Pre-Amplifier & Active Mixer',
                  config: 'Inverting Configuration (Virtual Ground Summing Amplifier)',
                  desc: 'Because the inverting input sits at virtual ground (0V), multiple audio channel signals can be summed through independent input resistors without any cross-talk between channels. Widely utilized in professional audio mixing consoles and microphone preamplifiers.',
                  gainFormula: 'Vout = - (Rf / R1 · V1 + Rf / R2 · V2 + Rf / R3 · V3)',
                ),
                _buildAppCard(
                  title: '2. Biomedical Instrumentation Buffer (ECG / EEG / EMG)',
                  config: 'Non-Inverting Configuration (High-Z Unity Gain Buffer)',
                  desc: 'Biological skin electrodes exhibit extremely high source impedance (10 kΩ - 100 kΩ). Applying an inverting amplifier would severely load and attenuate microvolt bio-potentials. A non-inverting voltage follower provides > 10¹² Ω input impedance, transmitting undisturbed signals to subsequent ADC acquisition stages.',
                  gainFormula: 'Av = 1 + (0 / ∞) = 1.0 (Zin > 10¹² Ω)',
                ),
                _buildAppCard(
                  title: '3. Sallen-Key Active Second-Order Low-Pass Filter',
                  config: 'Non-Inverting Configuration with Frequency-Selective RC Network',
                  desc: 'Combines an active non-inverting op-amp stage with two capacitors and two resistors to realize sharp -40 dB/decade roll-off filtering for anti-aliasing in digital signal processing (DSP) front-ends.',
                  gainFormula: 'fc = 1 / (2π √(R1 R2 C1 C2))',
                ),
                _buildAppCard(
                  title: '4. Precision Optical Transimpedance Amplifier (TIA)',
                  config: 'Inverting Configuration (Current-to-Voltage Converter)',
                  desc: 'Used with photodiode detectors in optical fiber communications and LiDAR sensors. The virtual ground terminal holds the photodiode at zero bias voltage, eliminating leakage current and generating output voltage proportional to photon flux.',
                  gainFormula: 'Vout = - I_diode · Rf',
                ),

                const SizedBox(height: 28),
                const Text('Academic Literature & IEEE-Style Research References:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 14),

                _buildCitation(
                  index: 1,
                  authors: 'R. J. Widlar (National Semiconductor)',
                  title: 'Design Techniques for Monolithic Operational Amplifiers',
                  journal: 'IEEE Journal of Solid-State Circuits, vol. SC-4, no. 4, pp. 184–191, Aug. 1969.',
                  abstractText: 'Pioneered the seminal internal 3-stage architecture of monolithic bipolar op-amps, including the 30 pF internal dominant-pole compensation capacitor that made the IC 741 unconditionally stable down to unity gain.',
                ),
                _buildCitation(
                  index: 2,
                  authors: 'J. G. Graeme, G. E. Tobey, and L. P. Huelsman (Burr-Brown Research Corporation)',
                  title: 'Operational Amplifiers: Design and Applications',
                  journal: 'McGraw-Hill Electrical and Electronic Engineering Series, New York, 1971.',
                  abstractText: 'Formalized mathematical derivations of virtual ground integrity, loop gain margin, input impedance boosting under negative feedback, and finite open-loop bandwidth gain-bandwidth product trade-offs.',
                ),
                _buildCitation(
                  index: 3,
                  authors: 'A. S. Sedra and K. C. Smith',
                  title: 'Microelectronic Circuits (8th Edition)',
                  journal: 'Oxford University Press, Chapter 2: Operational Amplifiers, 2020.',
                  abstractText: 'Establishes standard engineering criteria for linear active dynamic range, output saturation clipping at ±Vsat, slew rate limiting on high-frequency sinusoidal waveforms, and offset voltage nulling.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppCard({required String title, required String config, required String desc, required String gainFormula}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B))),
          const SizedBox(height: 4),
          Text(config, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E40AF))),
          const SizedBox(height: 8),
          Text(desc, style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.5)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(3), border: Border.all(color: const Color(0xFFCBD5E1))),
            child: Text('Governing Equation: $gainFormula', style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Color(0xFFD9531E))),
          ),
        ],
      ),
    );
  }

  Widget _buildCitation({required int index, required String authors, required String title, required String journal, required String abstractText}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('[$index]', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E40AF))),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$authors, "$title," $journal', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                const SizedBox(height: 4),
                Text('Abstract Significance: $abstractText', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontStyle: FontStyle.italic, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// SECTION 7: FORMAL ENGINEERING LAB REPORT GENERATOR & PDF EXPORT
// =============================================================================

class LabReportGeneratorView extends StatefulWidget {
  final OpAmpController ctrl;
  const LabReportGeneratorView({super.key, required this.ctrl});

  @override
  State<LabReportGeneratorView> createState() => _LabReportGeneratorViewState();
}

class _LabReportGeneratorViewState extends State<LabReportGeneratorView> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _rollCtrl = TextEditingController();
  final TextEditingController _branchCtrl = TextEditingController();
  final TextEditingController _collegeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.ctrl.reportData.studentName;
    _rollCtrl.text = widget.ctrl.reportData.rollNo;
    _branchCtrl.text = widget.ctrl.reportData.branch;
    _collegeCtrl.text = widget.ctrl.reportData.college;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _rollCtrl.dispose();
    _branchCtrl.dispose();
    _collegeCtrl.dispose();
    super.dispose();
  }

  void _printOrExportPdf() {
    // Triggers browser print dialog which supports saving as clean A4 PDF
    // Alternatively, provides clipboard or downloaded HTML report
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Press Ctrl+P / Cmd+P in browser to Save as PDF, or click "Copy Report HTML".'),
        backgroundColor: Color(0xFF1E40AF),
      ),
    );
  }

  void _saveReportToPostgres() async {
    final ctrl = widget.ctrl;
    final api = PostgresApiService();

    await api.syncStudent(
      rollNo: ctrl.reportData.rollNo,
      name: ctrl.reportData.studentName,
      branch: ctrl.reportData.branch,
      college: ctrl.reportData.college,
      batch: ctrl.reportData.batch,
    );

    final success = await api.submitLabReport(
      studentRollNo: ctrl.reportData.rollNo,
      reportTitle: 'Study of Basic Properties of Operational Amplifier',
      studentMeta: {
        'name': ctrl.reportData.studentName,
        'rollNo': ctrl.reportData.rollNo,
        'branch': ctrl.reportData.branch,
        'college': ctrl.reportData.college,
        'batch': ctrl.reportData.batch,
      },
      readings: ctrl.readings.map((r) => {
        'serialNo': r.serialNo,
        'vin': r.vin,
        'r1': r.r1,
        'rf': r.rf,
        'expectedVout': r.expectedVout,
        'measuredVout': r.measuredVout,
        'errorPercent': r.errorPercent,
        'isSaturated': r.isSaturated,
      }).toList(),
      circuitStatus: ctrl.isCircuitConnected ? 'Verified & Complete' : 'Incomplete',
      conclusion: 'The closed-loop voltage gain, virtual ground principle, and saturation behavior were experimentally verified with high correlation to theoretical values.',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Lab Report successfully saved & appended to PostgreSQL database! (All readings & profile recorded)' : 'Report saved locally (PostgreSQL backend offline).'),
          backgroundColor: success ? const Color(0xFF15803D) : const Color(0xFF1E40AF),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.ctrl;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Student Information Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Student Credentials & Lab Metadata', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Wrap(
                          spacing: 8,
                          children: [
                            ElevatedButton.icon(
                              icon: const Icon(Icons.cloud_upload, size: 16),
                              label: const Text('Save to PostgreSQL'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF15803D),
                                foregroundColor: Colors.white,
                              ),
                              onPressed: _saveReportToPostgres,
                            ),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.print, size: 16),
                              label: const Text('Print / Save as PDF'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD9531E),
                                foregroundColor: Colors.white,
                              ),
                              onPressed: _printOrExportPdf,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _nameCtrl,
                            decoration: const InputDecoration(labelText: 'Student Name', isDense: true, border: OutlineInputBorder()),
                            onChanged: (v) {
                              ctrl.reportData.studentName = v;
                              PostgresApiService().syncStudent(
                                rollNo: ctrl.reportData.rollNo,
                                name: v,
                                branch: ctrl.reportData.branch,
                                college: ctrl.reportData.college,
                                batch: ctrl.reportData.batch,
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: TextField(
                            controller: _rollCtrl,
                            decoration: const InputDecoration(labelText: 'Roll Number / Registration No.', isDense: true, border: OutlineInputBorder()),
                            onChanged: (v) {
                              ctrl.reportData.rollNo = v;
                              PostgresApiService().syncStudent(
                                rollNo: v,
                                name: ctrl.reportData.studentName,
                                branch: ctrl.reportData.branch,
                                college: ctrl.reportData.college,
                                batch: ctrl.reportData.batch,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _branchCtrl,
                            decoration: const InputDecoration(labelText: 'Branch & Semester', isDense: true, border: OutlineInputBorder()),
                            onChanged: (v) => ctrl.reportData.branch = v,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: TextField(
                            controller: _collegeCtrl,
                            decoration: const InputDecoration(labelText: 'Institution / University Name', isDense: true, border: OutlineInputBorder()),
                            onChanged: (v) => ctrl.reportData.college = v,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.cloud_sync, size: 16),
                        label: const Text('Save & Update Student in Database'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E40AF),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () async {
                          final ok = await PostgresApiService().syncStudent(
                            rollNo: ctrl.reportData.rollNo,
                            name: ctrl.reportData.studentName,
                            branch: ctrl.reportData.branch,
                            college: ctrl.reportData.college,
                            batch: ctrl.reportData.batch,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(ok
                                    ? 'Student "${ctrl.reportData.studentName}" (${ctrl.reportData.rollNo}) successfully updated in PostgreSQL!'
                                    : 'Failed to update student in database. Check backend status.'),
                                backgroundColor: ok ? const Color(0xFF15803D) : const Color(0xFFDC2626),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // The Generated Engineering Lab Report Document
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Report Header
                    Center(
                      child: Column(
                        children: [
                          Text(_collegeCtrl.text.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A))),
                          const SizedBox(height: 4),
                          const Text('DEPARTMENT OF ELECTRONICS & COMMUNICATION ENGINEERING', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF475569))),
                          const SizedBox(height: 4),
                          const Text('LINEAR INTEGRATED CIRCUITS LABORATORY REPORT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFFD9531E))),
                          const Divider(thickness: 1.5, color: Color(0xFF0F172A), height: 24),
                        ],
                      ),
                    ),

                    // Metadata Box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), border: Border.all(color: const Color(0xFFE2E8F0))),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Student: ${_nameCtrl.text}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
                              Text('Roll No: ${_rollCtrl.text}', style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('Branch: ${_branchCtrl.text}', style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                              Text('Date: ${DateTime.now().toLocal().toString().split(' ')[0]}', style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                    const Text('EXPERIMENT NO. 04', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E40AF))),
                    const Text('TITLE: STUDY OF BASIC PROPERTIES OF OPERATIONAL AMPLIFIER (INVERTING & NON-INVERTING)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))),
                    const SizedBox(height: 16),

                    const Text('1. AIM:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const Text('To configure the operational amplifier IC 741 as an inverting amplifier and a non-inverting amplifier, measure closed-loop voltage gains, verify the virtual ground condition, and record saturation limits (±Vsat).', style: TextStyle(fontSize: 13, height: 1.4)),
                    const SizedBox(height: 16),

                    const Text('2. CIRCUIT DIAGRAMS & FORMULAE:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    const Text('• Inverting Amplifier Gain: Av = - (Rf / R1) with 180° phase inversion\n• Non-Inverting Amplifier Gain: Av = 1 + (Rf / R1) with 0° phase inversion\n• Saturation Limits: ±Vsat ≈ ±(Vcc - 1.5V) = ±13.5V for Vcc = ±15V', style: TextStyle(fontSize: 13, fontFamily: 'monospace', height: 1.5)),
                    const SizedBox(height: 16),

                    const Text('3. RECORDED OBSERVATION TABLE:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),

                    if (ctrl.readings.isEmpty)
                      const Text('No readings recorded in the simulation session yet. Please run the simulation, add table readings, and return here.', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Color(0xFF94A3B8)))
                    else
                      Table(
                        border: TableBorder.all(color: const Color(0xFFCBD5E1)),
                        columnWidths: const {
                          0: FlexColumnWidth(1),
                          1: FlexColumnWidth(1.5),
                          2: FlexColumnWidth(1.5),
                          3: FlexColumnWidth(1.5),
                          4: FlexColumnWidth(2),
                          5: FlexColumnWidth(2),
                          6: FlexColumnWidth(1.5),
                          7: FlexColumnWidth(2),
                        },
                        children: [
                          const TableRow(
                            decoration: BoxDecoration(color: Color(0xFFF1F5F9)),
                            children: [
                              Padding(padding: EdgeInsets.all(6), child: Text('S.N', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                              Padding(padding: EdgeInsets.all(6), child: Text('Vin (V)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                              Padding(padding: EdgeInsets.all(6), child: Text('R1 (kΩ)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                              Padding(padding: EdgeInsets.all(6), child: Text('Rf (kΩ)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                              Padding(padding: EdgeInsets.all(6), child: Text('Exp Vo (V)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                              Padding(padding: EdgeInsets.all(6), child: Text('Meas Vo (V)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                              Padding(padding: EdgeInsets.all(6), child: Text('Error %', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                              Padding(padding: EdgeInsets.all(6), child: Text('State', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                            ],
                          ),
                          ...ctrl.readings.map((r) => TableRow(
                            children: [
                              Padding(padding: const EdgeInsets.all(6), child: Text('${r.serialNo}', style: const TextStyle(fontSize: 11))),
                              Padding(padding: const EdgeInsets.all(6), child: Text(r.vin.toStringAsFixed(1), style: const TextStyle(fontSize: 11))),
                              Padding(padding: const EdgeInsets.all(6), child: Text((r.r1 / 1000).toStringAsFixed(1), style: const TextStyle(fontSize: 11))),
                              Padding(padding: const EdgeInsets.all(6), child: Text((r.rf / 1000).toStringAsFixed(1), style: const TextStyle(fontSize: 11))),
                              Padding(padding: const EdgeInsets.all(6), child: Text(r.expectedVout.toStringAsFixed(2), style: const TextStyle(fontSize: 11))),
                              Padding(padding: const EdgeInsets.all(6), child: Text(r.measuredVout.toStringAsFixed(2), style: const TextStyle(fontSize: 11))),
                              Padding(padding: const EdgeInsets.all(6), child: Text('${r.errorPercent.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 11))),
                              Padding(padding: const EdgeInsets.all(6), child: Text(r.isSaturated ? 'Saturated' : 'Linear', style: const TextStyle(fontSize: 11))),
                            ],
                          )),
                        ],
                      ),

                    const SizedBox(height: 18),
                    const Text('4. SAMPLE CALCULATIONS:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(
                      '• For R1 = ${(ctrl.r1 / 1000).toStringAsFixed(1)} kΩ and Rf = ${(ctrl.rf / 1000).toStringAsFixed(1)} kΩ:\n'
                      '  Calculated Closed Loop Gain Av = ${ctrl.theoreticalGain.toStringAsFixed(2)}\n'
                      '  For Vin = ${ctrl.vin.toStringAsFixed(1)} V: Expected Output Vo = (${ctrl.theoreticalGain.toStringAsFixed(2)}) × (${ctrl.vin.toStringAsFixed(1)}) = ${ctrl.expectedOutputVoltage.toStringAsFixed(2)} V\n'
                      '  Measured Output Vo = ${ctrl.outputVoltage.toStringAsFixed(2)} V (Clipped at ±Vsat if |Vo| > 13.5V)',
                      style: const TextStyle(fontSize: 12, height: 1.5, fontFamily: 'monospace'),
                    ),

                    const SizedBox(height: 18),
                    const Text('5. RESULTS & CONCLUSION:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    const Text(
                      '1. The inverting and non-inverting operational amplifier configurations were successfully simulated and analyzed.\n'
                      '2. In inverting mode, the output exhibited exact 180° phase inversion and verified Av = - (Rf / R1).\n'
                      '3. In non-inverting mode, the output remained in-phase with the input and verified Av = 1 + (Rf / R1).\n'
                      '4. Virtual ground condition (Vdiff ≈ 0V) held true throughout the linear active region.\n'
                      '5. Output saturation occurred predictably at ±13.5V when the input amplitude exceeded the dynamic headroom of the DC supply rails (±15V).',
                      style: TextStyle(fontSize: 13, height: 1.5),
                    ),

                    const SizedBox(height: 40),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('Student Signature', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        Text('Faculty Evaluator Signature & Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// SECTION 8: PRIMARY SIMULATION VIEW & NAVIGATION SHELL
// =============================================================================

class SimulationView extends StatefulWidget {
  final OpAmpController ctrl;
  final bool isDark;
  const SimulationView({super.key, required this.ctrl, required this.isDark});

  @override
  State<SimulationView> createState() => _SimulationViewState();
}

class _SimulationViewState extends State<SimulationView> {
  final TextEditingController _r1Ctrl = TextEditingController();
  final TextEditingController _rfCtrl = TextEditingController();
  final TextEditingController _vinCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _r1Ctrl.text = (widget.ctrl.r1 / 1000).toStringAsFixed(1);
    _rfCtrl.text = (widget.ctrl.rf / 1000).toStringAsFixed(1);
    _vinCtrl.text = widget.ctrl.vin.toStringAsFixed(1);
  }

  @override
  void dispose() {
    _r1Ctrl.dispose();
    _rfCtrl.dispose();
    _vinCtrl.dispose();
    super.dispose();
  }

  void _syncControllers() {
    _r1Ctrl.text = (widget.ctrl.r1 / 1000).toStringAsFixed(1);
    _rfCtrl.text = (widget.ctrl.rf / 1000).toStringAsFixed(1);
    _vinCtrl.text = widget.ctrl.vin.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.ctrl;

    return ListenableBuilder(
      listenable: ctrl,
      builder: (context, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1040),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildToolbar(ctrl),
                  const SizedBox(height: 12),
                  RealisticWorkbenchCanvas(ctrl: ctrl, isDark: widget.isDark),
                  const SizedBox(height: 14),
                  _buildControls(ctrl),
                  const SizedBox(height: 14),
                  if (ctrl.showTransferPlot) ...[
                    EngineeringPlotterWidget(ctrl: ctrl, isDark: widget.isDark),
                    const SizedBox(height: 14),
                  ],
                  _buildObservationTable(ctrl),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildToolbar(OpAmpController ctrl) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          SegmentedButton<OpAmpMode>(
            segments: const [
              ButtonSegment(value: OpAmpMode.inverting, label: Text('Inverting')),
              ButtonSegment(value: OpAmpMode.nonInverting, label: Text('Non-Inverting')),
            ],
            selected: {ctrl.mode},
            onSelectionChanged: (val) {
              ctrl.setMode(val.first);
              _syncControllers();
            },
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.verified, size: 15),
                label: const Text('Check Connection'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E40AF), foregroundColor: Colors.white, elevation: 0),
                onPressed: () {
                  final isDone = ctrl.isCircuitConnected;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isDone ? 'Circuit verified! All connections correct.' : 'Incomplete connections. Use "Show Expected" or "Auto Wire".'),
                      backgroundColor: isDone ? const Color(0xFF15803D) : const Color(0xFFD97706),
                    ),
                  );
                },
              ),
              OutlinedButton.icon(
                icon: Icon(ctrl.showExpectedOverlay ? Icons.visibility_off : Icons.visibility, size: 15),
                label: Text(ctrl.showExpectedOverlay ? 'Hide Guide' : 'Show Expected'),
                onPressed: ctrl.toggleExpectedOverlay,
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.auto_fix_high, size: 15),
                label: const Text('Auto Wire'),
                onPressed: ctrl.autoWireCircuit,
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.restart_alt, size: 15),
                label: const Text('Reset Layout'),
                onPressed: ctrl.resetComponentLayout,
              ),
              TextButton.icon(
                icon: const Icon(Icons.delete_sweep, size: 15, color: Color(0xFFDC2626)),
                label: const Text('Clear', style: TextStyle(color: Color(0xFFDC2626))),
                onPressed: ctrl.clearWires,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControls(OpAmpController ctrl) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Circuit Parameters & Signal Controls', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Wire Color: ', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ...[const Color(0xFFDC2626), const Color(0xFF1E293B), const Color(0xFF2563EB), const Color(0xFF16A34A), const Color(0xFFD97706)].map((c) {
                    final isSel = ctrl.selectedWireColor == c;
                    return InkWell(
                      onTap: () => ctrl.setWireColor(c),
                      child: Container(
                        margin: const EdgeInsets.only(left: 6),
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(color: isSel ? Colors.amber : Colors.white, width: isSel ? 2 : 1),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 520;
              final pR1 = _buildParamInput('R1 (1 - 50 kΩ):', _r1Ctrl, (v) {
                final n = double.tryParse(v);
                if (n != null) ctrl.setR1(n * 1000);
              });
              final pRf = _buildParamInput('Rf (2 - 100 kΩ):', _rfCtrl, (v) {
                final n = double.tryParse(v);
                if (n != null) ctrl.setRf(n * 1000);
              });
              final pVin = _buildParamInput('Vin (-15 to 15 V):', _vinCtrl, (v) {
                final n = double.tryParse(v);
                if (n != null) ctrl.setVin(n);
              });
              final pVo = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Output Vo (Measured):', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(4)),
                    child: Text(
                      ctrl.isCircuitConnected ? '${ctrl.outputVoltage.toStringAsFixed(2)} V' : '--.-- V',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: !ctrl.isCircuitConnected
                            ? const Color(0xFF64748B)
                            : (ctrl.isSaturated ? const Color(0xFFEF4444) : const Color(0xFF38BDF8)),
                      ),
                    ),
                  ),
                ],
              );

              if (isNarrow) {
                return Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(child: pR1),
                        const SizedBox(width: 10),
                        Expanded(child: pRf),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(child: pVin),
                        const SizedBox(width: 10),
                        Expanded(child: pVo),
                      ],
                    ),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: pR1),
                  const SizedBox(width: 10),
                  Expanded(child: pRf),
                  const SizedBox(width: 10),
                  Expanded(child: pVin),
                  const SizedBox(width: 10),
                  Expanded(child: pVo),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.add_chart, size: 15),
                label: const Text('Add to table'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF15803D), foregroundColor: Colors.white, elevation: 0),
                onPressed: () {
                  if (!ctrl.isCircuitConnected) {
                    ctrl.autoWireCircuit();
                  }
                  ctrl.addReadingToTable();
                  if (ctrl.readings.isNotEmpty) {
                    final r = ctrl.readings.last;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Reading #${r.serialNo} added to Observation Table (${r.vin}V -> ${r.measuredVout.toStringAsFixed(2)}V). Will be permanently stored in PostgreSQL when you Save Report.'),
                        backgroundColor: const Color(0xFF15803D),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.exposure_plus_2, size: 15),
                label: const Text('Vin × 2'),
                onPressed: () {
                  ctrl.multiplyVinByTwo();
                  _vinCtrl.text = ctrl.vin.toStringAsFixed(1);
                },
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.exposure_neg_2, size: 15),
                label: const Text('Vin / 2'),
                onPressed: () {
                  ctrl.divideVinByTwo();
                  _vinCtrl.text = ctrl.vin.toStringAsFixed(1);
                },
              ),
              if (ctrl.readings.isNotEmpty)
                OutlinedButton.icon(
                  icon: const Icon(Icons.copy, size: 15),
                  label: const Text('Copy CSV'),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: ctrl.generateCsv()));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied observation table CSV!')));
                  },
                ),
              if (ctrl.readings.isNotEmpty)
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline, size: 15, color: Color(0xFFDC2626)),
                  label: const Text('Clear', style: TextStyle(color: Color(0xFFDC2626))),
                  onPressed: ctrl.clearTable,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildParamInput(String label, TextEditingController controller, ValueChanged<String> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        SizedBox(
          height: 40,
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
            decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10)),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildObservationTable(OpAmpController ctrl) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Observation Table', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text('${ctrl.readings.length} readings', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
            ],
          ),
          const SizedBox(height: 8),
          if (ctrl.readings.isEmpty)
            Container(
              height: 60,
              alignment: Alignment.center,
              child: const Text('No readings logged yet. Wire the circuit, set Vin, and click "Add to table".', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontStyle: FontStyle.italic)),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
                dataRowMinHeight: 34,
                dataRowMaxHeight: 36,
                columns: const [
                  DataColumn(label: Text('S.No', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                  DataColumn(label: Text('Vin (V)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                  DataColumn(label: Text('R1 (kΩ)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                  DataColumn(label: Text('Rf (kΩ)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                  DataColumn(label: Text('Expected Vo (V)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                  DataColumn(label: Text('Measured Vo (V)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                  DataColumn(label: Text('Error %', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                  DataColumn(label: Text('State', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                ],
                rows: ctrl.readings.map((r) => DataRow(
                  cells: [
                    DataCell(Text('${r.serialNo}', style: const TextStyle(fontSize: 11))),
                    DataCell(Text(r.vin.toStringAsFixed(1), style: const TextStyle(fontSize: 11))),
                    DataCell(Text((r.r1 / 1000).toStringAsFixed(1), style: const TextStyle(fontSize: 11))),
                    DataCell(Text((r.rf / 1000).toStringAsFixed(1), style: const TextStyle(fontSize: 11))),
                    DataCell(Text(r.expectedVout.toStringAsFixed(2), style: const TextStyle(fontSize: 11))),
                    DataCell(Text(r.measuredVout.toStringAsFixed(2), style: const TextStyle(fontSize: 11))),
                    DataCell(Text('${r.errorPercent.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 11))),
                    DataCell(Text(r.isSaturated ? 'Saturated' : 'Linear', style: TextStyle(fontSize: 11, color: r.isSaturated ? const Color(0xFFDC2626) : const Color(0xFF15803D), fontWeight: FontWeight.bold))),
                  ],
                )).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// SECTION 9: SHELL WITH PUSH/PULL SIDEBAR, DAY/NIGHT & APK LINK
// =============================================================================

class LabPortalShell extends StatefulWidget {
  final ThemeMode themeMode;
  final VoidCallback onToggleTheme;

  const LabPortalShell({
    super.key,
    required this.themeMode,
    required this.onToggleTheme,
  });

  @override
  State<LabPortalShell> createState() => _LabPortalShellState();
}

class _LabPortalShellState extends State<LabPortalShell> {
  int _activeNavIndex = 5; // Default to Simulation
  final OpAmpController _ctrl = OpAmpController();

  final List<Map<String, dynamic>> _navItems = const [
    {'title': 'Aim', 'icon': Icons.track_changes},
    {'title': 'Objective', 'icon': Icons.checklist},
    {'title': 'Pretest', 'icon': Icons.assignment_outlined},
    {'title': 'Theory', 'icon': Icons.menu_book},
    {'title': 'Procedure', 'icon': Icons.format_list_numbered},
    {'title': 'Simulation with Graph', 'icon': Icons.precision_manufacturing},
    {'title': 'Applications & Research', 'icon': Icons.science_outlined},
    {'title': 'Generate Lab Report', 'icon': Icons.picture_as_pdf_outlined},
    {'title': 'Posttest', 'icon': Icons.quiz_outlined},
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.themeMode == ThemeMode.dark;
    final isMobile = MediaQuery.of(context).size.width < 768;

    return ListenableBuilder(
      listenable: _ctrl,
      builder: (context, _) {
        return Scaffold(
          drawer: isMobile ? _buildMobileDrawer(isDark) : null,
          body: Column(
            children: [
              _buildHeader(isDark, isMobile),
              Expanded(
                child: Row(
                  children: [
                    if (!isMobile && !_ctrl.isSidebarCollapsed) _buildDesktopSidebar(isDark),
                    Expanded(
                      child: Container(
                        color: isDark ? const Color(0xFF0B1120) : const Color(0xFFF4F6F9),
                        child: _buildActiveView(isDark),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool isDark, bool isMobile) {
    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          if (isMobile)
            Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            )
          else
            IconButton(
              icon: Icon(_ctrl.isSidebarCollapsed ? Icons.menu_open : Icons.menu),
              tooltip: _ctrl.isSidebarCollapsed ? 'Expand Sidebar (Pull)' : 'Collapse Sidebar (Push)',
              onPressed: _ctrl.toggleSidebar,
            ),
          const SizedBox(width: 8),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFFD9531E), borderRadius: BorderRadius.circular(3)),
            child: const Text('VLABS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2)),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Study of Basic Properties of Operational Amplifier',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 12 : 13, color: isDark ? Colors.white : const Color(0xFF1E293B)),
                  overflow: TextOverflow.ellipsis,
                ),
                if (!isMobile)
                  const Text('Linear Integrated Circuits Virtual Laboratory', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
              ],
            ),
          ),

          // PostgreSQL Database Status & Settings Button
          IconButton(
            icon: const Icon(Icons.storage, size: 20, color: Color(0xFF38BDF8)),
            tooltip: 'PostgreSQL Database Settings & Sync',
            onPressed: () => _showPostgreSqlDialog(context, isDark),
          ),
          const SizedBox(width: 6),

          // Direct Download APK Button
          OutlinedButton.icon(
            icon: const Icon(Icons.android, size: 16, color: Color(0xFF10B981)),
            label: Text(isMobile ? 'APK' : 'Download APK', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
            onPressed: () => _showApkDownloadDialog(context, isDark),
          ),
          const SizedBox(width: 8),

          // Day / Night Theme Mode Toggle
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode, color: isDark ? const Color(0xFFFBBF24) : const Color(0xFF1E293B)),
            tooltip: isDark ? 'Switch to Day Mode' : 'Switch to Night Mode',
            onPressed: widget.onToggleTheme,
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopSidebar(bool isDark) {
    return Material(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: Container(
        width: 240,
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
        ),
        child: ListView.separated(
          itemCount: _navItems.length,
          separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
          itemBuilder: (context, idx) {
            final item = _navItems[idx];
            final isSelected = _activeNavIndex == idx;

            return ListTile(
              dense: true,
              selected: isSelected,
              selectedTileColor: isDark ? const Color(0xFF334155) : const Color(0xFFFFF7ED),
              leading: Icon(
                item['icon'] as IconData,
                size: 18,
                color: isSelected ? const Color(0xFFD9531E) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
              title: Text(
                item['title'] as String,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? const Color(0xFFD9531E) : (isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155)),
                ),
              ),
              trailing: isSelected ? Container(width: 3, height: 18, color: const Color(0xFFD9531E)) : null,
              onTap: () => setState(() => _activeNavIndex = idx),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMobileDrawer(bool isDark) {
    return Drawer(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: ListView(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFFD9531E)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Text('VIRTUAL LABS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                SizedBox(height: 6),
                Text('Op-Amp Properties & Simulation', style: TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
          ...List.generate(_navItems.length, (idx) {
            final item = _navItems[idx];
            final isSelected = _activeNavIndex == idx;
            return ListTile(
              leading: Icon(item['icon'] as IconData, color: isSelected ? const Color(0xFFD9531E) : null),
              title: Text(item['title'] as String, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
              onTap: () {
                Navigator.pop(context);
                setState(() => _activeNavIndex = idx);
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _buildActiveView(bool isDark) {
    switch (_activeNavIndex) {
      case 0:
        return const AimView();
      case 1:
        return const ObjectiveView();
      case 2:
        return PretestView(ctrl: _ctrl);
      case 3:
        return TheoryView(ctrl: _ctrl);
      case 4:
        return const ProcedureView();
      case 5:
        return SimulationView(ctrl: _ctrl, isDark: isDark);
      case 6:
        return const ApplicationsAndResearchView();
      case 7:
        return LabReportGeneratorView(ctrl: _ctrl);
      case 8:
        return PosttestView(ctrl: _ctrl);
      default:
        return SimulationView(ctrl: _ctrl, isDark: isDark);
    }
  }

  void _showApkDownloadDialog(BuildContext context, bool isDark) {
    const String apkDownloadUrl = 'https://github.com/SrijanRegmi011/opamp_simulator/releases/latest/download/app-release.apk';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Row(
          children: const [
            Icon(Icons.android, color: Color(0xFF10B981), size: 28),
            SizedBox(width: 10),
            Text('Android APK Download', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.check_circle, color: Color(0xFF15803D), size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Virtual Lab Mobile App v1.0.0 (Release Build)',
                        style: TextStyle(color: Color(0xFF15803D), fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('Direct APK Download URL:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 4),
              SelectableText(
                apkDownloadUrl,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Color(0xFF1E40AF)),
              ),
              const SizedBox(height: 16),
              const Text('Installation Steps on Android:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              const Text('1. Tap "Copy APK Link" or open the link directly on your Android phone.'),
              const Text('2. Once downloaded, tap the notification or file in Downloads.'),
              const Text('3. If prompted by Android, allow "Install Unknown Apps" or tap "Install Anyway".'),
              const Text('4. Open "Op-Amp Virtual Lab" and begin your experiments!'),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.terminal, size: 16, color: Color(0xFF64748B)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Local CLI Build: flutter build apk --release',
                        style: TextStyle(fontFamily: 'monospace', fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy APK Link'),
            onPressed: () {
              Clipboard.setData(const ClipboardData(text: apkDownloadUrl));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('APK download link copied to clipboard!'),
                  backgroundColor: Color(0xFF10B981),
                ),
              );
            },
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.download, size: 16),
            label: const Text('Download APK'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
            onPressed: () {
              Clipboard.setData(const ClipboardData(text: apkDownloadUrl));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Starting APK Download / Link copied to clipboard!'),
                  backgroundColor: Color(0xFF10B981),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showPostgreSqlDialog(BuildContext context, bool isDark) {
    final api = PostgresApiService();
    final urlCtrl = TextEditingController(text: api.baseUrl);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            title: Row(
              children: const [
                Icon(Icons.storage, color: Color(0xFF38BDF8), size: 26),
                SizedBox(width: 10),
                Text('PostgreSQL Backend Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Backend Server & Database Configuration:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: urlCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Dart + PostgreSQL REST API URL',
                      helperText: 'Mobile on Wi-Fi: http://192.168.0.100:8080 | PC: http://localhost:8080',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.wifi, size: 14),
                        label: const Text('Set PC Wi-Fi IP (192.168.0.100)', style: TextStyle(fontSize: 11)),
                        onPressed: () {
                          setDialogState(() {
                            urlCtrl.text = 'http://192.168.0.100:8080';
                          });
                        },
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.computer, size: 14),
                        label: const Text('Set Localhost (8080)', style: TextStyle(fontSize: 11)),
                        onPressed: () {
                          setDialogState(() {
                            urlCtrl.text = 'http://localhost:8080';
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('PostgreSQL Database Schema:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        SizedBox(height: 4),
                        Text('• Database: opamp_vlab (PostgreSQL 16 Alpine)', style: TextStyle(fontSize: 11)),
                        Text('• Tables: students, experiment_readings, circuit_verifications, quiz_submissions, lab_reports', style: TextStyle(fontSize: 11)),
                        Text('• Quick Start: docker compose -f backend/docker-compose.yml up -d', style: TextStyle(fontSize: 11, fontFamily: 'monospace')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Test Connection'),
                onPressed: () async {
                  api.setBaseUrl(urlCtrl.text.trim());
                  final ok = await api.checkHealth();
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(ok ? 'Connected successfully to PostgreSQL backend!' : 'Backend unreachable at ${urlCtrl.text}. Local fallback active.'),
                        backgroundColor: ok ? const Color(0xFF15803D) : const Color(0xFFDC2626),
                      ),
                    );
                  }
                },
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E40AF), foregroundColor: Colors.white),
                onPressed: () {
                  api.setBaseUrl(urlCtrl.text.trim());
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('PostgreSQL backend URL set to: ${api.baseUrl}')),
                  );
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }
}

// =============================================================================
// CURRICULUM VIEWS: AIM, OBJECTIVE, PRETEST, THEORY, PROCEDURE, POSTTEST
// =============================================================================

class AimView extends StatelessWidget {
  const AimView({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Container(
            color: Theme.of(context).colorScheme.surface,
            padding: const EdgeInsets.all(32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Aim of the Experiment', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w400, decoration: TextDecoration.underline, decorationThickness: 1.5)),
                SizedBox(height: 20),
                Text(
                  'To experimentally investigate and verify the fundamental operational properties of the integrated circuit operational amplifier (IC 741), configuring it as:\n\n'
                  '1. Inverting Amplifier: Verify closed-loop voltage gain Av = - (Rf / R1) and observe 180° phase inversion.\n\n'
                  '2. Non-Inverting Amplifier: Verify closed-loop voltage gain Av = 1 + (Rf / R1) and observe 0° phase shift.\n\n'
                  '3. Transfer Characteristics: Plot Vout vs Vin to delineate the linear active region and identify positive and negative saturation limits (±Vsat).',
                  style: TextStyle(fontSize: 15, height: 1.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ObjectiveView extends StatefulWidget {
  const ObjectiveView({super.key});

  @override
  State<ObjectiveView> createState() => _ObjectiveViewState();
}

class _ObjectiveViewState extends State<ObjectiveView> {
  final Map<int, bool> _completed = {};

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Container(
            color: Theme.of(context).colorScheme.surface,
            padding: const EdgeInsets.all(32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Learning Objectives', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w400, decoration: TextDecoration.underline, decorationThickness: 1.5)),
                const SizedBox(height: 20),
                const Text('Students can check off competency milestones as they master each phase of the lab:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                const SizedBox(height: 20),
                _buildItem(1, 'Identify the pin configuration and internal architecture of IC 741 (pins 2, 3, 4, 6, 7).'),
                _buildItem(2, 'Wire the inverting amplifier circuit and experimentally verify Av = - (Rf / R1).'),
                _buildItem(3, 'Wire the non-inverting amplifier circuit and experimentally verify Av = 1 + (Rf / R1).'),
                _buildItem(4, 'Demonstrate the concept of Virtual Ground at the inverting terminal during negative feedback.'),
                _buildItem(5, 'Plot transfer characteristics and identify the linear active region and saturation plateaus (±Vsat).'),
                _buildItem(6, 'Observe 180° phase inversion versus 0° phase shift on an animated dual-trace oscilloscope.'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItem(int idx, String text) {
    final isChecked = _completed[idx] ?? false;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: InkWell(
        onTap: () => setState(() => _completed[idx] = !isChecked),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(value: isChecked, activeColor: const Color(0xFFD9531E), onChanged: (val) => setState(() => _completed[idx] = val ?? false)),
            const SizedBox(width: 8),
            Expanded(child: Text('$idx. $text', style: TextStyle(fontSize: 14, height: 1.5, decoration: isChecked ? TextDecoration.lineThrough : null))),
          ],
        ),
      ),
    );
  }
}

class PretestView extends StatefulWidget {
  final OpAmpController ctrl;
  const PretestView({super.key, required this.ctrl});

  @override
  State<PretestView> createState() => _PretestViewState();
}

class _PretestViewState extends State<PretestView> {
  final Map<int, int?> _answers = {};
  bool _isSubmitted = false;

  int get _score => widget.ctrl.pretestList.where((q) => _answers[q.id] == q.correctIndex).length;

  @override
  Widget build(BuildContext context) {
    final questions = widget.ctrl.pretestList;
    final total = questions.length;
    final score = _score;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Container(
            color: Theme.of(context).colorScheme.surface,
            padding: const EdgeInsets.all(32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Pretest', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w400, decoration: TextDecoration.underline, decorationThickness: 1.5)),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.shuffle, size: 16),
                      label: const Text('New Random Questions'),
                      onPressed: () {
                        widget.ctrl.shufflePretest();
                        setState(() {
                          _answers.clear();
                          _isSubmitted = false;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Fresh conceptual & parametric calculation questions are generated every attempt to assess your knowledge:', style: TextStyle(fontSize: 14, color: Color(0xFF64748B))),
                const SizedBox(height: 20),

                if (_isSubmitted)
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: score >= 7 ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                      border: Border.all(color: score >= 7 ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('Score: $score / $total (${((score / total) * 100).toInt()}%) - ${score >= 9 ? "Distinction" : (score >= 6 ? "Passed" : "Review Recommended")}',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: score >= 7 ? const Color(0xFF15803D) : const Color(0xFFB45309)),
                    ),
                  ),

                ...questions.map(_buildCard),

                const SizedBox(height: 16),
                if (!_isSubmitted)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E40AF), foregroundColor: Colors.white),
                    onPressed: () {
                      setState(() => _isSubmitted = true);
                      PostgresApiService().submitQuiz(
                        studentRollNo: widget.ctrl.reportData.rollNo,
                        quizType: 'pretest',
                        answers: _answers,
                      );
                    },
                    child: const Text('Submit Pretest'),
                  )
                else
                  OutlinedButton(
                    onPressed: () {
                      widget.ctrl.shufflePretest();
                      setState(() {
                        _answers.clear();
                        _isSubmitted = false;
                      });
                    },
                    child: const Text('Try New Questions'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(QuizQuestion q) {
    final selected = _answers[q.id];
    final isCorrect = _isSubmitted && selected == q.correctIndex;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _isSubmitted ? (isCorrect ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5)) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Q${q.id}. ${q.question}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
          const SizedBox(height: 10),
          ...List.generate(q.options.length, (optIdx) => RadioListTile<int>(
            dense: true,
            value: optIdx,
            groupValue: selected,
            title: Text(q.options[optIdx], style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155))),
            onChanged: _isSubmitted ? null : (v) => setState(() => _answers[q.id] = v),
          )),
          if (_isSubmitted)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFCBD5E1))),
              child: Text('Explanation: ${q.explanation}', style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569), fontStyle: FontStyle.italic)),
            ),
        ],
      ),
    );
  }
}

class TheoryView extends StatelessWidget {
  final OpAmpController ctrl;
  const TheoryView({super.key, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Container(
            color: Theme.of(context).colorScheme.surface,
            padding: const EdgeInsets.all(32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Theory & Integrated Circuit Architecture', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w400, decoration: TextDecoration.underline, decorationThickness: 1.5)),
                const SizedBox(height: 18),
                const Text(
                  'The Operational Amplifier (Op-Amp) is a direct-coupled, high-gain differential voltage amplifier featuring high input impedance, low output impedance, and wide bandwidth stabilized via external negative feedback networks.',
                  style: TextStyle(fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 20),
                InteractiveTheoryExplorer(ctrl: ctrl),
                const SizedBox(height: 24),
                const Text('Internal Architecture Stages:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
                  child: Row(
                    children: const [
                      Expanded(child: Text('1. Differential Input Stage\n(Dual input, high CMRR, active current mirror)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                      Icon(Icons.arrow_forward, size: 16),
                      Expanded(child: Text('2. Intermediate Gain Stage\n(High-gain level shifter & 30pF Miller capacitor)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                      Icon(Icons.arrow_forward, size: 16),
                      Expanded(child: Text('3. Push-Pull Output Stage\n(Class AB complementary, low Rout ≈ 75 Ω)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ProcedureView extends StatelessWidget {
  const ProcedureView({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Container(
            color: Theme.of(context).colorScheme.surface,
            padding: const EdgeInsets.all(32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Laboratory Procedure', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w400, decoration: TextDecoration.underline, decorationThickness: 1.5)),
                const SizedBox(height: 18),
                _buildStep(1, 'Select Configuration', 'Choose Inverting or Non-Inverting mode using the selector.'),
                _buildStep(2, 'Drag Components on Workbench', 'Reposition IC 741, Resistors R1 & Rf, DC Source, and DMM on the canvas as desired.'),
                _buildStep(3, 'Wire Circuit (Click & Drag)', 'Connect terminals using realistic patch cords. Use "Show Expected" for guidance or "Auto Wire".'),
                _buildStep(4, 'Verify Netlist Connectivity', 'Click "Check Connection" to confirm all power and signal loops are closed.'),
                _buildStep(5, 'Tune Parameters & Log Readings', 'Adjust R1, Rf, and Vin. Click "Add to table" to record data.'),
                _buildStep(6, 'Observe Waveform Dynamics', 'Watch the live streaming waveform on the dual-trace oscilloscope and observe saturation clipping.'),
                _buildStep(7, 'Generate & Download Lab Report', 'Navigate to "Generate Lab Report", enter your student credentials, and print/download the report as PDF.'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep(int num, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(radius: 12, backgroundColor: const Color(0xFF1E40AF), child: Text('$num', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 2),
                Text(desc, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PosttestView extends StatefulWidget {
  final OpAmpController ctrl;
  const PosttestView({super.key, required this.ctrl});

  @override
  State<PosttestView> createState() => _PosttestViewState();
}

class _PosttestViewState extends State<PosttestView> {
  final Map<int, int?> _answers = {};
  bool _isSubmitted = false;

  int get _score => widget.ctrl.posttestList.where((q) => _answers[q.id] == q.correctIndex).length;

  @override
  Widget build(BuildContext context) {
    final questions = widget.ctrl.posttestList;
    final total = questions.length;
    final score = _score;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Container(
            color: Theme.of(context).colorScheme.surface,
            padding: const EdgeInsets.all(32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Posttest', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w400, decoration: TextDecoration.underline, decorationThickness: 1.5)),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.shuffle, size: 16),
                      label: const Text('New Random Questions'),
                      onPressed: () {
                        widget.ctrl.shufflePosttest();
                        setState(() {
                          _answers.clear();
                          _isSubmitted = false;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Dynamic post-lab analytical and calculation questions generated to test your comprehension:', style: TextStyle(fontSize: 14, color: Color(0xFF64748B))),
                const SizedBox(height: 20),

                if (_isSubmitted)
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: score >= 7 ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                      border: Border.all(color: score >= 7 ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('Score: $score / $total (${((score / total) * 100).toInt()}%) - ${score >= 9 ? "Distinction" : (score >= 6 ? "Passed" : "Review Recommended")}',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: score >= 7 ? const Color(0xFF15803D) : const Color(0xFFB45309)),
                    ),
                  ),

                ...questions.map(_buildCard),

                const SizedBox(height: 16),
                if (!_isSubmitted)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E40AF), foregroundColor: Colors.white),
                    onPressed: () {
                      setState(() => _isSubmitted = true);
                      PostgresApiService().submitQuiz(
                        studentRollNo: widget.ctrl.reportData.rollNo,
                        quizType: 'posttest',
                        answers: _answers,
                      );
                    },
                    child: const Text('Submit Posttest'),
                  )
                else
                  OutlinedButton(
                    onPressed: () {
                      widget.ctrl.shufflePosttest();
                      setState(() {
                        _answers.clear();
                        _isSubmitted = false;
                      });
                    },
                    child: const Text('Try New Questions'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(QuizQuestion q) {
    final selected = _answers[q.id];
    final isCorrect = _isSubmitted && selected == q.correctIndex;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _isSubmitted ? (isCorrect ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5)) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Q${q.id}. ${q.question}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
          const SizedBox(height: 10),
          ...List.generate(q.options.length, (optIdx) => RadioListTile<int>(
            dense: true,
            value: optIdx,
            groupValue: selected,
            title: Text(q.options[optIdx], style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155))),
            onChanged: _isSubmitted ? null : (v) => setState(() => _answers[q.id] = v),
          )),
          if (_isSubmitted)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFCBD5E1))),
              child: Text('Explanation: ${q.explanation}', style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569), fontStyle: FontStyle.italic)),
            ),
        ],
      ),
    );
  }
}
