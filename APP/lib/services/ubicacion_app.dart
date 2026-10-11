// Aquí se implementa un servicio de la aplicación.


import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
// La clase UbicacionApp reúne los datos y las acciones de esta parte de la app.

class UbicacionApp {
  UbicacionApp._();

  static const _enabledKey = 'app_location_enabled';
  static final ValueNotifier<bool> enabled = ValueNotifier(true);

  static Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    enabled.value = preferences.getBool(_enabledKey) ?? true;
  }

  static Future<void> setEnabled(bool value) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setBool(_enabledKey, value);
    if (!saved) {
      throw StateError('No se pudo guardar la preferencia de ubicación.');
    }
    enabled.value = value;
  }
}
