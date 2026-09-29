import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'localizacion.dart';

class SeguimientoSenderoController extends ChangeNotifier {
  SeguimientoSenderoController({
    required this.routePoints,
    required this.mapController,
  });

  final List<LatLng> routePoints;
  final MapController mapController;
  final LocalizacionService _localizacionService = LocalizacionService();
  final Distance _distanceCalculator = const Distance();

  StreamSubscription<Position>? _positionSubscription;
  Timer? _timer;
  DateTime? _startTime;
  double? _lastAltitude;
  bool _isDisposed = false;

  LatLng? userLocation;
  bool isLoadingLocation = true;
  Duration elapsedTime = Duration.zero;
  double distanceKm = 0;
  double elevationGainMeters = 0;

  String get formattedDuration {
    final hours = elapsedTime.inHours.toString().padLeft(2, '0');
    final minutes = (elapsedTime.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (elapsedTime.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  LatLng get initialCenter {
    if (routePoints.isEmpty) {
      return userLocation ?? const LatLng(-34.6037, -58.3816);
    }
    final latitude = routePoints.fold<double>(
      0,
      (sum, point) => sum + point.latitude,
    );
    final longitude = routePoints.fold<double>(
      0,
      (sum, point) => sum + point.longitude,
    );
    return LatLng(
      latitude / routePoints.length,
      longitude / routePoints.length,
    );
  }

  Future<void> start() async {
    _startTime = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isDisposed || _startTime == null) return;
      elapsedTime = DateTime.now().difference(_startTime!);
      _notify();
    });

    try {
      if (!await _localizacionService.requestPermissionAndStartTracking()) {
        isLoadingLocation = false;
        _notify();
        return;
      }

      final position = await _localizacionService.getCurrentPosition().timeout(
        const Duration(seconds: 15),
      );
      if (!_isDisposed && position != null) _updateUserLocation(position);
    } on Exception catch (error) {
      debugPrint('No se obtuvo una posición inicial: $error');
    }

    if (_isDisposed) return;
    isLoadingLocation = false;
    _notify();
    _positionSubscription = _localizacionService
        .getPositionStream(showNotification: false)
        .listen(
          (position) {
            if (!_isDisposed) _updateUserLocation(position);
          },
          onError: (Object error) {
            debugPrint('Error al recibir ubicación: $error');
          },
        );
  }

  void _updateUserLocation(Position position) {
    final point = LatLng(position.latitude, position.longitude);
    userLocation = point;
    _updateProgress(point, position.altitude);
    try {
      mapController.move(point, 16);
    } on StateError {
      // The map controller may not be attached yet.
    }
    _notify();
  }

  void _updateProgress(LatLng point, double altitude) {
    if (routePoints.isEmpty) return;

    var nearestIndex = 0;
    var nearestDistance = double.infinity;
    for (var index = 0; index < routePoints.length; index++) {
      final distance = _distanceCalculator.as(
        LengthUnit.Meter,
        point,
        routePoints[index],
      );
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestIndex = index;
      }
    }

    var distanceAlongRoute = 0.0;
    for (var index = 0; index < nearestIndex; index++) {
      distanceAlongRoute += _distanceCalculator.as(
        LengthUnit.Meter,
        routePoints[index],
        routePoints[index + 1],
      );
    }
    distanceKm = distanceAlongRoute / 1000;

    if (!altitude.isFinite) return;
    final previousAltitude = _lastAltitude;
    if (previousAltitude != null && altitude > previousAltitude) {
      elevationGainMeters += altitude - previousAltitude;
    }
    _lastAltitude = altitude;
  }

  void centerOnUserLocation() {
    final location = userLocation;
    if (location == null) return;
    try {
      mapController.move(location, 16);
    } on StateError {
      // The map controller may not be attached yet.
    }
  }

  void _notify() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _timer?.cancel();
    _positionSubscription?.cancel();
    _localizacionService.dispose();
    super.dispose();
  }
}
