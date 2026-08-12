import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';

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
      home: const HomePage(),
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

  static const List<NavigationDestination> _destinations =
      <NavigationDestination>[
        NavigationDestination(
          icon: Icon(Icons.explore_outlined),
          selectedIcon: Icon(Icons.explore),
          label: 'Explorar',
        ),
        NavigationDestination(
          icon: Icon(Icons.map_outlined),
          selectedIcon: Icon(Icons.map),
          label: 'Mapas',
        ),
        NavigationDestination(
          icon: Icon(Icons.videocam_outlined),
          selectedIcon: Icon(Icons.videocam),
          label: 'Grabar',
        ),
        NavigationDestination(
          icon: Icon(Icons.groups_outlined),
          selectedIcon: Icon(Icons.groups),
          label: 'Comunidad',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Perfil',
        ),
      ];

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
      setState(() {
        _status = 'Activa la ubicación del dispositivo';
      });
      return;
    }

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

  Future<void> _refreshLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
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
    } catch (_) {
      setState(() {
        _status = 'No se pudo obtener la ubicación';
      });
    }
  }

  Future<void> _updateCamera(Position position) async {
    _mapController.move(LatLng(position.latitude, position.longitude), 16);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_destinations[_selectedIndex].label),
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
                ElevatedButton.icon(
                  onPressed: _refreshLocation,
                  icon: const Icon(Icons.my_location),
                  label: const Text('Actualizar ubicación'),
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: _destinations,
      ),
    );
  }
}
