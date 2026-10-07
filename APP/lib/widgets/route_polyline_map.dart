import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/trail_waypoint.dart';
import '../utils/route_calculator.dart';
import 'waypoint_markers_layer.dart';

class RoutePolylineMap extends StatelessWidget {
  const RoutePolylineMap({
    super.key,
    required this.points,
    this.height = 180,
    this.tileLayer,
    this.isLoading = false,
    this.hasError = false,
    this.unavailableMessage = 'El trayecto no está disponible',
    this.waypoints = const [],
  });

  final List<LatLng> points;
  final double? height;
  final TileLayer? tileLayer;
  final bool isLoading;
  final bool hasError;
  final String unavailableMessage;
  final List<TrailWaypoint> waypoints;

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

    final panBounds = _boundsWithPanMargin(LatLngBounds.fromPoints(points));

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: height,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: RouteCalculator.centerOfPoints(points)!,
            initialZoom: 14,
            initialCameraFit: CameraFit.bounds(
              bounds: panBounds,
              padding: const EdgeInsets.all(24),
            ),
            cameraConstraint: CameraConstraint.contain(bounds: panBounds),
            minZoom: 5,
            maxZoom: 18,
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
                  color: const Color(0xffff9800),
                  strokeWidth: 5,
                ),
              ],
            ),
            WaypointMarkersLayer(waypoints: waypoints),
          ],
        ),
      ),
    );
  }

  LatLngBounds _boundsWithPanMargin(LatLngBounds routeBounds) {
    final latitudeSpan = routeBounds.north - routeBounds.south;
    final longitudeSpan = routeBounds.east - routeBounds.west;
    final latitudeMargin = math.max(latitudeSpan * 0.1, 0.001);
    final longitudeMargin = math.max(longitudeSpan * 0.1, 0.001);

    return LatLngBounds(
      LatLng(
        routeBounds.south - latitudeMargin,
        routeBounds.west - longitudeMargin,
      ),
      LatLng(
        routeBounds.north + latitudeMargin,
        routeBounds.east + longitudeMargin,
      ),
    );
  }
}
