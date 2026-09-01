import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'inicio.dart';
import 'localizacion.dart';
import 'navegacion.dart';
import 'perfil.dart';
import 'utils/route_calculator.dart';

class GrabarPage extends StatefulWidget {
  const GrabarPage({super.key});

  @override
  State<GrabarPage> createState() => _GrabarPageState();
}

class _GrabarPageState extends State<GrabarPage> {
  final MapController _mapController = MapController();
  final Distance _distanceCalculator = const Distance();
  final RouteCalculator _routeCalculator = RouteCalculator();
  final LatLng _initialPosition = const LatLng(20.6736, -103.344);
  final List<LatLng> _recordedRoute = [];
  final List<Marker> _markers = [];
  final List<_InterestPoint> _interestPoints = [];
  final LocalizacionService _localizacionService = LocalizacionService();

  StreamSubscription<Position>? _positionSubscription;
  static const double _userWeightKg = 70;
  static const double _caloriesPerKgKm = 0.75;
  bool _isRecording = false;
  bool _isPaused = false;
  double _distanceKm = 0;
  String _status = 'Esperando ubicación...';
  String _recordingStatus = 'Inicia la grabación para comenzar tu trayecto';

  @override
  void initState() {
    super.initState();
    _requestPermissionAndStartTracking();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
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
    final position = await _localizacionService.getCurrentPosition();

    if (position == null) {
      if (mounted) {
        setState(() => _status = 'Activa la ubicación del dispositivo');
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
        .listen(_updateLocation);
  }

  void _updateLocation(Position position) {
    if (!mounted) return;
    final point = LatLng(position.latitude, position.longitude);
    _mapController.move(point, 16);
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
        // Calcular distancia solo si hay puntos previos
        if (_recordedRoute.isNotEmpty) {
          final lastPoint = _recordedRoute.last;
          // Solo agregar si la distancia es mayor a 1 metro (para evitar ruido GPS)
          final distance = _distanceCalculator.as(
            LengthUnit.Kilometer,
            lastPoint,
            point,
          );
          if (distance > 0.001) {
            // 1 metro en km
            _distanceKm += distance;
            _recordedRoute.add(point);
          }
        } else {
          // Primer punto de la grabación
          _recordedRoute.add(point);
        }
        _recordingStatus =
            'Grabando: ${_distanceKm.toStringAsFixed(2)} km | '
            '${_estimatedCalories.toStringAsFixed(0)} kcal';
      }
    });
  }

  double get _estimatedCalories =>
      _distanceKm * _userWeightKg * _caloriesPerKgKm;

  void _toggleRecording() {
    setState(() {
      if (_isRecording) {
        _isRecording = false;
        _isPaused = false;
        _recordingStatus =
            'Trayecto detenido con ${_recordedRoute.length} puntos';
        // Detener notificación cuando se deja de grabar
        _startLocationStream(showNotification: false);
      } else {
        _recordedRoute.clear();
        _distanceKm = 0;
        _isRecording = true;
        _isPaused = false;
        _recordingStatus = 'Grabando trayecto...';
        // Mostrar notificación cuando se inicia grabación
        _startLocationStream(showNotification: true);
      }
    });
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

  void _selectDestination(int index) {
    if (index == 2) return;
    if (index == 4) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ProfilePage()),
      );
      return;
    }
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => HomePage(initialIndex: index)),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(title: const Text('Grabar trayecto')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(_status, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              children: [
                Text(_recordingStatus),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _MetricIndicator(
                      icon: Icons.directions_walk,
                      label: 'Distancia',
                      value: '${_distanceKm.toStringAsFixed(2)} km',
                      color: Colors.blue,
                    ),
                    _MetricIndicator(
                      icon: Icons.local_fire_department,
                      label: 'Calorías',
                      value: '${_estimatedCalories.toStringAsFixed(0)} kcal',
                      color: Colors.deepOrange,
                    ),
                  ],
                ),
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
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _toggleRecording,
                          icon: const Icon(Icons.stop),
                          label: const Text('Detener'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
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
                      icon: const Icon(Icons.fiber_manual_record),
                      label: const Text('Iniciar grabación'),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _initialPosition,
                initialZoom: 14,
                onLongPress: (_, point) => _addInterestPoint(point),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
                        color: Colors.blueAccent,
                        strokeWidth: 5,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: buildNavigationBar(
        selectedIndex: 2,
        onDestinationSelected: _selectDestination,
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
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            Text(value, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ],
    );
  }
}
