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

      expect(calculator.calculateIncrementMeters(base, movedPoint) > 3.0, isTrue);
    });
  });
}
