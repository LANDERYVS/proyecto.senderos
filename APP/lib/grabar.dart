import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'inicio.dart';
import 'localizacion.dart';
import 'navegacion.dart';
import 'perfil.dart';
import 'services/offline_tile_service.dart';
import 'services/route_storage_service.dart';
import 'utils/route_calculator.dart';
import 'widgets/save_route_dialog.dart';

class GrabarPage extends StatefulWidget {
  const GrabarPage({super.key});

  @override
  State<GrabarPage> createState() => _GrabarPageState();
}

class _GrabarPageState extends State<GrabarPage> {
  final MapController _mapController = MapController();
  final RouteCalculator _routeCalculator = RouteCalculator();
  final RouteStorageService _routeStorageService = RouteStorageService();
  final OfflineTileService _offlineTileService = OfflineTileService();
  final LatLng _initialPosition = const LatLng(-37.3217, -59.1332);
  final List<LatLng> _recordedRoute = [];
  final List<Marker> _markers = [];
  final List<_InterestPoint> _interestPoints = [];
  final LocalizacionService _localizacionService = LocalizacionService();

  StreamSubscription<Position>? _positionSubscription;
  Timer? _locationRefreshTimer;
  Timer? _recordingTimer;
  Duration _recordingDuration = Duration.zero;

  static const double _userWeightKg = 70;
  static const double _caloriesPerKgKm = 0.75;

  bool _isRecording = false;
  bool _isPaused = false;
  double _distanceKm = 0;
  String _status = '';
  String _recordingStatus = 'Inicia la grabación para comenzar tu trayecto';
  TileLayer? _offlineTileLayer;

  @override
  void initState() {
    super.initState();
    _loadOfflineMap();
    _requestPermissionAndStartTracking();
  }

  Future<void> _loadOfflineMap() async {
    if (!await _offlineTileService.hasDownloadedTiles()) return;
    final offlineTileLayer = await _offlineTileService.offlineTileLayer();
    if (!mounted) return;
    setState(() => _offlineTileLayer = offlineTileLayer);
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _locationRefreshTimer?.cancel();
    _recordingTimer?.cancel();
    _localizacionService.dispose();
    super.dispose();
  }

  Future<void> _requestPermissionAndStartTracking() async {
    final granted = await _localizacionService
        .requestPermissionAndStartTracking();
    if (!mounted) return;

    if (granted) {
      await _startLocationUpdates();
    } else {
      setState(() => _status = 'Permiso de ubicación denegado');
    }
  }

  Future<void> _startLocationUpdates() async {
    Position? position;
    try {
      position = await _localizacionService.getCurrentPosition();
    } catch (error) {
      _handleLocationError(error);
    }

    if (position == null) {
      if (mounted) {
        setState(() => _status = '');
      }
      return;
    }

    _updateLocation(position);
    _startLocationStream(showNotification: false);
  }

