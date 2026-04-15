import 'dart:convert';
import 'package:flutter/services.dart';

class TranslationService {
  static Map<String, dynamic> _translations = {};
  static String _currentLang = 'en';
  static Map<String, dynamic> _config = {};

  static Future<void> load(String lang) async {
    final raw = await rootBundle.loadString('assets/config.json');
    _config = json.decode(raw);
    _currentLang = lang;
    _translations = _config['translations'][lang] ?? _config['translations']['en'];
  }

  static Map<String, dynamic> get defaultSettings => _config['default_settings'] ?? {};

  static String t(String key, {Map<String, String>? params}) {
    String val = _translations[key] ?? key;
    if (params != null) {
      params.forEach((k, v) { val = val.replaceAll('{$k}', v); });
    }
    return val;
  }

  static String get currentLang => _currentLang;

  static List<String> get availableLanguages =>
      (_config['translations'] as Map<String, dynamic>?)?.keys.toList() ?? ['en'];
}
