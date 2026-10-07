import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto/services/gpx_import.dart';

void main() {
  test('lee distancia y desnivel del GPX importado', () async {
    final directory = await Directory.systemTemp.createTemp('gpx_import_test_');
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });

    final file = File('${directory.path}/sendero.gpx');
    await file.writeAsString('''
<gpx version="1.1" creator="test">
  <trk>
    <name>Sendero de prueba</name>
    <trkseg>
      <trkpt lat="-37.0" lon="-59.0"><ele>100</ele></trkpt>
      <trkpt lat="-37.001" lon="-59.0"><ele>115</ele></trkpt>
      <trkpt lat="-37.002" lon="-59.0"><ele>108</ele></trkpt>
    </trkseg>
  </trk>
</gpx>
''');

    final route = await GpxImportService().read(file);

    expect(route.name, 'Sendero de prueba');
    expect(route.points, hasLength(3));
    expect(route.distanceKm, greaterThan(0.2));
    expect(route.elevationGainMeters, 15);
    expect(route.elevationLossMeters, 7);
  });
}
