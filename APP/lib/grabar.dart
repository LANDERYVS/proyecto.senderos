import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'navegacion.dart';
import 'perfil.dart';

class GrabarPage extends StatefulWidget {
  const GrabarPage({super.key});

  @override
  State<GrabarPage> createState() => _GrabarPageState();
}

class _GrabarPageState extends State<GrabarPage> {
  final MapController _mapController = MapController();
  final Distance _distanceCalculator = const Distance();
  final LatLng _initialPosition = const LatLng(20.6736, -103.344);
  final List<LatLng> _recordedRoute = [];
  final List<Marker> _markers = [];

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
    super.dispose();
  }

  Future<void> _requestPermissionAndStartTracking() async {
    final status = await Permission.location.request();
    if (!mounted) return;

    if (status.isGranted) {
      await Permission.locationAlways.request();
      await _startLocationUpdates();
    } else {
      setState(() => _status = 'Permiso de ubicación denegado');
    }
  }

  Future<void> _startLocationUpdates() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      await Geolocator.openLocationSettings();
      if (mounted) {
        setState(() => _status = 'Activa la ubicación del dispositivo');
      }
      return;
    }

    final position = await Geolocator.getCurrentPosition();
    _updateLocation(position);
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen(_updateLocation);
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
        if (_recordedRoute.isNotEmpty) {
          _distanceKm += _distanceCalculator.as(
            LengthUnit.Kilometer,
            _recordedRoute.last,
            point,
          );
        }
        _recordedRoute.add(point);
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
      } else {
        _recordedRoute.clear();
        _distanceKm = 0;
        _isRecording = true;
        _isPaused = false;
        _recordingStatus = 'Grabando trayecto...';
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

  void _selectDestination(int index) {
    if (index == 4) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProfilePage()),
      );
    } else if (index != 2) {
      Navigator.pop(context);
    }
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
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.proyecto',
                ),
                MarkerLayer(markers: _markers),
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
