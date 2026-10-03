import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../models/trail_waypoint.dart';

class WaypointMarkersLayer extends StatelessWidget {
  const WaypointMarkersLayer({super.key, required this.waypoints});

  final List<TrailWaypoint> waypoints;

  @override
  Widget build(BuildContext context) => MarkerLayer(
    markers: [
      for (final waypoint in waypoints)
        Marker(
          width: 16,
          height: 16,
          point: waypoint.point,
          child: Tooltip(
            message: waypoint.type,
            child: WaypointIcon(type: waypoint.type, size: 12),
          ),
        ),
    ],
  );
}

class WaypointIcon extends StatelessWidget {
  const WaypointIcon({
    super.key,
    required this.type,
    this.fallbackIcon,
    this.fallbackColor,
    this.size = 12,
  });

  final String type;
  final IconData? fallbackIcon;
  final Color? fallbackColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    final normalizedType = type.trim().toLowerCase();
    final asset = switch (normalizedType) {
      'vista' || 'mirador' => 'assets/waypoints/waypoint_mirador.png',
      'bebedero' => 'assets/waypoints/waypoint_bebedero.png',
      _ => null,
    };

    if (asset != null) {
      return Image.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Icon(
          fallbackIcon ?? _iconForType(normalizedType),
          color: fallbackColor ?? _colorForType(normalizedType),
          size: size,
        ),
      );
    }

    return Icon(
      fallbackIcon ?? _iconForType(normalizedType),
      color: fallbackColor ?? _colorForType(normalizedType),
      size: size,
    );
  }

  IconData _iconForType(String normalizedType) => switch (normalizedType) {
    'peligro' => Icons.warning_rounded,
    'descanso' => Icons.weekend_outlined,
    _ => Icons.place,
  };

  Color _colorForType(String normalizedType) => switch (normalizedType) {
    'peligro' => const Color(0xffd73737),
    'descanso' => const Color(0xff7650a2),
    _ => const Color(0xff4f8f3a),
  };
}
