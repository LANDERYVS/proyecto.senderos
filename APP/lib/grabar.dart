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
  final LatLng _initialPosition = const LatLng(20.6736, -103.344);
  final List<LatLng> _recordedRoute = [];
  final List<Marker> _markers = [];

  StreamSubscription<Position>? _positionSubscription;
  bool _isRecording = false;
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
      _status =
          'Lat: ${position.latitude.toStringAsFixed(5)} | Lon: ${position.longitude.toStringAsFixed(5)}';
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
      if (_isRecording) {
        _recordedRoute.add(point);
        _recordingStatus = 'Grabando trayecto: ${_recordedRoute.length} puntos';
      }
    });
  }

  void _toggleRecording() {
    setState(() {
      if (_isRecording) {
        _isRecording = false;
        _recordingStatus =
            'Trayecto detenido con ${_recordedRoute.length} puntos';
      } else {
        _recordedRoute.clear();
        _isRecording = true;
        _recordingStatus = 'Grabando trayecto...';
      }
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
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _toggleRecording,
                    icon: Icon(
                      _isRecording ? Icons.stop : Icons.fiber_manual_record,
                    ),
                    label: Text(
                      _isRecording ? 'Detener grabación' : 'Iniciar grabación',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isRecording ? Colors.red : null,
                    ),
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
