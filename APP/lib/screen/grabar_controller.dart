import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../services/offline_tile_service.dart';
import '../services/guardado_local.dart';
import '../utils/route_calculator.dart';
import '../widgets/save_route_dialog.dart';
import 'localizacion.dart';

class GrabarController extends ChangeNotifier {
  final MapController mapController = MapController();
  final RouteCalculator routeCalculator = RouteCalculator();
  final RouteStorageService routeStorageService = RouteStorageService();
  final OfflineTileService offlineTileService = OfflineTileService();
  final LocalizacionService localizacionService = LocalizacionService();
  final LatLng initialPosition = const LatLng(-37.3217, -59.1332);

  final List<LatLng> recordedRoute = [];
  final List<Marker> markers = [];
  final List<GrabarInterestPoint> interestPoints = [];

  StreamSubscription<Position>? positionSubscription;
  Timer? locationRefreshTimer;
  Timer? recordingTimer;
  Duration recordingDuration = Duration.zero;

  static const double userWeightKg = 70;
  static const double caloriesPerKgKm = 0.75;
  static const double minimumElevationChangeMeters = 2;

  bool isRecording = false;
  bool isPaused = false;
  double distanceKm = 0;
  double elevationGainMeters = 0;
  double elevationLossMeters = 0;
  double? _lastRecordedAltitude;
  String status = '';
  String recordingStatus = 'Inicia la grabación para comenzar tu trayecto';
  TileLayer? offlineTileLayer;

  Future<void> loadOfflineMap() async {
    if (!await offlineTileService.hasDownloadedTiles()) return;
    final layer = await offlineTileService.offlineTileLayer();
    offlineTileLayer = layer;
  }

  @override
  void dispose() {
    positionSubscription?.cancel();
    locationRefreshTimer?.cancel();
    recordingTimer?.cancel();
    localizacionService.dispose();
    super.dispose();
  }

  Future<void> requestPermissionAndStartTracking() async {
    final granted = await localizacionService
        .requestPermissionAndStartTracking();
    if (!granted) {
      status = 'Permiso de ubicación denegado';
      return;
    }

    await startLocationUpdates();
  }

  Future<void> startLocationUpdates() async {
    Position? position;
    try {
      position = await localizacionService.getCurrentPosition();
    } catch (error) {
      handleLocationError(error);
    }

    if (position == null) {
      status = '';
      return;
    }

    updateLocation(position);
    startLocationStream(showNotification: false);
  }

