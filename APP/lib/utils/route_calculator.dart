import 'dart:math' as math;
import 'package:latlong2/latlong.dart';

class RouteCalculator {
  static const double _maxDistanceMeters = 40.0;
  static const double _latitudeScale = 111320.0;

  final Distance _distanceCalculator = const Distance();

  /// Encuentra el punto más cercano en la ruta a un punto dado
  /// Retorna null si no hay punto dentro de la distancia máxima (40 metros)
  LatLng? findNearestRoutePoint(LatLng targetPoint, List<LatLng> route) {
    if (route.length < 2) return null;

    LatLng? nearestPoint;
    var nearestDistance = double.infinity;

    final longitudeScale =
        _latitudeScale * math.cos(targetPoint.latitude * math.pi / 180);

    // Iterar sobre cada segmento de la ruta
    for (var index = 0; index < route.length - 1; index++) {
      final candidate = _findNearestPointOnSegment(
        targetPoint,
        route[index],
        route[index + 1],
        longitudeScale,
      );

      if (candidate == null) continue;

      final distance = _distanceCalculator.as(
        LengthUnit.Meter,
        targetPoint,
        candidate,
      );

      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestPoint = candidate;
      }
    }

    // Retorna null si está más lejos que la distancia máxima
    return nearestDistance <= _maxDistanceMeters ? nearestPoint : null;
  }

  /// Encuentra el punto más cercano en un segmento de línea a un punto dado
  LatLng? _findNearestPointOnSegment(
    LatLng point,
    LatLng segmentStart,
    LatLng segmentEnd,
    double longitudeScale,
  ) {
    // Convertir a coordenadas de Mercator
    final startX = segmentStart.longitude * longitudeScale;
    final startY = segmentStart.latitude * _latitudeScale;
    final endX = segmentEnd.longitude * longitudeScale;
    final endY = segmentEnd.latitude * _latitudeScale;
    final pointX = point.longitude * longitudeScale;
    final pointY = point.latitude * _latitudeScale;

    // Calcular deltas
    final deltaX = endX - startX;
    final deltaY = endY - startY;
    final segmentLengthSquared = deltaX * deltaX + deltaY * deltaY;

    // Calcular proyección del punto sobre la línea
    final projection = segmentLengthSquared == 0
        ? 0.0
        : ((pointX - startX) * deltaX + (pointY - startY) * deltaY) /
              segmentLengthSquared;

    // Clampar la proyección entre 0 y 1 (dentro del segmento)
    final clampedProjection = projection.clamp(0.0, 1.0);

    // Retornar el punto más cercano
    return LatLng(
      segmentStart.latitude +
          (segmentEnd.latitude - segmentStart.latitude) * clampedProjection,
      segmentStart.longitude +
          (segmentEnd.longitude - segmentStart.longitude) * clampedProjection,
    );
  }
}
