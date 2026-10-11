import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../models/waypoints_sendero.dart';

// Convierte los puntos de interés de una ruta en marcadores visibles sobre el mapa.
class WaypointMarkersLayer extends StatelessWidget {
  const WaypointMarkersLayer({super.key, required this.waypoints});

  final List<TrailWaypoint> waypoints;

  @override
  Widget build(BuildContext context) {
    return MarkerLayer(
      markers: [
        // Sitúa cada marcador en sus coordenadas y muestra su tipo al mantenerlo pulsado.
        for (final waypoint in waypoints)
          Marker(
            width: 24,
            height: 24,
            point: waypoint.point,
            child: Tooltip(
              message: waypoint.review.trim().isEmpty
                  ? waypoint.type
                  : '${waypoint.type}\n${waypoint.review.trim()}',
              child: WaypointIcon(type: waypoint.type, size: 20),
            ),
          ),
      ],
    );
  }
}

// Elige el símbolo del punto de interés según su tipo y admite estilos alternativos.
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
    // Normaliza el texto para que mayúsculas y espacios no afecten la selección del icono.
    final normalizedType = type.trim().toLowerCase();
    if (normalizedType == 'peligro' || normalizedType == 'descanso') {
      // Estos dos tipos se dibujan como insignias personalizadas en lugar de usar un icono estándar.
      return CustomPaint(
        size: Size.square(size),
        painter: _WaypointBadgePainter(
          color: normalizedType == 'peligro'
              ? const Color(0xfffa160d)
              : const Color(0xffff9872),
          isBridge: normalizedType == 'descanso',
        ),
      );
    }

    // Usa imágenes propias para los tipos que tienen un recurso gráfico dedicado.
    final asset = switch (normalizedType) {
      'vista' || 'mirador' => 'assets/waypoints/waypoint_mirador.png',
      'bebedero' => 'assets/waypoints/waypoint_bebedero.png',
      _ => null,
    };

    if (asset != null) {
      // Si el recurso no se encuentra o no puede cargarse, muestra un icono alternativo.
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

    // Los demás tipos se representan con un icono Material según su categoría.
    return Icon(
      fallbackIcon ?? _iconForType(normalizedType),
      color: fallbackColor ?? _colorForType(normalizedType),
      size: size,
    );
  }

  // Asigna un símbolo Material para cada categoría que no usa una imagen propia.
  IconData _iconForType(String normalizedType) => switch (normalizedType) {
    'peligro' => Icons.warning_rounded,
    'descanso' => Icons.weekend_outlined,
    _ => Icons.place,
  };

  // Mantiene un color coherente con la categoría del punto de interés.
  Color _colorForType(String normalizedType) => switch (normalizedType) {
    'peligro' => const Color(0xffd73737),
    'descanso' => const Color(0xff7650a2),
    _ => const Color(0xff4f8f3a),
  };
}

// Dibuja las insignias circulares de peligro y descanso usando formas vectoriales.
class _WaypointBadgePainter extends CustomPainter {
  const _WaypointBadgePainter({required this.color, required this.isBridge});

  final Color color;
  final bool isBridge;

  @override
  void paint(Canvas canvas, Size size) {
    // Adapta el círculo y su borde al tamaño disponible para el marcador.
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;
    canvas.drawCircle(center, radius, Paint()..color = Colors.white);
    canvas.drawCircle(center, radius * 0.86, Paint()..color = color);

    if (isBridge) {
      _paintBridge(canvas, size);
    } else {
      _paintDanger(canvas, size);
    }
  }

  // Dibuja el signo de advertencia en blanco dentro de la insignia de peligro.
  void _paintDanger(Canvas canvas, Size size) {
    final whitePaint = Paint()..color = Colors.white;
    final centerX = size.width / 2;
    final unit = size.shortestSide;
    final stem = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(centerX, size.height * 0.42),
        width: unit * 0.105,
        height: unit * 0.48,
      ),
      Radius.circular(unit * 0.025),
    );
    canvas.drawRRect(stem, whitePaint);
    canvas.drawCircle(
      Offset(centerX, size.height * 0.72),
      unit * 0.055,
      whitePaint,
    );
  }

  // Compone una ilustración de puente con trazos blancos dentro de la insignia.
  void _paintBridge(Canvas canvas, Size size) {
    final unit = size.shortestSide;
    final whitePaint = Paint()..color = Colors.white;
    final supportWidth = unit * 0.09;
    final leftSupport = size.width * 0.28;
    final rightSupport = size.width * 0.72;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          leftSupport,
          size.height * 0.25,
          rightSupport - leftSupport,
          unit * 0.085,
        ),
        Radius.circular(unit * 0.035),
      ),
      whitePaint,
    );
    for (final x in [leftSupport, rightSupport - supportWidth]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            x,
            size.height * 0.22,
            supportWidth,
            size.height * 0.34,
          ),
          Radius.circular(unit * 0.035),
        ),
        whitePaint,
      );
    }

    for (final fraction in [0.39, 0.50, 0.61]) {
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(size.width * fraction, size.height * 0.43),
          width: unit * 0.07,
          height: unit * 0.19,
        ),
        whitePaint,
      );
    }

    final deck = Path()
      ..moveTo(size.width * 0.20, size.height * 0.56)
      ..lineTo(size.width * 0.28, size.height * 0.48)
      ..lineTo(size.width * 0.72, size.height * 0.48)
      ..lineTo(size.width * 0.80, size.height * 0.56)
      ..lineTo(size.width * 0.80, size.height * 0.59)
      ..lineTo(size.width * 0.20, size.height * 0.59)
      ..close();
    canvas.drawPath(deck, whitePaint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.20,
          size.height * 0.61,
          size.width * 0.60,
          unit * 0.075,
        ),
        Radius.circular(unit * 0.025),
      ),
      whitePaint,
    );
    for (final x in [size.width * 0.29, size.width * 0.66]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            x,
            size.height * 0.66,
            unit * 0.075,
            size.height * 0.14,
          ),
          Radius.circular(unit * 0.025),
        ),
        whitePaint,
      );
    }
  }

  @override
  // Solo vuelve a dibujar la insignia si cambian su color o su forma.
  bool shouldRepaint(_WaypointBadgePainter oldDelegate) =>
      color != oldDelegate.color || isBridge != oldDelegate.isBridge;
}
