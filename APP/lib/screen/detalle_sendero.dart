import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:xml/xml.dart';

import '../models/explore_trail.dart';

class DetalleSenderoScreen extends StatefulWidget {
  const DetalleSenderoScreen({super.key, required this.trail});

  final ExploreTrail trail;

  @override
  State<DetalleSenderoScreen> createState() => _DetalleSenderoScreenState();
}

class _DetalleSenderoScreenState extends State<DetalleSenderoScreen> {
  List<LatLng> _routePoints = const [];
  bool _isLoadingRoute = true;
  String? _routeError;

  @override
  void initState() {
    super.initState();
    _loadRoute();
  }

  Future<void> _loadRoute() async {
    final url = widget.trail.gpxUrl;
    if (url == null) {
      setState(() => _isLoadingRoute = false);
      return;
    }

    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('HTTP ${response.statusCode}', uri: Uri.parse(url));
      }
      final document = XmlDocument.parse(await response.transform(const Utf8Decoder()).join());
      final points = document
          .findAllElements('trkpt')
          .map((element) {
            final latitude = double.tryParse(element.getAttribute('lat') ?? '');
            final longitude = double.tryParse(element.getAttribute('lon') ?? '');
            return latitude != null && longitude != null
                ? LatLng(latitude, longitude)
                : null;
          })
          .whereType<LatLng>()
          .toList();
      client.close();
      if (!mounted) return;
      setState(() {
        _routePoints = points;
        _isLoadingRoute = false;
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingRoute = false;
        _routeError = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Información del sendero')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Container(
                height: 220,
                width: double.infinity,
                color: const Color(0xffeaf5df),
                  child: widget.trail.photoUrl == null
                    ? Image.asset('assets/arbol.jpg', fit: BoxFit.contain)
                    : Image.network(
                      widget.trail.photoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, error, stackTrace) => Image.asset(
                          'assets/arbol.jpg',
                          fit: BoxFit.contain,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.trail.name,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Publicado por: ${widget.trail.author}',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            _TrailInfo(
              difficulty: widget.trail.difficulty,
              distance: '${widget.trail.distanceKm.toStringAsFixed(1)} km',
              elevation: widget.trail.elevation,
            ),
            const SizedBox(height: 24),
            Text(
              'Trayecto',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            _RouteMap(
              points: _routePoints,
              isLoading: _isLoadingRoute,
              hasError: _routeError != null,
            ),
            const SizedBox(height: 24),
            Text(
              'Descripción',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.trail.description.isEmpty
                  ? 'Este sendero no tiene una descripción.'
                : widget.trail.description,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteMap extends StatelessWidget {
  const _RouteMap({
    required this.points,
    required this.isLoading,
    required this.hasError,
  });

  final List<LatLng> points;
  final bool isLoading;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox(
        height: 180,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (points.length < 2 || hasError) {
      return Container(
        height: 180,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text('El trayecto no está disponible'),
      );
    }

    final center = _centerOf(points);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 180,
        child: FlutterMap(
          options: MapOptions(initialCenter: center, initialZoom: 14),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'proyecto.senderos',
            ),
            PolylineLayer(
              polylines: [
                Polyline(
                  points: points,
                  color: const Color(0xff4f8f3a),
                  strokeWidth: 5,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  LatLng _centerOf(List<LatLng> points) {
    final latitude = points.fold<double>(0, (sum, point) => sum + point.latitude);
    final longitude = points.fold<double>(0, (sum, point) => sum + point.longitude);
    return LatLng(latitude / points.length, longitude / points.length);
  }
}

class _TrailInfo extends StatelessWidget {
  const _TrailInfo({
    required this.difficulty,
    required this.distance,
    required this.elevation,
  });

  final String difficulty;
  final String distance;
  final String elevation;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _InfoItem(
            icon: Icons.terrain,
            label: 'Dificultad',
            value: difficulty,
          ),
        ),
        Expanded(
          child: _InfoItem(
            icon: Icons.straighten,
            label: 'Distancia',
            value: distance,
          ),
        ),
        Expanded(
          child: _InfoItem(
            icon: Icons.height,
            label: 'Desnivel',
            value: elevation,
          ),
        ),
      ],
    );
  }
}

class _InfoItem extends StatelessWidget {
  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 22),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}