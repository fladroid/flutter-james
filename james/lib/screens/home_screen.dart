import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../models/app_settings.dart';
import '../models/event_log.dart';
import '../services/notification_service.dart';
import '../services/translation_service.dart';
import 'settings_screen.dart';
import 'sensor_screen.dart';

class HomeScreen extends StatefulWidget {
  final AppSettings settings;
  final VoidCallback onSettingsChanged;
  const HomeScreen({super.key, required this.settings, required this.onSettingsChanged});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _armed = false;
  double _magnitude = 0.0;
  DateTime? _lastAlert;
  StreamSubscription? _sensorSub;
  final List<EventEntry> _events = [];

  void _arm() async {
    setState(() => _armed = true);
    _addEvent(EventType.armed);
    await NotificationService.sendArmed(widget.settings);
    _sensorSub = userAccelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 500),
    ).listen(_onSensor);
  }

  void _disarm() async {
    setState(() => _armed = false);
    _sensorSub?.cancel();
    _sensorSub = null;
    _addEvent(EventType.disarmed);
    await NotificationService.sendDisarmed(widget.settings);
  }

  void _onSensor(UserAccelerometerEvent e) {
    final m = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
    setState(() => _magnitude = m);
    if (!_armed) return;
    final now = DateTime.now();
    if (m > widget.settings.threshold) {
      final cooldown = Duration(seconds: widget.settings.cooldownSeconds);
      if (_lastAlert == null || now.difference(_lastAlert!) >= cooldown) {
        _lastAlert = now;
        _addEvent(EventType.intrusion, magnitude: m);
        NotificationService.sendIntrusion(widget.settings, m);
      }
    }
  }

  void _addEvent(EventType type, {double? magnitude}) {
    setState(() {
      _events.insert(0, EventEntry(timestamp: DateTime.now(), type: type, magnitude: magnitude));
      if (_events.length > 50) _events.removeLast();
    });
  }

  @override
  void dispose() {
    _sensorSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    final t = TranslationService.t;
    final armed = _armed;

    return Scaffold(
      backgroundColor: armed ? const Color(0xFF0a2e0a) : const Color(0xFF0a0a1e),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('${t('app_title')} v1.0.0',
            style: const TextStyle(color: Colors.white70, fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.sensors, color: Colors.white54),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SensorScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white54),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(
                  builder: (_) => SettingsScreen(settings: s)));
              widget.onSettingsChanged();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 40),
          // Status circle
          Center(
            child: GestureDetector(
              onTap: armed ? _disarm : _arm,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: armed ? const Color(0xFF1a5c1a) : const Color(0xFF1a1a3e),
                  border: Border.all(
                    color: armed ? Colors.greenAccent : Colors.blueAccent,
                    width: 3,
                  ),
                  boxShadow: [BoxShadow(
                    color: (armed ? Colors.greenAccent : Colors.blueAccent).withOpacity(0.3),
                    blurRadius: 30, spreadRadius: 5,
                  )],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(armed ? Icons.lock : Icons.lock_open,
                        color: armed ? Colors.greenAccent : Colors.blueAccent, size: 48),
                    const SizedBox(height: 8),
                    Text(armed ? t('armed') : t('disarmed'),
                        style: TextStyle(
                          color: armed ? Colors.greenAccent : Colors.blueAccent,
                          fontSize: 18, fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        )),
                    const SizedBox(height: 4),
                    Text(armed ? t('disarm') : t('arm'),
                        style: const TextStyle(color: Colors.white38, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Live magnitude
          Text(t('live_magnitude'),
              style: const TextStyle(color: Colors.white38, fontSize: 12)),
          const SizedBox(height: 4),
          Text('${_magnitude.toStringAsFixed(3)} m/s²',
              style: TextStyle(
                color: _magnitude > s.threshold ? Colors.redAccent : Colors.white70,
                fontSize: 20, fontFamily: 'monospace',
              )),
          if (s.whatGuarding.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(t('guarding_label', params: {'what': s.whatGuarding}),
                style: const TextStyle(color: Colors.white38, fontSize: 13)),
          ],
          const SizedBox(height: 24),
          // Events
          Expanded(
            child: _events.isEmpty
                ? Center(child: Text(t('events_empty'),
                    style: const TextStyle(color: Colors.white24)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _events.length,
                    itemBuilder: (_, i) => _EventTile(event: _events[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  final EventEntry event;
  const _EventTile({required this.event});

  @override
  Widget build(BuildContext context) {
    final t = TranslationService.t;
    IconData icon;
    Color color;
    String label;

    switch (event.type) {
      case EventType.armed:
        icon = Icons.lock; color = Colors.greenAccent;
        label = t('armed_msg');
      case EventType.disarmed:
        icon = Icons.lock_open; color = Colors.blueAccent;
        label = t('disarmed_msg');
      case EventType.intrusion:
        icon = Icons.warning_amber; color = Colors.redAccent;
        label = '${t('intrusion_msg')} ${event.magnitude?.toStringAsFixed(2)} m/s²';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Text(event.timeString,
            style: const TextStyle(color: Colors.white38, fontSize: 12, fontFamily: 'monospace')),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: TextStyle(color: color, fontSize: 13))),
      ]),
    );
  }
}
