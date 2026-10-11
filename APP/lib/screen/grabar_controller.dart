// Aquí se implementa una pantalla de la app.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../services/ubicacion_app.dart';
import '../services/offline_tile_service.dart';
import '../services/guardado_local.dart';
import '../services/walking_stats_service.dart';
import '../utils/route_calculator.dart';
import '../widgets/dialogo_salir_ruta.dart';
import '../widgets/dialogo_guardado.dart';
import 'grabar_styles.dart';
import 'localizacion.dart';
// Esta enumeración lista las opciones disponibles para esta función.

enum GrabarMarkerType {
  mirador(
    'Mirador',
    'vista',
    Icons.camera_alt_outlined,
    GrabarStyles.primaryGreen,
  ),
  bebedero(
    'Bebedero',
    'Bebedero',
    Icons.water_drop_outlined,
    GrabarStyles.primaryGreen,
  ),
  peligro('Peligro', 'peligro', Icons.warning_rounded, Color(0xffd73737)),
  descanso('Descanso', 'descanso', Icons.weekend_outlined, Color(0xff7650a2));

  const GrabarMarkerType(this.label, this.databaseType, this.icon, this.color);

  final String label;
  final String databaseType;
  final IconData icon;
  final Color color;
}

// Controla la grabación del recorrido: GPS, distancia, duración, desnivel y puntos de interés.

class GrabarController extends ChangeNotifier {
  GrabarController() {
    UbicacionApp.enabled.addListener(_onLocationPreferenceChanged);
  }

  final MapController mapController = MapController();
  final RouteCalculator routeCalculator = RouteCalculator();
  final RouteStorageService routeStorageService = RouteStorageService();
  final OfflineTileService offlineTileService = OfflineTileService();
  final LocalizacionService localizacionService = LocalizacionService();
  final WalkingStatsService walkingStatsService = WalkingStatsService();
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
  static const double minimumWaypointDistanceMeters = 15;

  bool isRecording = false;
  bool isPaused = false;
  bool get canAddWaypoint => isRecording && !isPaused;
  bool _hasCenteredOnInitialLocation = false;
  int _locationGeneration = 0;
  double distanceKm = 0;
  bool _walkingDistanceRecorded = false;
  double elevationGainMeters = 0;
  double elevationLossMeters = 0;
  double? _lastRecordedAltitude;
  String status = '';
  String recordingStatus = 'Inicia la grabación para comenzar tu trayecto';
  TileLayer? offlineTileLayer;
  // Prepara la capa del mapa sin conexión cuando hay mapas descargados.

  Future<void> loadOfflineMap() async {
    if (!await offlineTileService.hasDownloadedTiles()) return;
    final layer = await offlineTileService.offlineTileLayer();
    offlineTileLayer = layer;
  }
  // Al salir de esta pantalla, se cancelan las tareas activas y se liberan sus recursos.

  @override
  void dispose() {
    UbicacionApp.enabled.removeListener(_onLocationPreferenceChanged);
    positionSubscription?.cancel();
    locationRefreshTimer?.cancel();
    recordingTimer?.cancel();
    super.dispose();
  }
  // Pide permiso para usar el GPS y comienza a seguir la ubicación.

  Future<void> requestPermissionAndStartTracking() async {
    final generation = ++_locationGeneration;
    if (!UbicacionApp.enabled.value) {
      status = 'Ubicación pausada desde Configuración';
      notifyListeners();
      return;
    }

    final granted = await localizacionService
        .requestPermissionAndStartTracking();
    if (generation != _locationGeneration || !UbicacionApp.enabled.value) {
      return;
    }
    if (!granted) {
      status = 'Permiso de ubicación denegado';
      notifyListeners();
      return;
    }

    if (isRecording) {
      startLocationStream(showNotification: true);
      await refreshCurrentLocation();
    } else {
      await startLocationUpdates();
    }
  }
  // Obtiene la ubicación actual y después deja activo el seguimiento por GPS.

  Future<void> startLocationUpdates() async {
    if (!UbicacionApp.enabled.value) return;
    final generation = _locationGeneration;
    Position? position;
    try {
      position = await localizacionService.getCurrentPosition();
    } catch (error) {
      handleLocationError(error);
    }

    if (generation != _locationGeneration || !UbicacionApp.enabled.value) {
      return;
    }
    if (position == null) {
      status = '';
      return;
    }

    updateLocation(position);
    startLocationStream(showNotification: false);
  }
  // Inicia el proceso necesario para esta función.

