import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../services/translation_service.dart';
import '../services/app_theme.dart';
import 'calibration_screen.dart';

class SettingsScreen extends StatefulWidget {
  final AppSettings settings;
  const SettingsScreen({super.key, required this.settings});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _theme = AppTheme();
  late TextEditingController _customThreshold, _cooldown, _whatGuarding;
  late TextEditingController _ntfyUrl, _ntfyToken;
  late TextEditingController _telegramToken, _telegramChatId;
  late TextEditingController _webhookUrl;
  late String _channel;
  late String _lang;
  late String _fontSize;
  late String _contrast;
  late bool _testMode;
  late String _preset; // 'low' | 'medium' | 'high' | 'custom'

  @override
  void initState() {
    super.initState();
    final s = widget.settings;
    _customThreshold = TextEditingController(text: s.threshold.toString());
    _cooldown        = TextEditingController(text: s.cooldownSeconds.toString());
    _whatGuarding    = TextEditingController(text: s.whatGuarding);
    _ntfyUrl         = TextEditingController(text: s.ntfyUrl);
    _ntfyToken       = TextEditingController(text: s.ntfyToken);
    _telegramToken   = TextEditingController(text: s.telegramToken);
    _telegramChatId  = TextEditingController(text: s.telegramChatId);
    _webhookUrl      = TextEditingController(text: s.webhookUrl);
    _channel  = s.notificationChannel;
    _lang     = s.language;
    _fontSize = s.fontSize;
    _contrast = s.contrast;
    _testMode = s.testMode;
    _preset   = s.sensitivityPreset;
  }

  @override
  void dispose() {
    for (final c in [_customThreshold, _cooldown, _whatGuarding, _ntfyUrl,
        _ntfyToken, _telegramToken, _telegramChatId, _webhookUrl]) c.dispose();
    super.dispose();
  }

  double get _effectiveThreshold {
    if (_preset == 'custom') {
      return double.tryParse(_customThreshold.text) ?? 0.25;
    }
    return AppSettings.presetValues[_preset] ?? 0.25;
  }

