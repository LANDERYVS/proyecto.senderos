import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/waypoints_sendero.dart';
import 'waypoints_mapa.dart';

// Presenta una ruta y sus puntos de interés sobre un mapa ajustado al trazado.
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
    // Mientras se preparan los datos, conserva el espacio previsto para el mapa.
    if (isLoading) {
      return SizedBox(
        height: height,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    // Un mapa necesita al menos dos coordenadas para dibujar un recorrido.
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

    // Amplía el área de la ruta para dejar espacio al desplazar el mapa.
    final panBounds = _boundsWithPanMargin(LatLngBounds.fromPoints(points));

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: height,
        child: FlutterMap(
          options: MapOptions(
            // Los minimapas comienzan mostrando el punto de partida del GPX.
            initialCenter: points.first,
            initialZoom: 14,
            cameraConstraint: CameraConstraint.contain(bounds: panBounds),
            minZoom: 5,
            maxZoom: 18,
          ),
          children: [
            // Usa la capa de mapas recibida o, si no se proporciona, OpenStreetMap.
            tileLayer ??
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'proyecto.senderos',
                ),
            // Dibuja el recorrido encima del mapa base.
            PolylineLayer(
              polylines: [
                Polyline(
                  points: points,
                  color: const Color(0xffff9800),
                  strokeWidth: 5,
                ),
              ],
            ),
            MarkerLayer(
              markers: [
                Marker(
                  width: 34,
                  height: 34,
                  point: points.first,
                  child: const Tooltip(
                    message: 'Inicio',
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color(0xff2e7d32),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  ),
                ),
                Marker(
                  width: 34,
                  height: 34,
                  point: points.last,
                  child: const Tooltip(
                    message: 'Llegada',
                    child: Icon(Icons.flag, color: Color(0xff2e7d32), size: 30),
                  ),
                ),
              ],
            ),
            // Coloca los marcadores de los puntos de interés sobre el trazado.
            WaypointMarkersLayer(waypoints: waypoints),
          ],
        ),
      ),
    );
  }

  // Añade un margen proporcional al recorrido y un mínimo para rutas muy cortas.
  LatLngBounds _boundsWithPanMargin(LatLngBounds routeBounds) {
    final latitudeSpan = routeBounds.north - routeBounds.south;
    final longitudeSpan = routeBounds.east - routeBounds.west;
    final latitudeMargin = math.max(latitudeSpan * 0.1, 0.001);
    final longitudeMargin = math.max(longitudeSpan * 0.1, 0.001);

    // Devuelve los límites extendidos para el encuadre y la restricción de cámara.
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
