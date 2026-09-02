import 'dart:async';
import 'dart:ui' show Color;
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocalizacionService {
  StreamSubscription<Position>? _positionSubscription;

  /// Solicita permisos de ubicación y comienza a rastrear
  Future<bool> requestPermissionAndStartTracking() async {
    final locationStatus = await Permission.location.request();

    if (!locationStatus.isGranted) {
      return false;
    }

    var alwaysStatus = await Permission.locationAlways.status;
    if (!alwaysStatus.isGranted) {
      alwaysStatus = await Permission.locationAlways.request();
    }

    if (!alwaysStatus.isGranted) {
      return false;
    }

    await Permission.notification.request();
    return true;
  }

  /// Inicia las actualizaciones de ubicación
  Future<Position?> getCurrentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      await Geolocator.openLocationSettings();
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition();
    } catch (e) {
      return null;
    }
  }

  /// Inicia el stream de posiciones con o sin notificación
  Stream<Position> getPositionStream({required bool showNotification}) {
    _positionSubscription?.cancel();

    return Geolocator.getPositionStream(
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 1, // Actualiza cada metro para más precisión
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