  void _startLocationStream({required bool showNotification}) {
    _positionSubscription?.cancel();
    _positionSubscription = _localizacionService
        .getPositionStream(showNotification: showNotification)
        .listen(_updateLocation, onError: _handleLocationError);

    _locationRefreshTimer?.cancel();
    _locationRefreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _refreshCurrentLocation();
    });
  }

  Future<void> _refreshCurrentLocation() async {
    if (!mounted || (!_isRecording && _positionSubscription == null)) return;

    try {
      final position = await _localizacionService.getCurrentPosition();
      if (position != null) _updateLocation(position);
    } catch (error) {
      _handleLocationError(error);
    }
  }

  void _handleLocationError(Object error) {
    if (!mounted) return;
    setState(() => _status = 'Error de ubicación: $error');
  }

  void _updateLocation(Position position) {
    if (!mounted) return;

    final point = LatLng(position.latitude, position.longitude);
    setState(() {
      _markers
        ..clear()
        ..add(
          Marker(
            width: 60,
            height: 60,
            point: point,
            child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
          ),
        );

      if (_isRecording && !_isPaused) {
        if (_recordedRoute.isNotEmpty) {
          final lastPoint = _recordedRoute.last;
          final distanceMeters = _routeCalculator.calculateIncrementMeters(
            lastPoint,
            point,
          );
          if (distanceMeters > 0) {
            _distanceKm += distanceMeters / 1000;
            _recordedRoute.add(point);
            _recordingStatus =
                'Grabando: ${_distanceKm.toStringAsFixed(2)} km | '
                '${_estimatedCalories.toStringAsFixed(0)} kcal';
          }
        } else {
          _recordedRoute.add(point);
          _recordingStatus = 'Grabando trayecto...';
        }
      }
    });

    try {
      _mapController.move(point, 16);
    } on StateError {
      // The map controller may still be mounting on the first update.
    }
  }

  double get _estimatedCalories =>
      _distanceKm * _userWeightKg * _caloriesPerKgKm;

  Future<void> _toggleRecording() async {
    setState(() {
      if (_isRecording) {
        _isRecording = false;
        _isPaused = false;
        _recordingStatus =
            'Trayecto detenido con ${_recordedRoute.length} puntos';
        _positionSubscription?.cancel();
        _positionSubscription = null;
        _recordingTimer?.cancel();
      } else {
        _recordedRoute.clear();
        _distanceKm = 0;
        _recordingDuration = Duration.zero;
        _isRecording = true;
        _isPaused = false;
        _recordingStatus = 'Obteniendo ubicación...';
      }
    });

    if (!_isRecording) {
      _positionSubscription?.cancel();
      _positionSubscription = null;
      _locationRefreshTimer?.cancel();
      _locationRefreshTimer = null;
      await _finishAndSaveRoute();
      return;
    }

    _startLocationStream(showNotification: true);
    _startRecordingTimer();
    await _refreshCurrentLocation();
  }

  void _startRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_isRecording || _isPaused) return;
      setState(() => _recordingDuration += const Duration(seconds: 1));
    });
  }

  String get _formattedDuration {
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    final hours = twoDigits(_recordingDuration.inHours);
    final minutes = twoDigits(_recordingDuration.inMinutes.remainder(60));
    final seconds = twoDigits(_recordingDuration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  Future<void> _finishAndSaveRoute() async {
    if (_recordedRoute.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay puntos para guardar')),
        );
      }
      return;
    }

    final details = await showSaveRouteDialog(context);
    if (!mounted || details == null) return;

    try {
      final saved = await _routeStorageService.saveRoute(
        points: _recordedRoute,
        routeName: details.name,
        description: details.description,
        difficulty: details.difficulty,
        photos: details.photos,
        distanceKm: _distanceKm,
      );
      if (saved && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Trayecto "${details.name}" guardado')),
        );
      }
    } on RoutePublishException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Guardado localmente. ${error.message}')),
        );
        debugPrint('Error al publicar sendero en Supabase: $error');
      }
    } on Exception catch (error) {
      if (mounted) {
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

  void _togglePause() {
    if (!_isRecording) return;

    setState(() {
      _isPaused = !_isPaused;
      _recordingStatus = _isPaused
          ? 'Grabación pausada'
          : 'Grabando: ${_distanceKm.toStringAsFixed(2)} km | '
                '${_estimatedCalories.toStringAsFixed(0)} kcal';
    });

    if (_isPaused) {
      _recordingTimer?.cancel();
    } else {
      _startRecordingTimer();
    }
  }

  Future<void> _addInterestPoint(LatLng point) async {
    final routePoint = _routeCalculator.findNearestRoutePoint(
      point,
      _recordedRoute,
    );
    if (routePoint == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('El punto debe estar sobre el camino trazado'),
          ),
        );
      }
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
    if (!mounted || trimmedName == null || trimmedName.isEmpty) return;

    setState(() {
      _interestPoints.add(_InterestPoint(point: routePoint, name: trimmedName));
    });
  }

  Future<bool> _confirmExitIfRecording() async {
    if (!_isRecording) return true;

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

  Future<void> _selectDestination(int index) async {
    if (index == 2) return;

    final shouldLeave = await _confirmExitIfRecording();
    if (!shouldLeave || !mounted) return;

    if (index == 4) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ProfilePage()),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => HomePage(initialIndex: index)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isRecording,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || !_isRecording) return;

        final navigator = Navigator.of(context);
        final shouldLeave = await _confirmExitIfRecording();
        if (!mounted || !shouldLeave) return;

        if (navigator.canPop()) {
          navigator.pop();
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _initialPosition,
                      initialZoom: 14,
                      onLongPress: (_, point) => _addInterestPoint(point),
                    ),
                    children: [
                      _offlineTileLayer ??
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.proyecto',
                          ),
                      MarkerLayer(markers: _markers),
                      MarkerLayer(
                        markers: [
                          for (final interestPoint in _interestPoints)
                            Marker(
                              width: 120,
                              height: 70,
                              point: interestPoint.point,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.place,
                                    color: Colors.deepPurple,
                                    size: 34,
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    color: Colors.white,
                                    child: Text(
                                      interestPoint.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      if (_recordedRoute.length > 1)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: _recordedRoute,
                              color: const Color(0xffec1768),
                              strokeWidth: 7,
                            ),
                          ],
                        ),
                      if (_recordedRoute.isNotEmpty)
                        MarkerLayer(
                          markers: [
                            if (_recordedRoute.length > 1)
                              Marker(
                                width: 42,
                                height: 48,
                                point: _recordedRoute.last,
                                child: const Icon(
                                  Icons.flag,
                                  color: Colors.red,
                                  size: 34,
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: Material(
                      color: Colors.white,
                      elevation: 3,
                      shape: const CircleBorder(),
                      child: IconButton(
                        tooltip: 'Centrar en mi ubicación',
                        onPressed: _markers.isEmpty
                            ? null
                            : () =>
                                  _mapController.move(_markers.first.point, 16),
                        icon: const Icon(Icons.my_location_outlined),
                        color: const Color(0xff4f683c),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              color: const Color(0xfffbfaf7),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _MetricIndicator(
                        label: 'TIEMPO',
                        value: _formattedDuration,
                      ),
                      _MetricIndicator(
                        label: 'DISTANCIA',
                        value: '${_distanceKm.toStringAsFixed(1)} km',
                        alignment: CrossAxisAlignment.end,
                      ),
                    ],
                  ),
                  if (_isRecording) ...[
                    const SizedBox(height: 5),
                    Text(
                      _recordingStatus,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 10,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (_isRecording)
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _togglePause,
                            icon: Icon(
                              _isPaused ? Icons.play_arrow : Icons.pause,
                            ),
                            label: Text(_isPaused ? 'Reanudar' : 'Pausar'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _toggleRecording,
                            icon: const Icon(Icons.stop),
                            label: const Text('Detener'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade700,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _toggleRecording,
                        icon: const Icon(Icons.play_arrow, size: 18),
                        label: const Text('Iniciar trayecto'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff4f683c),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                      ),
                    ),
                  if (_status.isNotEmpty && !_isRecording) ...[
                    const SizedBox(height: 6),
                    Text(
                      _status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: buildNavigationBar(
          selectedIndex: 2,
          onDestinationSelected: _selectDestination,
        ),
      ),
    );
  }
}

class _InterestPoint {
  const _InterestPoint({required this.point, required this.name});

  final LatLng point;
  final String name;
}

class _MetricIndicator extends StatelessWidget {
  const _MetricIndicator({
    required this.label,
    required this.value,
    this.alignment = CrossAxisAlignment.start,
  });

  final String label;
  final String value;
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Column(
          crossAxisAlignment: alignment,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                color: Color(0xff171916),
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
