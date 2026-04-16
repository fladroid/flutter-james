import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../models/app_settings.dart';
import '../services/app_theme.dart';

enum PhaseState { idle, measuring, done }

class CalibrationScreen extends StatefulWidget {
  final AppSettings settings;
  const CalibrationScreen({super.key, required this.settings});
  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen>
    with SingleTickerProviderStateMixin {

  final _theme = AppTheme();
  late AnimationController _progressCtrl;
  StreamSubscription? _sensorSub;
  PhaseState _measuring = PhaseState.idle;
  int _activePhase = -1;

  double? _restMax;
  double? _gentleMin, _gentleMax;
  double? _strongMin, _strongMax;
  double? _suggested;

  double _liveMag = 0;
  final List<double> _samples = [];

  static const _duration = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _progressCtrl = AnimationController(vsync: this, duration: _duration);
  }

  @override
  void dispose() {
    _sensorSub?.cancel();
    _progressCtrl.dispose();
    super.dispose();
  }

  void _startPhase(int phase) {
    if (_measuring == PhaseState.measuring) return;
    setState(() {
      _measuring = PhaseState.measuring;
      _activePhase = phase;
      _samples.clear();
      _liveMag = 0;
    });
    _progressCtrl.reset();
    _progressCtrl.forward();
    _sensorSub?.cancel();
    _sensorSub = userAccelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 100),
    ).listen((e) {
      final m = sqrt(e.x*e.x + e.y*e.y + e.z*e.z);
      _samples.add(m);
      if (mounted) setState(() => _liveMag = m);
    });
    Future.delayed(_duration, _finishPhase);
  }

  void _finishPhase() {
    _sensorSub?.cancel();
    if (_samples.isEmpty) return;
    final peak = _samples.reduce(max);
    final minVal = _samples.reduce(min);
    setState(() {
      switch (_activePhase) {
        case 0: _restMax = peak;
        case 1: _gentleMin = minVal; _gentleMax = peak;
        case 2: _strongMin = minVal; _strongMax = peak;
      }
      _measuring = PhaseState.done;
      _liveMag = 0;
      if (_restMax != null && _gentleMin != null && _strongMin != null) {
        _calculateSuggested();
      }
    });
  }

  void _calculateSuggested() {
    final c1 = _restMax! * 3;
    final c2 = _gentleMin! / 2;
    var t = max(c1, c2);
    t = ((t * 100).round()) / 100;
    if (t < 0.05) t = 0.05;
    if (t > 2.0) t = 2.0;
    _suggested = t;
  }

  Future<void> _apply() async {
    if (_suggested == null) return;
    widget.settings.threshold = _suggested!;
    widget.settings.isCalibrated = true;
    await widget.settings.save();
    if (mounted) Navigator.pop(context, _suggested);
  }

  bool get _allDone => _restMax != null && _gentleMin != null && _strongMin != null;

  // Boje po fazama — dovoljno distinktivne na bijeloj pozadini
  Color get _restColor   => const Color(0xFFE65100);   // tamna narančasta
  Color get _gentleColor => const Color(0xFFF9A825);   // jantarna
  Color get _strongColor => _theme.accent;              // zelena (Tracker akcent)

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _theme.background,
      appBar: AppBar(
        backgroundColor: _theme.background,
        elevation: 0,
        title: Text('Calibrator',
            style: TextStyle(color: _theme.inkMedium, fontSize: _theme.bodySize + 2)),
        iconTheme: IconThemeData(color: _theme.inkMedium),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Measure each phase separately.\nRepeat any phase if needed.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _theme.inkMedium, fontSize: _theme.bodySize, height: 1.5),
          ),
          const SizedBox(height: 24),

          _PhaseCard(
            phase: 0,
            icon: '🛑',
            label: 'RESTING',
            instruction: 'Leave device completely still',
            color: _restColor,
            resultLabel: _restMax == null ? null
                : 'Peak noise: ${_restMax!.toStringAsFixed(4)} m/s²',
            isActive: _activePhase == 0 && _measuring == PhaseState.measuring,
            liveMag: _activePhase == 0 ? _liveMag : 0,
            progress: _activePhase == 0 ? _progressCtrl : null,
            onStart: _measuring == PhaseState.measuring ? null : () => _startPhase(0),
            theme: _theme,
          ),
          const SizedBox(height: 12),

          _PhaseCard(
            phase: 1,
            icon: '🤏',
            label: 'GENTLE MOVEMENT',
            instruction: 'Move device very gently\nAs if carefully lifting it',
            color: _gentleColor,
            resultLabel: _gentleMin == null ? null
                : 'Min: ${_gentleMin!.toStringAsFixed(4)}  Peak: ${_gentleMax!.toStringAsFixed(4)} m/s²',
            isActive: _activePhase == 1 && _measuring == PhaseState.measuring,
            liveMag: _activePhase == 1 ? _liveMag : 0,
            progress: _activePhase == 1 ? _progressCtrl : null,
            onStart: _measuring == PhaseState.measuring ? null : () => _startPhase(1),
            theme: _theme,
          ),
          const SizedBox(height: 12),

          _PhaseCard(
            phase: 2,
            icon: '💥',
            label: 'CLEAR MOVEMENT',
            instruction: 'Move device clearly and firmly\nAs an intruder would',
            color: _strongColor,
            resultLabel: _strongMin == null ? null
                : 'Min: ${_strongMin!.toStringAsFixed(4)}  Peak: ${_strongMax!.toStringAsFixed(4)} m/s²',
            isActive: _activePhase == 2 && _measuring == PhaseState.measuring,
            liveMag: _activePhase == 2 ? _liveMag : 0,
            progress: _activePhase == 2 ? _progressCtrl : null,
            onStart: _measuring == PhaseState.measuring ? null : () => _startPhase(2),
            theme: _theme,
          ),

          const SizedBox(height: 28),

          if (_allDone && _suggested != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _theme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _theme.accent.withOpacity(0.5), width: 1.5),
              ),
              child: Column(children: [
                Text('Suggested threshold',
                    style: TextStyle(color: _theme.inkMedium, fontSize: _theme.bodySize)),
                const SizedBox(height: 8),
                Text('${_suggested!.toStringAsFixed(2)} m/s²',
                    style: TextStyle(
                      color: _theme.accent, fontSize: 40,
                      fontFamily: 'monospace', fontWeight: FontWeight.bold,
                    )),
                const SizedBox(height: 4),
                Text(
                  _suggested! < _gentleMin!
                      ? '✅ Will catch gentle movement'
                      : '⚠️ May miss gentle movement — remeasure',
                  style: TextStyle(
                    color: _suggested! < _gentleMin! ? _theme.accent : _restColor,
                    fontSize: _theme.captionSize,
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _theme.accent,
                foregroundColor: _theme.accentText,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _apply,
              child: Text('Apply & Save',
                  style: TextStyle(fontSize: _theme.bodySize, fontWeight: FontWeight.bold)),
            ),
          ],

          if (!_allDone)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${_restMax == null ? '○' : '✓'} Resting  '
                '${_gentleMin == null ? '○' : '✓'} Gentle  '
                '${_strongMin == null ? '○' : '✓'} Strong',
                textAlign: TextAlign.center,
                style: TextStyle(color: _theme.inkFaint, fontSize: _theme.bodySize),
              ),
            ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _PhaseCard extends StatelessWidget {
  final int phase;
  final String icon, label, instruction;
  final Color color;
  final String? resultLabel;
  final bool isActive;
  final double liveMag;
  final AnimationController? progress;
  final VoidCallback? onStart;
  final AppTheme theme;

  const _PhaseCard({
    required this.phase, required this.icon, required this.label,
    required this.instruction, required this.color,
    this.resultLabel, required this.isActive, required this.liveMag,
    this.progress, this.onStart, required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isActive ? color.withOpacity(0.08) : theme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isActive ? color.withOpacity(0.7) : color.withOpacity(0.35),
          width: isActive ? 2 : 1,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(
                  color: color, fontSize: theme.captionSize + 1,
                  fontWeight: FontWeight.bold, letterSpacing: 1)),
              Text(instruction, style: TextStyle(
                  color: theme.inkMedium, fontSize: theme.captionSize, height: 1.4)),
            ],
          )),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isActive ? color.withOpacity(0.15) : theme.surface,
              foregroundColor: color,
              side: BorderSide(color: color.withOpacity(0.6)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
            ),
            onPressed: onStart,
            child: Text(
              resultLabel != null && !isActive ? 'Redo' : 'Measure',
              style: TextStyle(fontSize: theme.captionSize),
            ),
          ),
        ]),

        if (isActive && progress != null) ...[
          const SizedBox(height: 10),
          AnimatedBuilder(
            animation: progress!,
            builder: (_, __) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(
                  value: progress!.value,
                  backgroundColor: theme.border,
                  valueColor: AlwaysStoppedAnimation(color),
                  minHeight: 6,
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${(5 - (progress!.value * 5)).ceil()}s',
                        style: TextStyle(color: color, fontSize: theme.bodySize,
                            fontFamily: 'monospace')),
                    Text('Live: ${liveMag.toStringAsFixed(4)} m/s²',
                        style: TextStyle(color: color.withOpacity(0.8),
                            fontSize: theme.captionSize, fontFamily: 'monospace')),
                  ],
                ),
              ],
            ),
          ),
        ],

        if (resultLabel != null && !isActive) ...[
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.check_circle, color: color, size: 14),
            const SizedBox(width: 6),
            Text(resultLabel!, style: TextStyle(
                color: color, fontSize: theme.captionSize,
                fontFamily: 'monospace')),
          ]),
        ],
      ]),
    );
  }
}
