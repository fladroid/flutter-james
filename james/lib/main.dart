import 'package:flutter/material.dart';
import 'models/app_settings.dart';
import 'screens/home_screen.dart';
import 'services/translation_service.dart';
import 'services/app_theme.dart';

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
  final _theme = AppTheme();

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
      theme: ThemeData(
        colorScheme: ColorScheme.light(
          primary: _theme.accent,
          secondary: _theme.accent,
          surface: _theme.surface,
        ),
        scaffoldBackgroundColor: _theme.background,
        appBarTheme: AppBarTheme(
          backgroundColor: _theme.background,
          foregroundColor: _theme.ink,
          elevation: 0,
        ),
        textTheme: TextTheme(
          bodyMedium: TextStyle(color: _theme.ink),
        ),
      ),
      home: HomeScreen(settings: _settings, onSettingsChanged: _reload),
    );
  }
}
