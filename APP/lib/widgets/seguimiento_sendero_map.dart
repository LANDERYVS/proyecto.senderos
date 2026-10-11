// Aquí se define un componente visual reutilizable.

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/waypoints_sendero.dart';
import 'waypoints_mapa.dart';
// La clase SeguimientoSenderoMap reúne los datos y las acciones de esta parte de la app.

class SeguimientoSenderoMap extends StatelessWidget {
  const SeguimientoSenderoMap({
    super.key,
    required this.mapController,
    required this.routePoints,
    required this.initialCenter,
    required this.userLocation,
    required this.isLoadingLocation,
    required this.isLoadingMap,
    required this.offlineOnly,
    required this.unavailableMessage,
    required this.onCenterOnUserLocation,
    this.tileLayer,
    this.initialZoom = 15,
    this.waypoints = const [],
  });

  final MapController mapController;
  final List<LatLng> routePoints;
  final LatLng initialCenter;
  final LatLng? userLocation;
  final bool isLoadingLocation;
  final bool isLoadingMap;
  final bool offlineOnly;
  final String unavailableMessage;
  final VoidCallback? onCenterOnUserLocation;
  final TileLayer? tileLayer;
  final double initialZoom;
  final List<TrailWaypoint> waypoints;
  // Construye la interfaz de esta pantalla con los datos y filtros actuales.

  @override
  Widget build(BuildContext context) {
    final statusMessage = isLoadingLocation
        ? 'Buscando señal GPS...'
        : isLoadingMap
        ? 'Cargando mapa descargado...'
        : offlineOnly && tileLayer == null
        ? unavailableMessage
        : null;

    return Stack(
      children: [
        FlutterMap(
          mapController: mapController,
          options: MapOptions(
            initialCenter: initialCenter,
            initialZoom: routePoints.isEmpty ? 13 : initialZoom,
          ),
          children: [
            tileLayer ??
                (offlineOnly
                    ? const ColoredBox(color: Color(0xffe8ece7))
                    : TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'proyecto.senderos',
                      )),
            if (routePoints.length > 1)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: routePoints,
                    color: const Color(0xffff9800),
                    strokeWidth: 6,
                  ),
                ],
              ),
            if (routePoints.length > 1)
              MarkerLayer(
                markers: [
                  Marker(
                    width: 44,
                    height: 44,
                    point: routePoints.first,
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
                          size: 34,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            if (routePoints.isNotEmpty)
              MarkerLayer(
                markers: [
                  Marker(
                    width: 44,
                    height: 44,
                    point: routePoints.last,
                    child: const Tooltip(
                      message: 'Llegada',
                      child: Icon(
                        Icons.flag,
                        color: Color(0xff2e7d32),
                        size: 38,
                      ),
                    ),
                  ),
                ],
              ),
            WaypointMarkersLayer(waypoints: waypoints),
            if (userLocation != null)
              MarkerLayer(
                markers: [
                  Marker(
                    width: 32,
                    height: 32,
                    point: userLocation!,
                    child: const Icon(
                      Icons.navigation,
                      color: Color(0xff1d4ed8),
                      size: 28,
                    ),
                  ),
                ],
              ),
          ],
        ),
        if (statusMessage != null)
          Positioned(
            top: 12,
            left: 16,
            right: 72,
            child: IgnorePointer(
              child: Material(
                color: Colors.white.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(8),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: isLoadingLocation || isLoadingMap
                      ? Row(
                          children: [
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Text(statusMessage)),
                          ],
                        )
                      : Text(statusMessage),
                ),
              ),
            ),
          ),
        Positioned(
          top: 16,
          right: 16,
          child: SafeArea(
            child: Material(
              color: Colors.white,
              elevation: 3,
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: 'Centrar en mi ubicación',
                onPressed: onCenterOnUserLocation,
                icon: const Icon(Icons.my_location_outlined),
                color: const Color(0xff4f8f3a),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
