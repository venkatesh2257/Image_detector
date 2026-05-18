import 'package:flutter/foundation.dart';

/// Centralized console logs for ML pipeline proof (TFLite vs rules).
class InferenceLogger {
  static int _sessionCounter = 0;
  static String? _activeSessionId;
  static final List<String> _sessionLines = [];

  static String startSession(String trigger) {
    _sessionCounter++;
    _activeSessionId =
        'INF-${DateTime.now().millisecondsSinceEpoch}-$_sessionCounter';
    _sessionLines.clear();
    banner('NEW INFERENCE SESSION', _activeSessionId!);
    log('SESSION', 'Trigger: $trigger');
    return _activeSessionId!;
  }

  static String? get activeSessionId => _activeSessionId;

  static List<String> sessionLogSnapshot() => List.unmodifiable(_sessionLines);

  static void log(String tag, String message) {
    final line = '[$tag] $message';
    _sessionLines.add(line);
    debugPrint('🔬 $line');
  }

  static void banner(String title, [String? subtitle]) {
    const width = 58;
    final top = '═' * width;
    debugPrint('🔬 ╔$top╗');
    debugPrint('🔬 ║ ${title.padRight(width - 2)} ║');
    if (subtitle != null) {
      debugPrint('🔬 ║ ${subtitle.padRight(width - 2)} ║');
    }
    debugPrint('🔬 ╚$top╝');
    _sessionLines.add('=== $title ${subtitle ?? ''} ===');
  }

  static void proof(String check, bool passed, {String? detail}) {
    final icon = passed ? '✅' : '❌';
    final status = passed ? 'PASS' : 'FAIL';
    log('PROOF', '$icon $check → $status${detail != null ? ' | $detail' : ''}');
  }

  static void scores(String title, Map<String, double> values) {
    log('SCORES', title);
    final sorted = values.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final e in sorted) {
      final pct = (e.value * 100).toStringAsFixed(2);
      log('SCORES', '  ${e.key.padRight(12)} $pct%');
    }
  }

  static void endSession(String outcome) {
    log('SESSION', 'Finished → $outcome');
    banner('SESSION END', _activeSessionId);
    _activeSessionId = null;
  }
}

/// Proof metadata returned to UI + console summary.
class InferenceDiagnostics {
  final String sessionId;
  final bool tfliteModelLoaded;
  final bool tfliteInterpreterAllocated;
  final bool rulesGateRan;
  final bool rulesGatePassed;
  final bool tfliteInferenceExecuted;
  final String predictionSource;
  final String? rulesRejectReason;
  final String tfliteModelAsset;
  final List<String> labelClasses;
  final List<int> inputTensorShape;
  final List<int> outputTensorShape;
  final String rawTfliteLabel;
  final double tfliteConfidence;
  final Map<String, double> tfliteAllScores;
  final int tfliteLoadMs;
  final int tfliteInferenceMs;
  final int rulesGateMs;
  final List<String> logLines;

  const InferenceDiagnostics({
    required this.sessionId,
    required this.tfliteModelLoaded,
    required this.tfliteInterpreterAllocated,
    required this.rulesGateRan,
    required this.rulesGatePassed,
    required this.tfliteInferenceExecuted,
    required this.predictionSource,
    this.rulesRejectReason,
    required this.tfliteModelAsset,
    required this.labelClasses,
    required this.inputTensorShape,
    required this.outputTensorShape,
    required this.rawTfliteLabel,
    required this.tfliteConfidence,
    required this.tfliteAllScores,
    required this.tfliteLoadMs,
    required this.tfliteInferenceMs,
    required this.rulesGateMs,
    required this.logLines,
  });

  String get proofSummary {
    final parts = <String>[
      'TFLite loaded: $tfliteModelLoaded',
      'Interpreter: $tfliteInterpreterAllocated',
      'Rules gate: ${rulesGatePassed ? "PASS" : "FAIL"}',
      'interpreter.run(): $tfliteInferenceExecuted',
      'Predicted by: $predictionSource',
    ];
    return parts.join(' | ');
  }

  void printFullReport() {
    InferenceLogger.banner('INFERENCE PROOF REPORT', sessionId);
    InferenceLogger.log('REPORT', proofSummary);
    InferenceLogger.log('REPORT', 'Model: $tfliteModelAsset');
    InferenceLogger.log(
      'REPORT',
      'Tensors in=${inputTensorShape.join("x")} out=${outputTensorShape.join("x")}',
    );
    InferenceLogger.log(
      'REPORT',
      'Winner: $rawTfliteLabel @ ${(tfliteConfidence * 100).toStringAsFixed(2)}%',
    );
    InferenceLogger.scores('All class probabilities', tfliteAllScores);
    InferenceLogger.log('REPORT', 'Timings: load=${tfliteLoadMs}ms gate=${rulesGateMs}ms infer=${tfliteInferenceMs}ms');
    if (rulesRejectReason != null) {
      InferenceLogger.log('REPORT', 'Rules reject: $rulesRejectReason');
    }
  }
}
