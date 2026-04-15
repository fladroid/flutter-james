import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../services/translation_service.dart';
import 'calibration_screen.dart';

class SettingsScreen extends StatefulWidget {
  final AppSettings settings;
  const SettingsScreen({super.key, required this.settings});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _threshold, _cooldown, _whatGuarding;
  late TextEditingController _ntfyUrl, _ntfyToken;
  late TextEditingController _telegramToken, _telegramChatId;
  late TextEditingController _webhookUrl;
  late String _channel;
  late String _lang;

  @override
  void initState() {
    super.initState();
    final s = widget.settings;
    _threshold = TextEditingController(text: s.threshold.toString());
    _cooldown = TextEditingController(text: s.cooldownSeconds.toString());
    _whatGuarding = TextEditingController(text: s.whatGuarding);
    _ntfyUrl = TextEditingController(text: s.ntfyUrl);
    _ntfyToken = TextEditingController(text: s.ntfyToken);
    _telegramToken = TextEditingController(text: s.telegramToken);
    _telegramChatId = TextEditingController(text: s.telegramChatId);
    _webhookUrl = TextEditingController(text: s.webhookUrl);
    _channel = s.notificationChannel;
    _lang = s.language;
  }

  @override
  void dispose() {
    for (final c in [_threshold, _cooldown, _whatGuarding, _ntfyUrl,
        _ntfyToken, _telegramToken, _telegramChatId, _webhookUrl]) c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final s = widget.settings;
    s.threshold = double.tryParse(_threshold.text) ?? s.threshold;
    s.cooldownSeconds = int.tryParse(_cooldown.text) ?? s.cooldownSeconds;
    s.whatGuarding = _whatGuarding.text;
    s.notificationChannel = _channel;
    s.ntfyUrl = _ntfyUrl.text;
    s.ntfyToken = _ntfyToken.text;
    s.telegramToken = _telegramToken.text;
    s.telegramChatId = _telegramChatId.text;
    s.webhookUrl = _webhookUrl.text;
    s.language = _lang;
    await s.save();
    await TranslationService.load(_lang);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _openCalibrator() async {
    final result = await Navigator.push<double>(context,
        MaterialPageRoute(builder: (_) =>
            CalibrationScreen(settings: widget.settings)));
    if (result != null) {
      setState(() => _threshold.text = result.toStringAsFixed(2));
    }
  }

  void _showBatteryOptDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a3e),
        title: const Text('Battery Optimization',
            style: TextStyle(color: Colors.orangeAccent)),
        content: const SingleChildScrollView(
          child: Text(
            'For James to work reliably with the screen off, '
            'disable battery optimization for this app.\n\n'
            'Samsung One UI:\n'
            '1. Settings → Apps → James\n'
            '2. Battery → Unrestricted\n\n'
            'Or:\n'
            '1. Settings → Device care → Battery\n'
            '2. App power management\n'
            '3. Add James to "Never sleeping apps"\n\n'
            'Without this, Samsung may stop James after a few minutes.',
            style: TextStyle(color: Colors.white70, height: 1.6),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: Colors.blueAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = TranslationService.t;
    final langs = TranslationService.availableLanguages;
    final channels = ['ntfy', 'telegram', 'webhook'];

    return Scaffold(
      backgroundColor: const Color(0xFF0a0a1e),
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        title: Text(t('settings'), style: const TextStyle(color: Colors.white70)),
        iconTheme: const IconThemeData(color: Colors.white54),
        actions: [
          TextButton(onPressed: _save,
              child: Text(t('save'),
                  style: const TextStyle(color: Colors.blueAccent))),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // Battery optimization warning banner
          GestureDetector(
            onTap: _showBatteryOptDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orangeAccent.withOpacity(0.4)),
              ),
              child: const Row(children: [
                Icon(Icons.battery_alert, color: Colors.orangeAccent, size: 18),
                SizedBox(width: 10),
                Expanded(child: Text(
                  'Disable battery optimization for reliable background operation',
                  style: TextStyle(color: Colors.orangeAccent, fontSize: 12),
                )),
                Icon(Icons.chevron_right, color: Colors.orangeAccent, size: 18),
              ]),
            ),
          ),

          _section('General'),
          _field(t('what_guarding'), _whatGuarding, hint: t('what_guarding_hint')),

          // Threshold row with Calibrate button
          _label(t('threshold')),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _threshold,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white70),
                decoration: _inputDecoration(),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent.withOpacity(0.2),
                foregroundColor: Colors.blueAccent,
                side: const BorderSide(color: Colors.blueAccent, width: 1),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
              icon: const Icon(Icons.tune, size: 16),
              label: const Text('Calibrate', style: TextStyle(fontSize: 13)),
              onPressed: _openCalibrator,
            ),
          ]),
          const SizedBox(height: 12),

          _field(t('cooldown'), _cooldown, keyboard: TextInputType.number),
          const SizedBox(height: 8),
          _label(t('language')),
          DropdownButton<String>(
            value: _lang,
            dropdownColor: const Color(0xFF1a1a3e),
            style: const TextStyle(color: Colors.white70),
            isExpanded: true,
            items: langs.map((l) => DropdownMenuItem(value: l,
                child: Text(l))).toList(),
            onChanged: (v) => setState(() => _lang = v!),
          ),

          const SizedBox(height: 16),
          _section(t('notification_channel')),
          DropdownButton<String>(
            value: _channel,
            dropdownColor: const Color(0xFF1a1a3e),
            style: const TextStyle(color: Colors.white70),
            isExpanded: true,
            items: channels.map((c) => DropdownMenuItem(
              value: c, child: Text(t('channel_$c')))).toList(),
            onChanged: (v) => setState(() => _channel = v!),
          ),
          const SizedBox(height: 8),
          if (_channel == 'ntfy') ...[
            _field(t('ntfy_url'), _ntfyUrl, hint: t('ntfy_url_hint')),
            _field(t('ntfy_token'), _ntfyToken, obscure: true),
          ],
          if (_channel == 'telegram') ...[
            _field(t('telegram_token'), _telegramToken, obscure: true),
            _field(t('telegram_chat_id'), _telegramChatId),
          ],
          if (_channel == 'webhook')
            _field(t('webhook_url'), _webhookUrl),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 6),
    child: Text(title.toUpperCase(),
        style: const TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 1.5)),
  );

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(text, style: const TextStyle(color: Colors.white54, fontSize: 13)),
  );

  InputDecoration _inputDecoration({String? hint}) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Colors.white24),
    filled: true,
    fillColor: Colors.white.withOpacity(0.05),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
    ),
  );

  Widget _field(String label, TextEditingController ctrl,
      {String? hint, TextInputType? keyboard, bool obscure = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label(label),
      TextField(
        controller: ctrl,
        obscureText: obscure,
        keyboardType: keyboard,
        style: const TextStyle(color: Colors.white70),
        decoration: _inputDecoration(hint: hint),
      ),
    ]),
  );
}
