import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:proyecto/utils/route_calculator.dart';

void main() {
  group('RouteCalculator distance filtering', () {
    test('ignora desplazamientos menores a 3 metros por ruido del GPS', () {
      final calculator = RouteCalculator();
      final base = const LatLng(-37.3217, -59.1332);
      final noisyPoint = LatLng(base.latitude + 0.00001, base.longitude);

      expect(calculator.calculateIncrementMeters(base, noisyPoint), 0.0);
    });

    test('cuenta desplazamientos reales mayores a 3 metros', () {
      final calculator = RouteCalculator();
      final base = const LatLng(-37.3217, -59.1332);
      final movedPoint = LatLng(base.latitude + 0.00005, base.longitude);

      expect(
        calculator.calculateIncrementMeters(base, movedPoint) > 3.0,
        isTrue,
      );
    });

    test('la distancia del seguimiento comienza en cero', () {
      final accumulator = RouteDistanceAccumulator();

      accumulator.addLocation(const LatLng(-37.3217, -59.1332));

      expect(accumulator.distanceMeters, 0);
    });

    test('acumula solo el desplazamiento desde la primera ubicación', () {
      final accumulator = RouteDistanceAccumulator();
      const firstPoint = LatLng(-37.3217, -59.1332);
      final secondPoint = LatLng(firstPoint.latitude + 0.00005, firstPoint.longitude);

      accumulator
        ..addLocation(firstPoint)
        ..addLocation(secondPoint);

      expect(accumulator.distanceMeters, greaterThan(3));
      expect(accumulator.distanceMeters, lessThan(10));
    });

    test('descarta saltos GPS y vuelve a usar ese punto como referencia', () {
      final accumulator = RouteDistanceAccumulator();
      const firstPoint = LatLng(-37.3217, -59.1332);
      const jumpPoint = LatLng(-37.32, -59.1332);
      final nextPoint = LatLng(jumpPoint.latitude + 0.00005, jumpPoint.longitude);

      accumulator
        ..addLocation(firstPoint)
        ..addLocation(jumpPoint);
      final distanceAfterJump = accumulator.distanceMeters;
      accumulator.addLocation(nextPoint);

      expect(distanceAfterJump, 0);
      expect(accumulator.distanceMeters, greaterThan(3));
      expect(accumulator.distanceMeters, lessThan(10));
    });

    test('reanuda desde una nueva referencia sin sumar movimiento en pausa', () {
      final accumulator = RouteDistanceAccumulator();
      const firstPoint = LatLng(-37.3217, -59.1332);
      final secondPoint = LatLng(firstPoint.latitude + 0.00005, firstPoint.longitude);
      final resumedPoint = LatLng(secondPoint.latitude + 0.0005, secondPoint.longitude);

      accumulator
        ..addLocation(firstPoint)
        ..addLocation(secondPoint);
      final distanceBeforePause = accumulator.distanceMeters;
      accumulator
        ..resetBaseline()
        ..addLocation(resumedPoint);

      expect(accumulator.distanceMeters, distanceBeforePause);
    });

    test('calcula el centro promedio de los puntos', () {
      expect(
        RouteCalculator.centerOfPoints(const [LatLng(0, 2), LatLng(2, 4)]),
        const LatLng(1, 3),
      );
    });

    test('devuelve null si la lista de puntos está vacía', () {
      expect(RouteCalculator.centerOfPoints(const []), isNull);
    });
  });
}
