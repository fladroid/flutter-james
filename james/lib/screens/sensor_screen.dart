import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../services/translation_service.dart';

class SensorScreen extends StatefulWidget {
  const SensorScreen({super.key});
  @override
  State<SensorScreen> createState() => _SensorScreenState();
}

class _SensorScreenState extends State<SensorScreen> {
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
      backgroundColor: const Color(0xFF0a0a1e),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(t('sensor_explorer'),
            style: const TextStyle(color: Colors.white70)),
        iconTheme: const IconThemeData(color: Colors.white54),
        actions: [
          TextButton(
            onPressed: () => setState(() => _maxUserAccel = 0),
            child: const Text('Reset max', style: TextStyle(color: Colors.white38, fontSize: 12)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SensorCard(
            title: 'linear_acceleration (UserAccelerometer)',
            subtitle: 'Gravity filtered — used for motion detection',
            color: Colors.greenAccent,
            magnitude: _userAccelMag,
            x: _userX, y: _userY, z: _userZ,
            extra: 'Max: ${_maxUserAccel.toStringAsFixed(3)} m/s²',
          ),
          const SizedBox(height: 12),
          _SensorCard(
            title: 'Accelerometer (raw)',
            subtitle: 'Includes gravity (~9.8 m/s² at rest)',
            color: Colors.blueAccent,
            magnitude: _accelMag,
            x: _accelX, y: _accelY, z: _accelZ,
          ),
          const SizedBox(height: 12),
          _SensorCard(
            title: 'Gyroscope',
            subtitle: 'Rotation speed (rad/s)',
            color: Colors.purpleAccent,
            magnitude: _gyroMag,
            x: _gyroX, y: _gyroY, z: _gyroZ,
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Tip: Shake the device to see peak values.\n'
              'linear_acceleration > 0.8 m/s² triggers James alert.\n'
              'Adjust threshold in Settings based on observed values.',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _SensorCard extends StatelessWidget {
  final String title, subtitle;
  final Color color;
  final double magnitude, x, y, z;
  final String? extra;
  const _SensorCard({
    required this.title, required this.subtitle, required this.color,
    required this.magnitude, required this.x, required this.y, required this.z,
    this.extra,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
        Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 11)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _axis('X', x, color)),
          Expanded(child: _axis('Y', y, color)),
          Expanded(child: _axis('Z', z, color)),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          const Text('|mag| = ', style: TextStyle(color: Colors.white38, fontSize: 12)),
          Text(magnitude.toStringAsFixed(4),
              style: TextStyle(color: color, fontSize: 16, fontFamily: 'monospace',
                  fontWeight: FontWeight.bold)),
          if (extra != null) ...[
            const SizedBox(width: 16),
            Text(extra!, style: TextStyle(color: color.withOpacity(0.6), fontSize: 12)),
          ],
        ]),
      ]),
    );
  }

  Widget _axis(String label, double val, Color color) => Column(children: [
    Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
    Text(val.toStringAsFixed(3),
        style: TextStyle(color: color.withOpacity(0.8), fontSize: 12, fontFamily: 'monospace')),
  ]);
}
