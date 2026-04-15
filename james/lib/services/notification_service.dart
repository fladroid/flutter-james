import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/app_settings.dart';
import 'translation_service.dart';

class NotificationService {
  static Future<bool> sendArmed(AppSettings s) =>
      _send(s, TranslationService.t('armed_msg'), priority: 'low', tags: 'lock');

  static Future<bool> sendDisarmed(AppSettings s) =>
      _send(s, TranslationService.t('disarmed_msg'), priority: 'low', tags: 'unlock');

  static Future<bool> sendIntrusion(AppSettings s, double magnitude) {
    final detail = TranslationService.t('intrusion_detail',
        params: {'value': magnitude.toStringAsFixed(2)});
    final what = s.whatGuarding.isNotEmpty
        ? '\n${TranslationService.t('guarding_label', params: {'what': s.whatGuarding})}'
        : '';
    return _send(s, '${TranslationService.t('intrusion_msg')}$what\n$detail',
        priority: 'urgent', tags: 'warning,bell');
  }

  static Future<bool> _send(AppSettings s, String message,
      {String priority = 'default', String tags = ''}) async {
    try {
      switch (s.notificationChannel) {
        case 'ntfy':
          return await _sendNtfy(s, message, priority, tags);
        case 'telegram':
          return await _sendTelegram(s, message);
        case 'webhook':
          return await _sendWebhook(s, message, priority);
        default:
          return false;
      }
    } catch (e) {
      return false;
    }
  }

  static Future<bool> _sendNtfy(AppSettings s, String message, String priority, String tags) async {
    if (s.ntfyUrl.isEmpty) return false;
    final headers = <String, String>{
      'Priority': priority,
      if (tags.isNotEmpty) 'Tags': tags,
      if (s.ntfyToken.isNotEmpty) 'Authorization': 'Bearer ${s.ntfyToken}',
    };
    final resp = await http.post(Uri.parse(s.ntfyUrl),
        headers: headers, body: message).timeout(const Duration(seconds: 5));
    return resp.statusCode >= 200 && resp.statusCode < 300;
  }

  static Future<bool> _sendTelegram(AppSettings s, String message) async {
    if (s.telegramToken.isEmpty || s.telegramChatId.isEmpty) return false;
    final url = 'https://api.telegram.org/bot${s.telegramToken}/sendMessage';
    final resp = await http.post(Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'chat_id': s.telegramChatId, 'text': message}))
        .timeout(const Duration(seconds: 5));
    return resp.statusCode == 200;
  }

  static Future<bool> _sendWebhook(AppSettings s, String message, String priority) async {
    if (s.webhookUrl.isEmpty) return false;
    final resp = await http.post(Uri.parse(s.webhookUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'message': message, 'priority': priority,
            'timestamp': DateTime.now().toIso8601String()}))
        .timeout(const Duration(seconds: 5));
    return resp.statusCode >= 200 && resp.statusCode < 300;
  }
}
