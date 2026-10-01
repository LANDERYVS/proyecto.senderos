import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'seguimiento_sendero_screen.dart';

class SeguirSenderoPage extends StatelessWidget {
  const SeguirSenderoPage({
    super.key,
    required this.routePoints,
    this.routeName,
    this.offlineRegionId,
    this.senderoId,
  });

  final List<LatLng> routePoints;
  final String? routeName;
  final String? offlineRegionId;
  final int? senderoId;

  @override
  Widget build(BuildContext context) => SeguimientoSenderoScreen(
    routePoints: routePoints,
    title: routeName ?? 'Siguiendo sendero',
    exitMessage:
        'El seguimiento del sendero se detendrá y se perderá el progreso actual.',
    unavailableMapMessage: 'Mapa offline no disponible',
    offlineRegionId: offlineRegionId,
    senderoId: senderoId,
  );
}
