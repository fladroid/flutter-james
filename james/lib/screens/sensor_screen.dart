import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../services/translation_service.dart';
import '../services/app_theme.dart';

class SensorScreen extends StatefulWidget {
  const SensorScreen({super.key});
  @override
  State<SensorScreen> createState() => _SensorScreenState();
}

class _SensorScreenState extends State<SensorScreen> {
  final _theme = AppTheme();
  final List<StreamSubscription> _subs = [];
  double _accelMag = 0, _userAccelMag = 0, _gyroMag = 0;
  double _accelX = 0, _accelY = 0, _accelZ = 0;
  double _userX = 0, _userY = 0, _userZ = 0;
  double _gyroX = 0, _gyroY = 0, _gyroZ = 0;
  double _maxUserAccel = 0;

  @override
  void initState() {
    super.initState();
    _subs.add(accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 200),
    ).listen((e) => setState(() {
      _accelX = e.x; _accelY = e.y; _accelZ = e.z;
      _accelMag = sqrt(e.x*e.x + e.y*e.y + e.z*e.z);
    })));
    _subs.add(userAccelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 200),
    ).listen((e) => setState(() {
      _userX = e.x; _userY = e.y; _userZ = e.z;
      _userAccelMag = sqrt(e.x*e.x + e.y*e.y + e.z*e.z);
      if (_userAccelMag > _maxUserAccel) _maxUserAccel = _userAccelMag;
    })));
    _subs.add(gyroscopeEventStream(
      samplingPeriod: const Duration(milliseconds: 200),
    ).listen((e) => setState(() {
      _gyroX = e.x; _gyroY = e.y; _gyroZ = e.z;
      _gyroMag = sqrt(e.x*e.x + e.y*e.y + e.z*e.z);
    })));
  }

  @override
  void dispose() {
    for (final s in _subs) s.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = TranslationService.t;
    return Scaffold(
      backgroundColor: _theme.background,
      appBar: AppBar(
        backgroundColor: _theme.background,
        elevation: 0,
        title: Text(t('sensor_explorer'),
            style: TextStyle(color: _theme.inkMedium, fontSize: _theme.bodySize + 2)),
        iconTheme: IconThemeData(color: _theme.inkMedium),
        actions: [
          TextButton(
            onPressed: () => setState(() => _maxUserAccel = 0),
            child: Text('Reset max',
                style: TextStyle(color: _theme.inkFaint, fontSize: _theme.captionSize)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SensorCard(
            title: 'linear_acceleration (UserAccelerometer)',
            subtitle: 'Gravity filtered — used for motion detection',
            accentColor: _theme.accent,
            magnitude: _userAccelMag,
            x: _userX, y: _userY, z: _userZ,
            extra: 'Max: ${_maxUserAccel.toStringAsFixed(3)} m/s²',
            theme: _theme,
          ),
          const SizedBox(height: 12),
          _SensorCard(
            title: 'Accelerometer (raw)',
            subtitle: 'Includes gravity (~9.8 m/s² at rest)',
            accentColor: const Color(0xFF1565C0),
            magnitude: _accelMag,
            x: _accelX, y: _accelY, z: _accelZ,
            theme: _theme,
          ),
          const SizedBox(height: 12),
          _SensorCard(
            title: 'Gyroscope',
            subtitle: 'Rotation speed (rad/s)',
            accentColor: const Color(0xFF6A1B9A),
            magnitude: _gyroMag,
            x: _gyroX, y: _gyroY, z: _gyroZ,
            theme: _theme,
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _theme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _theme.border),
            ),
            child: Text(
              'Tip: Shake the device to see peak values.\n'
              'Observe magnitude at rest (should be < 0.01).\n'
              'Set threshold between resting noise and lightest expected movement.\n'
              'Recommended: 0.25 m/s² (tested on Samsung tablets).',
              style: TextStyle(color: _theme.inkMedium, fontSize: _theme.captionSize,
                  height: 1.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _SensorCard extends StatelessWidget {
  final String title, subtitle;
  final Color accentColor;
  final double magnitude, x, y, z;
  final String? extra;
  final AppTheme theme;
  const _SensorCard({
    required this.title, required this.subtitle, required this.accentColor,
    required this.magnitude, required this.x, required this.y, required this.z,
    required this.theme, this.extra,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accentColor.withOpacity(0.4), width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(color: accentColor, fontSize: theme.captionSize + 1,
            fontWeight: FontWeight.bold)),
        Text(subtitle, style: TextStyle(color: theme.inkFaint, fontSize: theme.captionSize)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _axis('X', x, accentColor)),
          Expanded(child: _axis('Y', y, accentColor)),
          Expanded(child: _axis('Z', z, accentColor)),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Text('|mag| = ', style: TextStyle(color: theme.inkFaint, fontSize: theme.captionSize)),
          Text(magnitude.toStringAsFixed(4),
              style: TextStyle(color: accentColor, fontSize: theme.bodySize + 3,
                  fontFamily: 'monospace', fontWeight: FontWeight.bold)),
          if (extra != null) ...[
            const SizedBox(width: 16),
            Text(extra!, style: TextStyle(color: accentColor.withOpacity(0.7),
                fontSize: theme.captionSize)),
          ],
        ]),
      ]),
    );
  }

  Widget _axis(String label, double val, Color color) => Column(children: [
    Text(label, style: TextStyle(color: AppTheme().inkFaint, fontSize: 11)),
    Text(val.toStringAsFixed(3),
        style: TextStyle(color: color.withOpacity(0.8), fontSize: 12,
            fontFamily: 'monospace')),
  ]);
}
