import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';
import '../models/event_log.dart';
import '../services/notification_service.dart';
import '../services/translation_service.dart';
import 'settings_screen.dart';
import 'sensor_screen.dart';
import 'calibration_screen.dart';

class HomeScreen extends StatefulWidget {
  final AppSettings settings;
  final Future<void> Function() onSettingsChanged;
  const HomeScreen({super.key, required this.settings, required this.onSettingsChanged});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _methodChannel = MethodChannel('com.fladroid.james/service');
  static const _eventChannel = EventChannel('com.fladroid.james/intrusion');

  bool _armed = false;
  double _magnitude = 0.0;
  StreamSubscription? _intrusionSub;
  StreamSubscription? _sensorDisplaySub;
  final List<EventEntry> _events = [];

  @override
  void initState() {
    super.initState();
    _checkServiceRunning();
    // Live magnitude display only (lightweight, stops when screen off — OK for display)
    _sensorDisplaySub = userAccelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 300),
    ).listen((e) {
      if (mounted) setState(() =>
        _magnitude = sqrt(e.x*e.x + e.y*e.y + e.z*e.z));
    });
  }

  Future<void> _checkServiceRunning() async {
    try {
      final running = await _methodChannel.invokeMethod<bool>('isRunning') ?? false;
      if (mounted) setState(() => _armed = running);
    } catch (_) {}
  }

  Future<void> _arm() async {
    final s = widget.settings;
    try {
      await _methodChannel.invokeMethod('startService', {
        'threshold': s.threshold,
        'cooldown': s.cooldownSeconds,
        'ntfy_url': s.ntfyUrl,
        'ntfy_token': s.ntfyToken,
        'telegram_token': s.telegramToken,
        'telegram_chat_id': s.telegramChatId,
        'webhook_url': s.webhookUrl,
        'notification_channel': s.notificationChannel,
        'what_guarding': s.whatGuarding,
      });
      // Save armed state for boot autostart
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('autostart_on_boot', true);
    } catch (e) {
      _showError('ForegroundService error: $e');
      return;
    }
    // Listen for intrusion events from native service
    _intrusionSub = _eventChannel.receiveBroadcastStream().listen((mag) {
      _onIntrusion((mag as double));
    });
    setState(() => _armed = true);
    _addEvent(EventType.armed);
  }

  Future<void> _disarm() async {
    try {
      await _methodChannel.invokeMethod('stopService');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('autostart_on_boot', false);
    } catch (_) {}
    _intrusionSub?.cancel();
    _intrusionSub = null;
    setState(() => _armed = false);
    _addEvent(EventType.disarmed);
  }

  void _onIntrusion(double mag) {
    _addEvent(EventType.intrusion, magnitude: mag);
  }

  void _addEvent(EventType type, {double? magnitude}) {
    if (!mounted) return;
    setState(() {
      _events.insert(0, EventEntry(
          timestamp: DateTime.now(), type: type, magnitude: magnitude));
      if (_events.length > 50) _events.removeLast();
    });
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.redAccent));
  }

  @override
  void dispose() {
    _intrusionSub?.cancel();
    _sensorDisplaySub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    final t = TranslationService.t;

    return Scaffold(
      backgroundColor: _armed ? const Color(0xFF0a2e0a) : const Color(0xFF0a0a1e),
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        title: Text('${t('app_title')} v1.2.2',
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
              await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => SettingsScreen(settings: s)));
              widget.onSettingsChanged();
            },
          ),
        ],
      ),
      body: Column(children: [
        const SizedBox(height: 40),
        Center(
          child: GestureDetector(
            onTap: _armed ? _disarm : _arm,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              width: 200, height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _armed ? const Color(0xFF1a5c1a) : const Color(0xFF1a1a3e),
                border: Border.all(
                    color: _armed ? Colors.greenAccent : Colors.blueAccent, width: 3),
                boxShadow: [BoxShadow(
                  color: (_armed ? Colors.greenAccent : Colors.blueAccent).withOpacity(0.3),
                  blurRadius: 30, spreadRadius: 5,
                )],
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(_armed ? Icons.lock : Icons.lock_open,
                    color: _armed ? Colors.greenAccent : Colors.blueAccent, size: 48),
                const SizedBox(height: 8),
                Text(_armed ? t('armed') : t('disarmed'),
                    style: TextStyle(
                      color: _armed ? Colors.greenAccent : Colors.blueAccent,
                      fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2,
                    )),
                const SizedBox(height: 4),
                Text(_armed ? t('disarm') : t('arm'),
                    style: const TextStyle(color: Colors.white38, fontSize: 12)),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 24),
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
        // Not calibrated warning
        if (!widget.settings.isCalibrated)
          GestureDetector(
            onTap: () async {
              await Navigator.push(context,
                  MaterialPageRoute(builder: (_) =>
                      CalibrationScreen(settings: widget.settings)));
              widget.onSettingsChanged();
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orangeAccent.withOpacity(0.5)),
              ),
              child: const Row(children: [
                Icon(Icons.tune, color: Colors.orangeAccent, size: 16),
                SizedBox(width: 8),
                Expanded(child: Text(
                  'Device not calibrated — using default threshold (0.25 m/s²). Tap to calibrate.',
                  style: TextStyle(color: Colors.orangeAccent, fontSize: 12),
                )),
                Icon(Icons.chevron_right, color: Colors.orangeAccent, size: 16),
              ]),
            ),
          ),
        if (_armed)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.circle, color: Colors.greenAccent, size: 8),
              const SizedBox(width: 6),
              Text('ForegroundService active',
                  style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ]),
          ),
        const SizedBox(height: 24),
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
      ]),
    );
  }
}

class _EventTile extends StatelessWidget {
  final EventEntry event;
  const _EventTile({required this.event});

  @override
  Widget build(BuildContext context) {
    final t = TranslationService.t;
    IconData icon; Color color; String label;
    switch (event.type) {
      case EventType.armed:
        icon = Icons.lock; color = Colors.greenAccent; label = t('armed_msg');
      case EventType.disarmed:
        icon = Icons.lock_open; color = Colors.blueAccent; label = t('disarmed_msg');
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
