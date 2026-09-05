import 'dart:async';
import 'dart:ui' show Color;
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocalizacionService {
  StreamSubscription<Position>? _positionSubscription;

  /// Solicita permisos de ubicación y comienza a rastrear
  Future<bool> requestPermissionAndStartTracking() async {
    var locationPermission = await Geolocator.checkPermission();
    if (locationPermission == LocationPermission.denied) {
      locationPermission = await Geolocator.requestPermission();
    }

    if (locationPermission == LocationPermission.denied ||
        locationPermission == LocationPermission.deniedForever) {
      return false;
    }

    // El permiso normal basta para seguir la ruta mientras la app está abierta.
    await Permission.notification.request();
    return true;
  }

  /// Inicia las actualizaciones de ubicación
  Future<Position?> getCurrentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      await Geolocator.openLocationSettings();
      return null;
    }

    return Geolocator.getCurrentPosition(
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 1,
      ),
    );
  }

  /// Inicia el stream de posiciones con o sin notificación
  Stream<Position> getPositionStream({required bool showNotification}) {
    _positionSubscription?.cancel();

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

  /// Detiene el stream de posiciones
  void stopTracking() {
    _positionSubscription?.cancel();
  }

  /// Limpia recursos
  void dispose() {
    _positionSubscription?.cancel();
  }
}