  Future<void> _save() async {
    final s = widget.settings;
    s.threshold           = _effectiveThreshold;
    s.sensitivityPreset   = _preset;
    s.cooldownSeconds     = int.tryParse(_cooldown.text) ?? s.cooldownSeconds;
    s.whatGuarding        = _whatGuarding.text;
    s.notificationChannel = _channel;
    s.ntfyUrl             = _ntfyUrl.text;
    s.ntfyToken           = _ntfyToken.text;
    s.telegramToken       = _telegramToken.text;
    s.telegramChatId      = _telegramChatId.text;
    s.webhookUrl          = _webhookUrl.text;
    s.language            = _lang;
    s.fontSize            = _fontSize;
    s.contrast            = _contrast;
    s.testMode            = _testMode;
    await s.save();
    await TranslationService.load(_lang);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _openCalibrator() async {
    final result = await Navigator.push<double>(context,
        MaterialPageRoute(builder: (_) =>
            CalibrationScreen(settings: widget.settings)));
    if (result != null) {
      setState(() {
        _preset = 'custom';
        _customThreshold.text = result.toStringAsFixed(2);
      });
    }
  }

  void _showBatteryOptDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _theme.surface,
        title: Text('Battery Optimization',
            style: TextStyle(color: _theme.ink, fontSize: _theme.bodySize + 2)),
        content: SingleChildScrollView(
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
            style: TextStyle(color: _theme.inkMedium, fontSize: _theme.bodySize, height: 1.6),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(
                color: _theme.accent, fontSize: _theme.bodySize)),
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
      backgroundColor: _theme.background,
      appBar: AppBar(
        backgroundColor: _theme.background,
        elevation: 0,
        title: Text(t('settings'),
            style: TextStyle(color: _theme.inkMedium, fontSize: _theme.bodySize + 2)),
        iconTheme: IconThemeData(color: _theme.inkMedium),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(t('save'),
                style: TextStyle(color: _theme.accent, fontSize: _theme.bodySize,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // Battery optimization warning
          GestureDetector(
            onTap: _showBatteryOptDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3CD),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFD4A017).withOpacity(0.6)),
              ),
              child: Row(children: [
                const Icon(Icons.battery_alert, color: Color(0xFF8B6000), size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(
                  'Disable battery optimization for reliable background operation',
                  style: TextStyle(color: _theme.inkMedium, fontSize: _theme.captionSize),
                )),
                Icon(Icons.chevron_right, color: _theme.inkLight, size: 18),
              ]),
            ),
          ),

          // ── DISPLAY ─────────────────────────────────────────
          _section('Display'),

          _label('Font size'),
          const SizedBox(height: 6),
          _SegmentedRow(
            options: const ['small', 'medium', 'large'],
            labels: const ['Small', 'Medium', 'Large'],
            selected: _fontSize,
            theme: _theme,
            onChanged: (v) => setState(() => _fontSize = v),
          ),
          const SizedBox(height: 16),

          _label('Contrast'),
          const SizedBox(height: 6),
          _SegmentedRow(
            options: const ['normal', 'high'],
            labels: const ['Normal', 'High contrast'],
            selected: _contrast,
            theme: _theme,
            onChanged: (v) => setState(() => _contrast = v),
          ),
          const SizedBox(height: 8),
          Text(
            'Changes take effect after saving and reopening the app.',
            style: TextStyle(color: _theme.inkFaint, fontSize: _theme.captionSize),
          ),

          // ── GENERAL ─────────────────────────────────────────
          _section('General'),
          _field(t('what_guarding'), _whatGuarding, hint: t('what_guarding_hint')),

          // Sensitivity preset
          _label(t('sensitivity_preset')),
          const SizedBox(height: 8),
          _PresetSelector(
            selected: _preset,
            theme: _theme,
            t: t,
            onChanged: (v) => setState(() => _preset = v),
          ),
          const SizedBox(height: 10),

          // Custom threshold — vidljiv samo kad je preset = custom
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _preset == 'custom'
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label(t('threshold')),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _customThreshold,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: _theme.ink, fontSize: _theme.bodySize),
                      decoration: _inputDecoration(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _theme.surface,
                      foregroundColor: _theme.accent,
                      side: BorderSide(color: _theme.accent, width: 1),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                    icon: Icon(Icons.tune, size: _theme.captionSize + 2),
                    label: Text('Calibrate', style: TextStyle(fontSize: _theme.captionSize + 1)),
                    onPressed: _openCalibrator,
                  ),
                ]),
                const SizedBox(height: 12),
              ],
            ),
            secondChild: const SizedBox.shrink(),
          ),

          _field(t('cooldown'), _cooldown, keyboard: TextInputType.number),
          const SizedBox(height: 8),

          _label(t('language')),
          DropdownButton<String>(
            value: _lang,
            dropdownColor: _theme.surface,
            style: TextStyle(color: _theme.ink, fontSize: _theme.bodySize),
            isExpanded: true,
            items: langs.map((l) => DropdownMenuItem(value: l,
                child: Text(l))).toList(),
            onChanged: (v) => setState(() => _lang = v!),
          ),

          // ── TEST MODE ────────────────────────────────────────
          _section('Test mode'),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Test mode', style: TextStyle(color: _theme.inkMedium, fontSize: _theme.bodySize)),
                  const SizedBox(height: 2),
                  Text('Arm/disarm works, no notifications sent',
                      style: TextStyle(color: _theme.inkFaint, fontSize: _theme.captionSize)),
                ],
              )),
              Switch(
                value: _testMode,
                activeColor: _theme.accent,
                onChanged: (v) => setState(() => _testMode = v),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ── NOTIFICATION ─────────────────────────────────────
          const SizedBox(height: 16),
          _section(t('notification_channel')),
          DropdownButton<String>(
            value: _channel,
            dropdownColor: _theme.surface,
            style: TextStyle(color: _theme.ink, fontSize: _theme.bodySize),
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
        style: TextStyle(color: _theme.inkFaint, fontSize: _theme.captionSize,
            letterSpacing: 1.5)),
  );

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(text, style: TextStyle(color: _theme.inkMedium, fontSize: _theme.bodySize)),
  );

  InputDecoration _inputDecoration({String? hint}) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: _theme.inkFaint),
    filled: true,
    fillColor: _theme.surface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide(color: _theme.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide(color: _theme.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide(color: _theme.accent, width: 1.5),
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
        style: TextStyle(color: _theme.ink, fontSize: _theme.bodySize),
        decoration: _inputDecoration(hint: hint),
      ),
    ]),
  );
}

