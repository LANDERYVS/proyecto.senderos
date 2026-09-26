import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/compartir_ubicacion.dart';

class UbicacionAmigoPage extends StatefulWidget {
  const UbicacionAmigoPage({
    super.key,
    required this.friendId,
    required this.friendName,
  });

  final String friendId;
  final String friendName;

  @override
  State<UbicacionAmigoPage> createState() => _UbicacionAmigoPageState();
}

class _UbicacionAmigoPageState extends State<UbicacionAmigoPage> {
  final CompartirUbicacionService _locationService =
      CompartirUbicacionService();
  Timer? _refreshTimer;
  LatLng? _friendLocation;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLocation();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _loadLocation(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _locationService.dispose();
    super.dispose();
  }

  Future<void> _loadLocation() async {
    try {
      final location = await _locationService.getFriendLocation(
        widget.friendId,
      );
      if (!mounted) return;
      setState(() {
        _friendLocation = location;
        _isLoading = false;
      });
    } on Exception {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = _friendLocation;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.friendName),
        actions: [
          IconButton(
            onPressed: _loadLocation,
            tooltip: 'Actualizar ubicación',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(location),
    );
  }

  Widget _buildBody(LatLng? location) {
    if (_isLoading && location == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (location == null) {
      return const Center(
        child: Text('Este usuario todavía no ha compartido su ubicación.'),
      );
    }

    final map = FlutterMap(
      key: ValueKey('${location.latitude}_${location.longitude}'),
      options: MapOptions(initialCenter: location, initialZoom: 16),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'proyecto.senderos',
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: location,
              width: 80,
              height: 80,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_pin, color: Colors.red, size: 46),
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      widget.friendName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );

    return Column(children: [Expanded(child: map)]);
  }
}