  void startLocationStream({required bool showNotification}) {
    positionSubscription?.cancel();
    positionSubscription = localizacionService
        .getPositionStream(showNotification: showNotification)
        .listen(updateLocation, onError: handleLocationError);

    locationRefreshTimer?.cancel();
    locationRefreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      refreshCurrentLocation();
    });
  }

  Future<void> refreshCurrentLocation() async {
    if ((!isRecording && positionSubscription == null)) return;

    try {
      final position = await localizacionService.getCurrentPosition();
      if (position != null) {
        updateLocation(position);
      }
    } catch (error) {
      handleLocationError(error);
    }
  }

  void handleLocationError(Object error) {
    status = 'Error de ubicación: $error';
  }

  void updateLocation(Position position) {
    final point = LatLng(position.latitude, position.longitude);
    markers
      ..clear()
      ..add(
        Marker(
          width: 60,
          height: 60,
          point: point,
          child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
        ),
      );

    if (isRecording && !isPaused) {
      if (recordedRoute.isNotEmpty) {
        final lastPoint = recordedRoute.last;
        final distanceMeters = routeCalculator.calculateIncrementMeters(
          lastPoint,
          point,
        );
        if (distanceMeters > 0) {
          distanceKm += distanceMeters / 1000;
          recordedRoute.add(point);
          _recordElevationChange(position.altitude);
          recordingStatus =
              'Grabando: ${distanceKm.toStringAsFixed(2)} km | '
              '${estimatedCalories.toStringAsFixed(0)} kcal';
        }
      } else {
        recordedRoute.add(point);
        _lastRecordedAltitude = _validAltitude(position.altitude);
        recordingStatus = 'Grabando trayecto...';
      }
    }

    try {
      mapController.move(point, 16);
    } on StateError {
      // The map controller may still be mounting on the first update.
    }
  }

  double get estimatedCalories => distanceKm * userWeightKg * caloriesPerKgKm;

  void _recordElevationChange(double altitude) {
    final validAltitude = _validAltitude(altitude);
    final previousAltitude = _lastRecordedAltitude;

    if (validAltitude == null || previousAltitude == null) return;

    final change = validAltitude - previousAltitude;
    if (change.abs() < minimumElevationChangeMeters) return;

    _lastRecordedAltitude = validAltitude;

    if (change > 0) {
      elevationGainMeters += change;
    } else {
      elevationLossMeters += change.abs();
    }
  }

  double? _validAltitude(double altitude) =>
      altitude.isFinite ? altitude : null;

  Future<void> toggleRecording() async {
    if (isRecording) {
      isRecording = false;
      isPaused = false;
      recordingStatus = 'Trayecto detenido con ${recordedRoute.length} puntos';
      positionSubscription?.cancel();
      positionSubscription = null;
      recordingTimer?.cancel();
    } else {
      recordedRoute.clear();
      distanceKm = 0;
      elevationGainMeters = 0;
      elevationLossMeters = 0;
      _lastRecordedAltitude = null;
      recordingDuration = Duration.zero;
      isRecording = true;
      isPaused = false;
      recordingStatus = 'Obteniendo ubicación...';
    }

    if (!isRecording) {
      positionSubscription?.cancel();
      positionSubscription = null;
      locationRefreshTimer?.cancel();
      locationRefreshTimer = null;
      return;
    }

    startLocationStream(showNotification: true);
    startRecordingTimer();
    await refreshCurrentLocation();
  }

  void startRecordingTimer() {
    recordingTimer?.cancel();
    recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!isRecording || isPaused) return;
      recordingDuration += const Duration(seconds: 1);
      notifyListeners();
    });
  }

  String get formattedDuration {
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    final hours = twoDigits(recordingDuration.inHours);
    final minutes = twoDigits(recordingDuration.inMinutes.remainder(60));
    final seconds = twoDigits(recordingDuration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  Future<void> finishAndSaveRoute(BuildContext context) async {
    if (recordedRoute.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay puntos para guardar')),
      );
      return;
    }

    final details = await showSaveRouteDialog(context);
    if (!context.mounted || details == null) return;

    try {
      final saved = await routeStorageService.saveRoute(
        points: recordedRoute,
        routeName: details.name,
        description: details.description,
        difficulty: details.difficulty,
        photos: details.photos,
        distanceKm: distanceKm,
        elevationGainMeters: elevationGainMeters,
        elevationLossMeters: elevationLossMeters,
      );
      if (saved && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Trayecto "${details.name}" guardado')),
        );
      }
    } on RoutePublishException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Guardado localmente. ${error.message}')),
        );
        debugPrint('Error al publicar sendero en Supabase: $error');
      }
    } on Exception catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'El sendero se guardó localmente, pero ocurrió un error inesperado',
            ),
          ),
        );
        debugPrint('Error al publicar sendero en Supabase: $error');
      }
    }
  }

  void togglePause() {
    if (!isRecording) return;

    isPaused = !isPaused;
    recordingStatus = isPaused
        ? 'Grabación pausada'
        : 'Grabando: ${distanceKm.toStringAsFixed(2)} km | '
              '${estimatedCalories.toStringAsFixed(0)} kcal';

    if (isPaused) {
      recordingTimer?.cancel();
    } else {
      startRecordingTimer();
    }
  }

  Future<void> addInterestPoint(BuildContext context, LatLng point) async {
    final routePoint = routeCalculator.findNearestRoutePoint(
      point,
      recordedRoute,
    );
    if (routePoint == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El punto debe estar sobre el camino trazado'),
        ),
      );
      return;
    }

    final nameController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Agregar punto de interés'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Nombre del lugar',
            hintText: 'Ej. Mirador',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, nameController.text),
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
    nameController.dispose();

    final trimmedName = name?.trim();
    if (!context.mounted || trimmedName == null || trimmedName.isEmpty) return;

    interestPoints.add(
      GrabarInterestPoint(point: routePoint, name: trimmedName),
    );
  }

  Future<bool> confirmExitIfRecording(BuildContext context) async {
    if (!isRecording) return true;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Seguro que quieres salir?'),
        content: const Text(
          'Hay un trayecto en grabación. Si sales, se perderá la ruta actual.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );

    return confirmed ?? false;
  }
}

class GrabarInterestPoint {
  const GrabarInterestPoint({required this.point, required this.name});

  final LatLng point;
  final String name;
}
