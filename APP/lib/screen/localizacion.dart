import 'dart:ui' show Color;
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/ubicacion_app.dart';

class LocalizacionService {
  /// Solicita permisos de ubicación y comienza a rastrear
  Future<bool> requestPermissionAndStartTracking() async {
    if (!UbicacionApp.enabled.value) return false;

    final granted = await requestLocationPermission();
    if (!granted || !UbicacionApp.enabled.value) return false;

    // El permiso normal basta para seguir la ruta mientras la app está abierta.
    await Permission.notification.request();
    return UbicacionApp.enabled.value;
  }

  Future<bool> requestLocationPermission() async {
    var locationPermission = await Geolocator.checkPermission();
    if (locationPermission == LocationPermission.denied) {
      locationPermission = await Geolocator.requestPermission();
    }

    return locationPermission != LocationPermission.denied &&
        locationPermission != LocationPermission.deniedForever;
  }

  /// Inicia las actualizaciones de ubicación
  Future<Position?> getCurrentPosition() async {
    if (!UbicacionApp.enabled.value) return null;
    if (!await Geolocator.isLocationServiceEnabled()) {
      await Geolocator.openLocationSettings();
      return null;
    }

    if (!UbicacionApp.enabled.value) return null;
    return Geolocator.getCurrentPosition(
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 1,
      ),
    );
  }

  /// Inicia el stream de posiciones con o sin notificación
  Stream<Position> getPositionStream({required bool showNotification}) {
    if (!UbicacionApp.enabled.value) return const Stream.empty();
    return Geolocator.getPositionStream(
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 1, // Actualiza cada metro para más precisión
        intervalDuration: const Duration(seconds: 1),
        foregroundNotificationConfig: showNotification
            ? ForegroundNotificationConfig(
                notificationTitle: 'Grabando trayecto',
                notificationText:
                    'La ubicación continúa activa en segundo plano',
                notificationChannelName: 'Grabación de trayectos',
                notificationIcon: const AndroidResource(
                  name: 'ic_notification',
                  defType: 'drawable',
                ),
                color: const Color(0xff4f8f3a),
                enableWakeLock: true,
                enableWifiLock: true,
                setOngoing: true,
              )
            : null,
      ),
    );
  }
}
