import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../utils/route_calculator.dart';
import 'localizacion.dart';

class SeguirSenderoPage extends StatefulWidget {
  const SeguirSenderoPage({
    super.key,
    required this.routePoints,
    this.routeName,
  });

  final List<LatLng> routePoints;
  final String? routeName;

  @override
  State<SeguirSenderoPage> createState() => _SeguirSenderoPageState();
}

class _SeguirSenderoPageState extends State<SeguirSenderoPage> {
  final MapController _mapController = MapController();
  final LocalizacionService _localizacionService = LocalizacionService();
  final RouteCalculator _routeCalculator = RouteCalculator();
  final Distance _distanceCalculator = const Distance();
  StreamSubscription<Position>? _positionSubscription;
  Timer? _timer;

  LatLng? _userLocation;
  bool _isLoadingLocation = true;
  String? _locationError;
  Duration _elapsedTime = Duration.zero;
  double _distanceKm = 0;
  double _elevationGainMeters = 0;
  double _elevationLossMeters = 0;
  int _currentRouteIndex = 0;
  double? _lastAltitude;
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _startTime == null) return;
      setState(() {
        _elapsedTime = DateTime.now().difference(_startTime!);
      });
    });
    _startTracking();
  }

  Future<void> _startTracking() async {
    final granted = await _localizacionService.requestPermissionAndStartTracking();
    if (!mounted) return;

    if (!granted) {
      setState(() {
        _isLoadingLocation = false;
        _locationError = 'No se pudo acceder a la ubicación.';
      });
      return;
    }

    final currentPosition = await _localizacionService.getCurrentPosition();
    if (!mounted) return;

    if (currentPosition != null) {
      final point = LatLng(currentPosition.latitude, currentPosition.longitude);
      setState(() => _userLocation = point);
      _updateTrackingProgress(point, currentPosition.altitude);
      _mapController.move(point, 16);
    }

    setState(() => _isLoadingLocation = false);

    _positionSubscription = _localizacionService
        .getPositionStream(showNotification: false)
        .listen((position) {
          if (!mounted) return;
          final point = LatLng(position.latitude, position.longitude);
          setState(() {
            _userLocation = point;
            _updateTrackingProgress(point, position.altitude);
          });
          _mapController.move(point, 16);
        }, onError: (_) {
          if (!mounted) return;
          setState(() => _locationError = 'No se pudo actualizar la ubicación.');
        });
  }

  void _updateTrackingProgress(LatLng point, double altitude) {
    final route = widget.routePoints;
    if (route.isEmpty) return;

    var nearestIndex = 0;
    var nearestDistance = double.infinity;
    for (var i = 0; i < route.length; i++) {
      final distance = _distanceCalculator.as(LengthUnit.Meter, point, route[i]);
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestIndex = i;
      }
    }

    final distanceAlongRoute = _distanceAlongRouteUntil(nearestIndex);
    _distanceKm = distanceAlongRoute / 1000;
    _currentRouteIndex = nearestIndex;

    final validAltitude = altitude.isFinite ? altitude : null;
    if (validAltitude != null) {
      final previousAltitude = _lastAltitude;
      if (previousAltitude != null) {
        final delta = validAltitude - previousAltitude;
        if (delta > 0) {
          _elevationGainMeters += delta;
        } else if (delta < 0) {
          _elevationLossMeters += delta.abs();
        }
      }
      _lastAltitude = validAltitude;
    }
  }

  double _distanceAlongRouteUntil(int index) {
    if (widget.routePoints.length < 2 || index <= 0) return 0;

    var total = 0.0;
    for (var i = 0; i < index; i++) {
      total += _distanceCalculator.as(
        LengthUnit.Meter,
        widget.routePoints[i],
        widget.routePoints[i + 1],
      );
    }
    return total;
  }

  String get _formattedDuration {
    final hours = _elapsedTime.inHours.toString().padLeft(2, '0');
    final minutes = (_elapsedTime.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (_elapsedTime.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  LatLng _centerOf(List<LatLng> points) {
    final latitude = points.fold<double>(0, (sum, point) => sum + point.latitude);
    final longitude = points.fold<double>(0, (sum, point) => sum + point.longitude);
    return LatLng(latitude / points.length, longitude / points.length);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _positionSubscription?.cancel();
    _localizacionService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final routePoints = widget.routePoints;
    final initialCenter = routePoints.isNotEmpty
        ? _centerOf(routePoints)
        : (_userLocation ?? const LatLng(-34.6037, -58.3816));

    final markers = <Marker>[];
    if (_userLocation != null) {
      markers.add(
        Marker(
          width: 42,
          height: 42,
          point: _userLocation!,
          child: const Icon(Icons.navigation, color: Colors.blue, size: 32),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.routeName ?? 'Siguiendo sendero'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: initialCenter,
                    initialZoom: routePoints.isNotEmpty ? 15 : 13,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'proyecto.senderos',
                    ),
                    if (routePoints.length > 1)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: routePoints,
                            color: const Color(0xff4f8f3a),
                            strokeWidth: 6,
                          ),
                        ],
                      ),
                    if (markers.isNotEmpty) MarkerLayer(markers: markers),
                  ],
                ),
                if (_isLoadingLocation)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withOpacity(0.08),
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                  ),
                if (_locationError != null)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 24,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _locationError!,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            color: const Color(0xfff5f4ef),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _MetricColumn(label: 'TIEMPO', value: _formattedDuration),
                _MetricColumn(
                  label: 'DISTANCIA',
                  value: '${_distanceKm.toStringAsFixed(1)} km',
                ),
                _MetricColumn(
                  label: 'SUBIDA',
                  value: '${_elevationGainMeters.toStringAsFixed(0)} m',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricColumn extends StatelessWidget {
  const _MetricColumn({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ],
    );
  }
}