// ── Preset selector widget ───────────────────────────────────────────────────
class _PresetSelector extends StatelessWidget {
  final String selected;
  final AppTheme theme;
  final String Function(String) t;
  final void Function(String) onChanged;

  const _PresetSelector({
    required this.selected,
    required this.theme,
    required this.t,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final presets = [
      _PresetOption('low',    Icons.shield_outlined,      t('preset_low'),    t('preset_low_hint'),    '0.50 m/s²'),
      _PresetOption('medium', Icons.shield,                t('preset_medium'), t('preset_medium_hint'), '0.25 m/s²'),
      _PresetOption('high',   Icons.security,              t('preset_high'),   t('preset_high_hint'),   '0.12 m/s²'),
      _PresetOption('custom', Icons.tune,                  t('preset_custom'), t('preset_custom_hint'), ''),
    ];

    return Column(
      children: presets.map((p) {
        final isSelected = selected == p.key;
        return GestureDetector(
          onTap: () => onChanged(p.key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.accent.withOpacity(0.08)
                  : theme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? theme.accent : theme.border,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(children: [
              Icon(p.icon,
                  color: isSelected ? theme.accent : theme.inkLight,
                  size: 22),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(p.label,
                        style: TextStyle(
                          color: isSelected ? theme.accent : theme.inkMedium,
                          fontSize: theme.bodySize,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        )),
                    if (p.value.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(p.value,
                          style: TextStyle(
                            color: theme.inkFaint,
                            fontSize: theme.captionSize,
                            fontFamily: 'monospace',
                          )),
                    ],
                  ]),
                  const SizedBox(height: 2),
                  Text(p.hint,
                      style: TextStyle(
                        color: theme.inkFaint,
                        fontSize: theme.captionSize,
                      )),
                ],
              )),
              if (isSelected)
                Icon(Icons.check_circle, color: theme.accent, size: 20),
            ]),
          ),
        );
      }).toList(),
    );
  }
}

class _PresetOption {
  final String key;
  final IconData icon;
  final String label;
  final String hint;
  final String value;
  const _PresetOption(this.key, this.icon, this.label, this.hint, this.value);
}

// ── Segmented row widget ─────────────────────────────────────────────────────
class _SegmentedRow extends StatelessWidget {
  final List<String> options;
  final List<String> labels;
  final String selected;
  final AppTheme theme;
  final void Function(String) onChanged;

  const _SegmentedRow({
    required this.options,
    required this.labels,
    required this.selected,
    required this.theme,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(options.length, (i) {
        final isSelected = options[i] == selected;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(options[i]),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              margin: EdgeInsets.only(
                left: i == 0 ? 0 : 4,
                right: i == options.length - 1 ? 0 : 4,
              ),
              decoration: BoxDecoration(
                color: isSelected ? theme.accent : theme.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected ? theme.accent : theme.border,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Text(
                labels[i],
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected ? theme.accentText : theme.inkMedium,
                  fontSize: theme.captionSize + 1,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
