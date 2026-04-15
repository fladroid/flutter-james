enum EventType { armed, disarmed, intrusion }

class EventEntry {
  final DateTime timestamp;
  final EventType type;
  final double? magnitude;

  EventEntry({required this.timestamp, required this.type, this.magnitude});

  String get timeString {
    final t = timestamp;
    return '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}:${t.second.toString().padLeft(2,'0')}';
  }
}
