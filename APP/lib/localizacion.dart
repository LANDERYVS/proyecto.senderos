import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocalizacionService {
  StreamSubscription<Position>? _positionSubscription;

  /// Solicita permisos de ubicación y comienza a rastrear
  Future<bool> requestPermissionAndStartTracking() async {
    final status = await Permission.location.request();

    if (status.isGranted) {
      await Permission.locationAlways.request();
      await Permission.notification.request();
      return true;
    }
    return false;
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
                enableWakeLock: true,
                enableWifiLock: true,
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
