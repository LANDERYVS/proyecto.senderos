import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class RoutePolylineMap extends StatelessWidget {
  const RoutePolylineMap({
    super.key,
    required this.points,
    this.height = 180,
    this.tileLayer,
    this.isLoading = false,
    this.hasError = false,
    this.unavailableMessage = 'El trayecto no está disponible',
  });

  final List<LatLng> points;
  final double? height;
  final TileLayer? tileLayer;
  final bool isLoading;
  final bool hasError;
  final String unavailableMessage;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return SizedBox(
        height: height,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (hasError || points.length < 2) {
      return Container(
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(unavailableMessage, textAlign: TextAlign.center),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: height,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: _centerOf(points),
            initialZoom: 14,
          ),
          children: [
            tileLayer ??
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

  LatLng _centerOf(List<LatLng> routePoints) {
    final latitude = routePoints.fold<double>(
      0,
      (sum, point) => sum + point.latitude,
    );
    final longitude = routePoints.fold<double>(
      0,
      (sum, point) => sum + point.longitude,
    );
    return LatLng(
      latitude / routePoints.length,
      longitude / routePoints.length,
    );
  }
}
