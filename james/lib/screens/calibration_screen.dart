import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../models/app_settings.dart';
import '../services/translation_service.dart';

enum CalibPhase { idle, resting, gentle, strong, done }

class CalibrationScreen extends StatefulWidget {
  final AppSettings settings;
  const CalibrationScreen({super.key, required this.settings});
  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen>
    with SingleTickerProviderStateMixin {

  CalibPhase _phase = CalibPhase.idle;
  StreamSubscription? _sensorSub;
  late AnimationController _progressCtrl;

  // Collected samples per phase
  final List<double> _restSamples = [];
  final List<double> _gentleSamples = [];
  final List<double> _strongSamples = [];

  // Results
  double _restMax = 0;
  double _gentleMin = 0;
  double _gentleMax = 0;
  double _strongMin = 0;
  double _suggestedThreshold = 0;

  static const _phaseDuration = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _progressCtrl = AnimationController(vsync: this, duration: _phaseDuration);
  }

  @override
  void dispose() {
    _sensorSub?.cancel();
    _progressCtrl.dispose();
    super.dispose();
  }

  void _startCalibration() {
    _restSamples.clear();
    _gentleSamples.clear();
    _strongSamples.clear();
    setState(() => _phase = CalibPhase.resting);
    _runPhase(CalibPhase.resting, _restSamples, () {
      setState(() => _phase = CalibPhase.gentle);
      _runPhase(CalibPhase.gentle, _gentleSamples, () {
        setState(() => _phase = CalibPhase.strong);
        _runPhase(CalibPhase.strong, _strongSamples, _finish);
      });
    });
  }

