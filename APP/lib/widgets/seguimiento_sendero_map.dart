import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

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
                    color: const Color(0xff4f8f3a),
                    strokeWidth: 6,
                  ),
                ],
              ),
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
          right: 16,
          bottom: 16,
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
      ],
    );
  }
}
