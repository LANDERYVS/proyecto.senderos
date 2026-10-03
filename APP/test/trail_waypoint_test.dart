import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:proyecto/models/trail_waypoint.dart';

void main() {
  test('lee y serializa un waypoint con el formato de Supabase', () {
    final waypoint = TrailWaypoint.fromMap({
      'type': 'vista',
      'lat': -37.32,
      'long': -59.13,
    });

    expect(waypoint.type, 'vista');
    expect(waypoint.point, const LatLng(-37.32, -59.13));
    expect(waypoint.toMap(), {'type': 'vista', 'lat': -37.32, 'long': -59.13});
  });

  test('rechaza coordenadas y tipos inválidos', () {
    expect(
      () => TrailWaypoint.fromMap({'type': 'vista', 'lat': 91, 'long': -59.13}),
      throwsFormatException,
    );
    expect(
      () => TrailWaypoint.fromMap({'type': '', 'lat': -37.32, 'long': -59.13}),
      throwsFormatException,
    );
  });

  test('decodifica waypoints almacenados como metadatos locales', () {
    final waypoints = TrailWaypoint.fromMetadata([
      {'type': 'Bebedero', 'lat': -37.32, 'long': -59.13},
    ]);

    expect(waypoints, hasLength(1));
    expect(waypoints.single.type, 'Bebedero');
  });
}
