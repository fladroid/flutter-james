import 'package:flutter/material.dart';
import 'models/app_settings.dart';
import 'screens/home_screen.dart';
import 'services/translation_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await AppSettings.load();
  await TranslationService.load(settings.language);
  runApp(JamesApp(settings: settings));
}

class JamesApp extends StatefulWidget {
  final AppSettings settings;
  const JamesApp({super.key, required this.settings});
  @override
  State<JamesApp> createState() => _JamesAppState();
}

class _JamesAppState extends State<JamesApp> {
  void _reload() => setState(() {});

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
      home: HomeScreen(settings: widget.settings, onSettingsChanged: _reload),
    );
  }
}
