import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'grabar.dart';
import 'login.dart';
import 'navegacion.dart';
import 'perfil.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mapa en tiempo real',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      home: AuthGate(home: const HomePage()),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.tileProvider});

  final TileProvider? tileProvider;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final MapController _mapController = MapController();
  final LatLng _initialPosition = const LatLng(20.6736, -103.344);

  final List<Marker> _markers = [];
  String _status = 'Esperando ubicación...';
  StreamSubscription<Position>? _positionSubscription;
  int _selectedIndex = 0;

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
    // Solicitar permisos de ubicación
    final status = await Permission.location.request();
    if (!mounted) return;

    if (status.isGranted) {
      // En Android 12+, también solicitar permiso de ubicación en segundo plano
      await Permission.locationAlways.request();
      await _startLocationUpdates();
    } else {
      setState(() {
        _status = 'Permiso de ubicación denegado';
      });
    }
  }

  Future<void> _startLocationUpdates() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Intentar activar servicios de ubicación
      await Geolocator.openLocationSettings();
      setState(() {
        _status = 'Activa la ubicación del dispositivo';
      });
      return;
    }

    // Obtener posición actual
    final position = await Geolocator.getCurrentPosition();
    _updateCamera(position);

    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
          ),
        ).listen((position) {
          if (!mounted) return;
          _updateCamera(position);
          setState(() {
            _status =
                'Lat: ${position.latitude.toStringAsFixed(5)} | Lon: ${position.longitude.toStringAsFixed(5)}';
            _markers
              ..clear()
              ..add(
                Marker(
                  width: 60,
                  height: 60,
                  point: LatLng(position.latitude, position.longitude),
                  child: const Icon(
                    Icons.location_pin,
                    color: Colors.red,
                    size: 40,
                  ),
                ),
              );
          });
        });
  }

  Future<void> _updateCamera(Position position) async {
    _mapController.move(LatLng(position.latitude, position.longitude), 16);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(navigationDestinations[_selectedIndex].label),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _status,
                    style: Theme.of(context).textTheme.bodyMedium,
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
                  tileProvider: widget.tileProvider ?? NetworkTileProvider(),
                ),
                MarkerLayer(markers: _markers),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: buildNavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const GrabarPage()),
            );
            return;
          }
          if (index == 4) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfilePage()),
            );
            return;
          }
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }
}
