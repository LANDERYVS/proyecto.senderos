import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TemaApp {
  TemaApp._();

  static const _darkModeKey = 'dark_mode_enabled';
  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier(
    ThemeMode.light,
  );

  static Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    themeMode.value = preferences.getBool(_darkModeKey) == true
        ? ThemeMode.dark
        : ThemeMode.light;
  }

  static Future<void> setDarkMode(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setBool(_darkModeKey, enabled);
    if (!saved) {
      throw StateError('No se pudo guardar la preferencia del tema.');
    }
    themeMode.value = enabled ? ThemeMode.dark : ThemeMode.light;
  }
}
