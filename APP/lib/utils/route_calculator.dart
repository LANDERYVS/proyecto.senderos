// Aquí se reúnen funciones auxiliares.

import 'package:latlong2/latlong.dart';
// La clase RouteCalculator reúne los datos y las acciones de esta parte de la app.

class RouteCalculator {
  static const double _minimumMeaningfulDistanceMeters = 3.0;

  final Distance _distanceCalculator = const Distance();

  /// Devuelve la distancia real entre dos puntos, ignorando ruido GPS muy pequeño.
  // Calcula este valor a partir de los datos actuales.
  double calculateIncrementMeters(LatLng previousPoint, LatLng currentPoint) {
    final distanceMeters = _distanceCalculator.as(
      LengthUnit.Meter,
      previousPoint,
      currentPoint,
    );

    return distanceMeters < _minimumMeaningfulDistanceMeters
        ? 0.0
        : distanceMeters;
  }

  static LatLng? centerOfPoints(List<LatLng> points) {
    if (points.isEmpty) return null;

    final latitude = points.fold<double>(
      0,
      (sum, point) => sum + point.latitude,
    );
    final longitude = points.fold<double>(
      0,
      (sum, point) => sum + point.longitude,
    );
    return LatLng(latitude / points.length, longitude / points.length);
  }
}
// La clase RouteDistanceAccumulator reúne los datos y las acciones de esta parte de la app.

class RouteDistanceAccumulator {
  static const double _maximumLocationJumpMeters = 100;

  final RouteCalculator _routeCalculator = RouteCalculator();
  LatLng? _previousPoint;
  double distanceMeters = 0;
  // Agrega el nuevo elemento a la lista que muestra la pantalla.

  void addLocation(LatLng point) {
    final previousPoint = _previousPoint;
    _previousPoint = point;
    if (previousPoint == null) return;

    final incrementMeters = _routeCalculator.calculateIncrementMeters(
      previousPoint,
      point,
    );
    if (incrementMeters <= _maximumLocationJumpMeters) {
      distanceMeters += incrementMeters;
    }
  }

  void resetBaseline() {
    _previousPoint = null;
  }
}
