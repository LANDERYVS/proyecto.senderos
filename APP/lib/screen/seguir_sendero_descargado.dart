import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../models/trail_waypoint.dart';
import 'seguimiento_sendero_screen.dart';

class SeguirSenderoDescargadoPage extends StatelessWidget {
  const SeguirSenderoDescargadoPage({
    super.key,
    required this.routePoints,
    required this.routeName,
    required this.offlineRegionId,
    this.senderoId,
    this.waypoints = const [],
  });

  final List<LatLng> routePoints;
  final String routeName;
  final String offlineRegionId;
  final int? senderoId;
  final List<TrailWaypoint> waypoints;

  @override
  Widget build(BuildContext context) => SeguimientoSenderoScreen(
    routePoints: routePoints,
    title: routeName,
    exitMessage: 'El seguimiento del sendero se detendrá.',
    unavailableMapMessage: 'No hay mapa descargado para esta ruta',
    offlineRegionId: offlineRegionId,
    senderoId: senderoId,
    waypoints: waypoints,
  );
}