  void startLocationStream({required bool showNotification}) {
    if (!UbicacionApp.enabled.value) return;
    positionSubscription?.cancel();
    positionSubscription = localizacionService
        .getPositionStream(showNotification: showNotification)
        .listen((position) {
          if (UbicacionApp.enabled.value) updateLocation(position);
        }, onError: handleLocationError);

    locationRefreshTimer?.cancel();
    locationRefreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      refreshCurrentLocation();
    });
  }
  // Vuelve a cargar los datos para reflejar los cambios más recientes.

  Future<void> refreshCurrentLocation() async {
    if (!UbicacionApp.enabled.value ||
        (!isRecording && positionSubscription == null)) {
      return;
    }

    try {
      final position = await localizacionService.getCurrentPosition();
      if (position != null && UbicacionApp.enabled.value) {
        updateLocation(position);
      }
    } catch (error) {
      if (UbicacionApp.enabled.value) handleLocationError(error);
    }
  }

  void _onLocationPreferenceChanged() {
    if (!UbicacionApp.enabled.value) {
      _locationGeneration++;
      positionSubscription?.cancel();
      positionSubscription = null;
      locationRefreshTimer?.cancel();
      locationRefreshTimer = null;
      markers.clear();
      status = 'Ubicación pausada desde Configuración';
      if (isRecording) {
        recordingStatus = 'GPS pausado desde Configuración';
      }
      notifyListeners();
      return;
    }

    if (isRecording) recordingStatus = 'Obteniendo ubicación...';
    unawaited(requestPermissionAndStartTracking());
  }
  // Este bloque maneja un error o evento del sistema para evitar que la app se rompa.

  void handleLocationError(Object error) {
    status = 'No hay conexión a internet.';
  }
  // Actualiza los datos existentes con la información nueva.

  void updateLocation(Position position) {
    final point = LatLng(position.latitude, position.longitude);
    markers
      ..clear()
      ..add(
        Marker(
          width: 46,
          height: 46,
          point: point,
          child: GrabarStyles.currentLocationMarker(size: 28),
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

    if (!_hasCenteredOnInitialLocation) {
      try {
        mapController.move(point, 16);
        _hasCenteredOnInitialLocation = true;
      } on StateError {
        // The map controller may still be mounting on the first update.
      }
    }
  }
  // Agrega el nuevo elemento a la lista que muestra la pantalla.

  Future<void> addCurrentLocationMarker(
    BuildContext context,
    GrabarMarkerType type,
  ) async {
    if (!_requireActiveRecordingForWaypoint(context)) return;
    if (markers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esperá a que se obtenga tu ubicación GPS.'),
        ),
      );
      return;
    }

    final point = markers.first.point;
    if (_hasWaypointNear(point)) {
      _showExistingWaypointMessage(context);
      return;
    }

    final details = await _showWaypointDetailsDialog(
      context,
      initialName: type.label,
    );
    if (!context.mounted || details == null) return;

    interestPoints.add(
      GrabarInterestPoint(
        point: point,
        name: details.name,
        review: details.review,
        type: type,
      ),
    );
    notifyListeners();
  }

  double get estimatedCalories => distanceKm * userWeightKg * caloriesPerKgKm;
  bool get hasUnrecordedWalk => !_walkingDistanceRecorded && distanceKm > 0;
  // Añade al recorrido la ubicación o métrica recibida del GPS.

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

  bool _hasWaypointNear(LatLng point) => interestPoints.any(
    (waypoint) =>
        routeCalculator.calculateIncrementMeters(waypoint.point, point) <=
        minimumWaypointDistanceMeters,
  );
  // Muestra al usuario las opciones o el aviso que corresponde a esta acción.

  void _showExistingWaypointMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Debe haber al menos 15 metros entre waypoints.'),
      ),
    );
  }

  bool _requireActiveRecordingForWaypoint(BuildContext context) {
    if (canAddWaypoint) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Inicia o reanuda la grabación para agregar waypoints.'),
      ),
    );
    return false;
  }

  double? _validAltitude(double altitude) =>
      altitude.isFinite ? altitude : null;
  // Cambia entre activar y desactivar esta función.

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
      _walkingDistanceRecorded = false;
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

    if (UbicacionApp.enabled.value) {
      startLocationStream(showNotification: true);
    }
    startRecordingTimer();
    if (UbicacionApp.enabled.value) await refreshCurrentLocation();
  }
  // Inicia el proceso necesario para esta función.

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
  // Termina este proceso y guarda el resultado cuando corresponde.

  Future<void> finishAndSaveRoute(BuildContext context) async {
    if (recordedRoute.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay puntos para guardar')),
      );
      return;
    }

    try {
      if (!_walkingDistanceRecorded) {
        await walkingStatsService.recordCompletedWalk(distanceKm: distanceKm);
        _walkingDistanceRecorded = distanceKm > 0;
      }
    } on WalkingStatsException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
      debugPrint('No se pudieron registrar los kilómetros caminados: $error');
      return;
    }

    if (!context.mounted) return;
    final details = await showSaveRouteDialog(
      context,
      duration: formattedDuration,
      distanceKm: distanceKm,
      elevationGainMeters: elevationGainMeters,
    );
    if (!context.mounted || details == null) return;

    try {
      final saved = await routeStorageService.saveRoute(
        points: recordedRoute,
        routeName: details.name,
        description: details.description,
        sport: details.sport,
        difficulty: details.difficulty,
        photos: details.photos,
        distanceKm: distanceKm,
        elevationGainMeters: elevationGainMeters,
        elevationLossMeters: elevationLossMeters,
        waypoints: [
          for (final waypoint in interestPoints)
            {
              'type': waypoint.type.databaseType,
              'lat': waypoint.point.latitude,
              'long': waypoint.point.longitude,
              'review': waypoint.review,
            },
        ],
      );
      if (saved && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Trayecto "${details.name}" guardado y kilómetros registrados',
            ),
          ),
        );
      }
    } on WalkingStatsException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
      debugPrint('No se pudieron registrar los kilómetros caminados: $error');
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
  // Cambia entre activar y desactivar esta función.

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
  Future<_WaypointDetails?> _showWaypointDetailsDialog(
    BuildContext context, {
    String? initialName,
  }) async {
    final nameController = TextEditingController(text: initialName);
    final reviewController = TextEditingController();
    try {
      return await showDialog<_WaypointDetails>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Agregar punto de interés'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: initialName == null,
                readOnly: initialName != null,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nombre del lugar',
                  hintText: 'Ej. Mirador',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reviewController,
                textCapitalization: TextCapitalization.sentences,
                maxLength: 300,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Reseña (opcional)',
                  hintText: 'Describe este lugar o comparte una recomendación',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(
                  dialogContext,
                  _WaypointDetails(
                    name: name,
                    review: reviewController.text.trim(),
                  ),
                );
              },
              child: const Text('Agregar'),
            ),
          ],
        ),
      );
    } finally {
      nameController.dispose();
      reviewController.dispose();
    }
  }
  // Pide confirmación antes de continuar con esta acción.

  Future<bool> confirmExitIfRecording(BuildContext context) async {
    if (!isRecording) {
      if (!hasUnrecordedWalk) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Los kilómetros de la caminata están pendientes. '
            'Reintenta guardarlos antes de salir.',
          ),
        ),
      );
      return false;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => ConfirmExitRecordingDialog(
        title: '¿Salir sin guardar?',
        message:
            'La grabación sigue en curso. Si sales, perderás el recorrido.',
        summary:
            '$formattedDuration · ${distanceKm.toStringAsFixed(1)} km · '
            '+${elevationGainMeters.toStringAsFixed(0)} m',
        continueLabel: 'Seguir grabando',
        exitLabel: 'Salir y descartar',
        onContinue: () => Navigator.pop(dialogContext, false),
        onExit: () => Navigator.pop(dialogContext, true),
      ),
    );

    return confirmed ?? false;
  }
}
// La clase GrabarInterestPoint reúne los datos y las acciones de esta parte de la app.

class GrabarInterestPoint {
  const GrabarInterestPoint({
    required this.point,
    required this.name,
    required this.type,
    this.review = '',
  });

  final LatLng point;
  final String name;
  final String review;
  final GrabarMarkerType type;
}

class _WaypointDetails {
  const _WaypointDetails({required this.name, required this.review});

  final String name;
  final String review;
}
