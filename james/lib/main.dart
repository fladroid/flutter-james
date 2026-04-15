import 'package:flutter/material.dart';
import 'models/app_settings.dart';
import 'screens/home_screen.dart';
import 'services/translation_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await AppSettings.load();
  await TranslationService.load(settings.language);
  runApp(JamesApp(initialSettings: settings));
}

class JamesApp extends StatefulWidget {
  final AppSettings initialSettings;
  const JamesApp({super.key, required this.initialSettings});
  @override
  State<JamesApp> createState() => _JamesAppState();
}

class _JamesAppState extends State<JamesApp> {
  late AppSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.initialSettings;
  }

  Future<void> _reload() async {
    final fresh = await AppSettings.load();
    await TranslationService.load(fresh.language);
    if (mounted) setState(() => _settings = fresh);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'James',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(
          primary: Colors.blueAccent,
          secondary: Colors.greenAccent,
        ),
      ),
      home: HomeScreen(settings: _settings, onSettingsChanged: _reload),
    );
  }
}
