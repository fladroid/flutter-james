// lib/services/app_theme.dart
import 'package:flutter/material.dart';

class AppTheme {
  static final AppTheme _instance = AppTheme._internal();
  factory AppTheme() => _instance;
  AppTheme._internal();

  String _size     = 'medium';
  String _contrast = 'normal';

  void init(String size, String contrast) { _size = size; _contrast = contrast; }
  void setSize(String s)     { _size = s; }
  void setContrast(String c) { _contrast = c; }

  bool get isHighContrast => _contrast == 'high';

  double get symbolSize  => _size == 'small' ? 22.0 : _size == 'large' ? 38.0 : 28.0;
  double get labelSize   => _size == 'small' ?  7.0 : _size == 'large' ? 12.0 :  9.0;
  double get bodySize    => _size == 'small' ? 11.0 : _size == 'large' ? 15.0 : 13.0;
  double get captionSize => _size == 'small' ?  9.0 : _size == 'large' ? 13.0 : 11.0;
  double get headerSize  => _size == 'small' ? 18.0 : _size == 'large' ? 26.0 : 22.0;
  double get badgeSize   => _size == 'small' ?  8.0 : _size == 'large' ? 13.0 : 10.0;
  double get counterSize => _size == 'small' ? 18.0 : _size == 'large' ? 28.0 : 22.0;

  Color get background  => isHighContrast ? const Color(0xFFF0EBE0) : const Color(0xFFF5F0E8);
  Color get surface     => isHighContrast ? const Color(0xFFFFFFFF) : const Color(0xFFFAF7F2);
  Color get ink         => isHighContrast ? const Color(0xFF000000) : const Color(0xFF1A1A1A);
  Color get inkMedium   => isHighContrast ? const Color(0xFF2A2A2A) : const Color(0xFF4A4540);
  Color get inkLight    => isHighContrast ? const Color(0xFF3A3A3A) : const Color(0xFF6B6560);
  Color get inkFaint    => isHighContrast ? const Color(0xFF555555) : const Color(0xFF9A9590);
  Color get border      => isHighContrast ? const Color(0xFF888880) : const Color(0xFFDDD8CE);
  Color get accent      => const Color(0xFF2D5A27);
  Color get accentText  => Colors.white;
  Color get destructive => const Color(0xFF8B2020);
  Color get positive    => const Color(0xFF2D5A27);

  String get size     => _size;
  String get contrast => _contrast;
}
