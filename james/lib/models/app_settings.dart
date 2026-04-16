import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  double threshold;
  int cooldownSeconds;
  String whatGuarding;
  String notificationChannel;
  String ntfyUrl;
  String ntfyToken;
  String telegramToken;
  String telegramChatId;
  String webhookUrl;
  String language;
  bool isCalibrated;
  String fontSize;    // 'small' | 'medium' | 'large'
  String contrast;    // 'normal' | 'high'

  AppSettings({
    this.threshold = 0.25,
    this.cooldownSeconds = 30,
    this.whatGuarding = '',
    this.notificationChannel = 'ntfy',
    this.ntfyUrl = '',
    this.ntfyToken = '',
    this.telegramToken = '',
    this.telegramChatId = '',
    this.webhookUrl = '',
    this.language = 'en',
    this.isCalibrated = false,
    this.fontSize = 'medium',
    this.contrast = 'normal',
  });

  static Future<AppSettings> load() async {
    final p = await SharedPreferences.getInstance();
    return AppSettings(
      threshold: p.getDouble('threshold') ?? 0.25,
      cooldownSeconds: p.getInt('cooldown_seconds') ?? 30,
      whatGuarding: p.getString('what_guarding') ?? '',
      notificationChannel: p.getString('notification_channel') ?? 'ntfy',
      ntfyUrl: p.getString('ntfy_url') ?? '',
      ntfyToken: p.getString('ntfy_token') ?? '',
      telegramToken: p.getString('telegram_token') ?? '',
      telegramChatId: p.getString('telegram_chat_id') ?? '',
      webhookUrl: p.getString('webhook_url') ?? '',
      language: p.getString('language') ?? 'en',
      isCalibrated: p.getBool('is_calibrated') ?? false,
      fontSize: p.getString('font_size') ?? 'medium',
      contrast: p.getString('contrast') ?? 'normal',
    );
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setDouble('threshold', threshold);
    await p.setInt('cooldown_seconds', cooldownSeconds);
    await p.setString('what_guarding', whatGuarding);
    await p.setString('notification_channel', notificationChannel);
    await p.setString('ntfy_url', ntfyUrl);
    await p.setString('ntfy_token', ntfyToken);
    await p.setString('telegram_token', telegramToken);
    await p.setString('telegram_chat_id', telegramChatId);
    await p.setString('webhook_url', webhookUrl);
    await p.setString('language', language);
    await p.setBool('is_calibrated', isCalibrated);
    await p.setString('font_size', fontSize);
    await p.setString('contrast', contrast);
  }
}