  void _runPhase(CalibPhase phase, List<double> samples, VoidCallback onDone) {
    _progressCtrl.reset();
    _progressCtrl.forward();
    _sensorSub?.cancel();
    _sensorSub = userAccelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 100),
    ).listen((e) {
      final m = sqrt(e.x*e.x + e.y*e.y + e.z*e.z);
      samples.add(m);
    });
    Future.delayed(_phaseDuration, () {
      _sensorSub?.cancel();
      onDone();
    });
  }

  void _finish() {
    _restMax = _restSamples.isEmpty ? 0 : _restSamples.reduce(max);
    _gentleMin = _gentleSamples.isEmpty ? 0 : _gentleSamples.reduce(min);
    _gentleMax = _gentleSamples.isEmpty ? 0 : _gentleSamples.reduce(max);
    _strongMin = _strongSamples.isEmpty ? 0 : _strongSamples.reduce(min);

    // Threshold = midpoint between resting noise and gentlest movement
    // with safety margin: rest_max * 3 or gentle_min / 2, whichever is higher
    final candidate1 = _restMax * 3;
    final candidate2 = _gentleMin / 2;
    _suggestedThreshold = max(candidate1, candidate2);
    // Round to 2 decimals
    _suggestedThreshold = ((_suggestedThreshold * 100).round()) / 100;
    // Sanity clamp
    if (_suggestedThreshold < 0.05) _suggestedThreshold = 0.05;
    if (_suggestedThreshold > 2.0) _suggestedThreshold = 2.0;

    setState(() => _phase = CalibPhase.done);
  }

  void _applyThreshold() async {
    widget.settings.threshold = _suggestedThreshold;
    await widget.settings.save();
    if (mounted) Navigator.pop(context, _suggestedThreshold);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a0a1e),
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        title: const Text('Calibrator',
            style: TextStyle(color: Colors.white70)),
        iconTheme: const IconThemeData(color: Colors.white54),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _phase == CalibPhase.idle
            ? _buildIdle()
            : _phase == CalibPhase.done
                ? _buildResults()
                : _buildPhaseUI(),
      ),
    );
  }

  Widget _buildIdle() => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Icon(Icons.tune, color: Colors.blueAccent, size: 64),
      const SizedBox(height: 24),
      const Text('Threshold Calibrator',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 16),
      _infoBox(
        '3 phases × 5 seconds each:\n\n'
        '1. 🛑  Leave device completely still\n'
        '2. 🤏  Move device very gently\n'
        '3. 💥  Move device clearly / firmly\n\n'
        'James will suggest the optimal threshold based on measured values.',
        Colors.blueAccent,
      ),
      const SizedBox(height: 32),
      ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueAccent,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: _startCalibration,
        child: const Text('Start Calibration',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    ],
  );

  Widget _buildPhaseUI() {
    final phaseData = {
      CalibPhase.resting: (
        icon: '🛑',
        label: 'RESTING',
        instruction: 'Leave the device completely still\nDo not touch it',
        color: Colors.orangeAccent,
      ),
      CalibPhase.gentle: (
        icon: '🤏',
        label: 'GENTLE MOVEMENT',
        instruction: 'Move the device very gently\nAs if someone is carefully lifting it',
        color: Colors.yellowAccent,
      ),
      CalibPhase.strong: (
        icon: '💥',
        label: 'CLEAR MOVEMENT',
        instruction: 'Move the device clearly and firmly\nAs an intruder would',
        color: Colors.greenAccent,
      ),
    };
    final d = phaseData[_phase]!;
    final currentSamples = _phase == CalibPhase.resting ? _restSamples
        : _phase == CalibPhase.gentle ? _gentleSamples : _strongSamples;
    final currentMax = currentSamples.isEmpty ? 0.0 : currentSamples.reduce(max);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(d.icon, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 72)),
        const SizedBox(height: 16),
        Text(d.label, textAlign: TextAlign.center,
            style: TextStyle(color: d.color, fontSize: 22,
                fontWeight: FontWeight.bold, letterSpacing: 2)),
        const SizedBox(height: 12),
        Text(d.instruction, textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 15, height: 1.6)),
        const SizedBox(height: 32),
        AnimatedBuilder(
          animation: _progressCtrl,
          builder: (_, __) => Column(children: [
            LinearProgressIndicator(
              value: _progressCtrl.value,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation(d.color),
              minHeight: 8,
            ),
            const SizedBox(height: 8),
            Text('${(5 - (_progressCtrl.value * 5)).ceil()}s',
                style: TextStyle(color: d.color, fontSize: 28,
                    fontFamily: 'monospace', fontWeight: FontWeight.bold)),
          ]),
        ),
        const SizedBox(height: 24),
        Center(
          child: Text('Peak: ${currentMax.toStringAsFixed(4)} m/s²',
              style: const TextStyle(color: Colors.white38,
                  fontSize: 14, fontFamily: 'monospace')),
        ),
      ],
    );
  }

  Widget _buildResults() => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        const Text('Calibration Complete ✅',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.greenAccent, fontSize: 20,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        _resultRow('🛑 Resting — peak noise', _restMax, Colors.orangeAccent),
        _resultRow('🤏 Gentle — min detected', _gentleMin, Colors.yellowAccent),
        _resultRow('🤏 Gentle — peak', _gentleMax, Colors.yellowAccent),
        _resultRow('💥 Strong — min detected', _strongMin, Colors.greenAccent),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blueAccent.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.blueAccent.withOpacity(0.5)),
          ),
          child: Column(children: [
            const Text('Suggested threshold',
                style: TextStyle(color: Colors.white54, fontSize: 13)),
            const SizedBox(height: 8),
            Text('${_suggestedThreshold.toStringAsFixed(2)} m/s²',
                style: const TextStyle(color: Colors.blueAccent, fontSize: 36,
                    fontFamily: 'monospace', fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              _suggestedThreshold < _gentleMin
                  ? '✅ Will catch gentle movement'
                  : '⚠️ May miss gentle movement — test carefully',
              style: TextStyle(
                color: _suggestedThreshold < _gentleMin
                    ? Colors.greenAccent : Colors.orangeAccent,
                fontSize: 12,
              ),
            ),
          ]),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.greenAccent,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _applyThreshold,
          child: const Text('Apply & Save',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => setState(() => _phase = CalibPhase.idle),
          child: const Text('Recalibrate',
              style: TextStyle(color: Colors.white38)),
        ),
      ],
    ),
  );

  Widget _resultRow(String label, double value, Color color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      Expanded(child: Text(label,
          style: const TextStyle(color: Colors.white54, fontSize: 13))),
      Text('${value.toStringAsFixed(4)} m/s²',
          style: TextStyle(color: color, fontSize: 14, fontFamily: 'monospace')),
    ]),
  );

  Widget _infoBox(String text, Color color) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Text(text, style: TextStyle(color: color.withOpacity(0.8),
        fontSize: 14, height: 1.5)),
  );
}
