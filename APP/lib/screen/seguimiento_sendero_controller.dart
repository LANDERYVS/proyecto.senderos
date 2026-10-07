import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../services/ubicacion_app.dart';
import '../utils/route_calculator.dart';
import 'localizacion.dart';

class SeguimientoSenderoController extends ChangeNotifier {
  SeguimientoSenderoController({
    required this.routePoints,
    required this.mapController,
  }) {
    UbicacionApp.enabled.addListener(_onLocationPreferenceChanged);
  }

  final List<LatLng> routePoints;
  final MapController mapController;
  final LocalizacionService _localizacionService = LocalizacionService();
  final RouteDistanceAccumulator _distanceAccumulator =
      RouteDistanceAccumulator();

  StreamSubscription<Position>? _positionSubscription;
  Timer? _timer;
  DateTime? _startTime;
  double? _lastAltitude;
  bool _isDisposed = false;
  int _locationGeneration = 0;

  LatLng? userLocation;
  bool isLoadingLocation = true;
  bool isPaused = false;
  bool isFinished = false;
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
    return RouteCalculator.centerOfPoints(routePoints) ??
        userLocation ??
        const LatLng(-34.6037, -58.3816);
  }

  Future<void> start() async {
    _startTime = DateTime.now();
    _startTimer();
    await _startLocationTracking();
  }

  Future<void> _startLocationTracking() async {
    final generation = ++_locationGeneration;
    if (!UbicacionApp.enabled.value) {
      isLoadingLocation = false;
      _notify();
      return;
    }

    try {
      if (!await _localizacionService.requestPermissionAndStartTracking()) {
        if (generation != _locationGeneration || _isDisposed) return;
        isLoadingLocation = false;
        _notify();
        return;
      }

      final position = await _localizacionService.getCurrentPosition().timeout(
        const Duration(seconds: 15),
      );
      if (generation != _locationGeneration ||
          _isDisposed ||
          !UbicacionApp.enabled.value) {
        return;
      }
      if (position != null) _updateUserLocation(position);
    } on Exception catch (error) {
      debugPrint('No se obtuvo una posición inicial: $error');
    }

    if (generation != _locationGeneration ||
        _isDisposed ||
        !UbicacionApp.enabled.value) {
      return;
    }
    isLoadingLocation = false;
    _notify();
    await _positionSubscription?.cancel();
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

  void _onLocationPreferenceChanged() {
    if (!UbicacionApp.enabled.value) {
      _locationGeneration++;
      _positionSubscription?.cancel();
      _positionSubscription = null;
      userLocation = null;
      _distanceAccumulator.resetBaseline();
      _lastAltitude = null;
      isLoadingLocation = false;
      _notify();
      return;
    }

    isLoadingLocation = true;
    _notify();
    _startLocationTracking();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isDisposed || _startTime == null) return;
      elapsedTime = DateTime.now().difference(_startTime!);
      _notify();
    });
  }

  void togglePause() {
    if (isFinished) return;
    if (isPaused) {
      isPaused = false;
      _startTime = DateTime.now().subtract(elapsedTime);
      _distanceAccumulator.resetBaseline();
      _lastAltitude = null;
      _startTimer();
    } else {
      isPaused = true;
      _timer?.cancel();
      elapsedTime = DateTime.now().difference(_startTime!);
    }
    _notify();
  }

  void stopTracking() {
    if (isFinished) return;
    isFinished = true;
    isPaused = true;
    _locationGeneration++;
    _timer?.cancel();
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  void _updateUserLocation(Position position) {
    final point = LatLng(position.latitude, position.longitude);
    userLocation = point;
    if (!isPaused) _updateProgress(point, position.altitude);
    try {
      mapController.move(point, 16);
    } on StateError {
      // The map controller may not be attached yet.
    }
    _notify();
  }

  void _updateProgress(LatLng point, double altitude) {
    _distanceAccumulator.addLocation(point);
    distanceKm = _distanceAccumulator.distanceMeters / 1000;

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
    UbicacionApp.enabled.removeListener(_onLocationPreferenceChanged);
    _timer?.cancel();
    _positionSubscription?.cancel();
    super.dispose();
  }
}
