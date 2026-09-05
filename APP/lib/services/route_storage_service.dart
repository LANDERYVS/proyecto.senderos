import 'dart:convert';
import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';

class RouteStorageService {
  Future<bool> saveRoute({
    required List<LatLng> points,
    required String routeName,
    required String description,
    required String difficulty,
    required List<XFile> photos,
    required double distanceKm,
  }) async {
    if (points.isEmpty) return false;

    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final safeName = routeName
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final fileBaseName =
        '${safeName.isEmpty ? 'trayecto' : safeName}_$timestamp';
    final gpxFile = File('${directory.path}/$fileBaseName.gpx');
    final pointsXml = points
        .map(
          (point) =>
              '      <trkpt lat="${point.latitude}" lon="${point.longitude}"/>',
        )
        .join('\n');
    final gpx =
        '''<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="Proyecto Senderos"
     xmlns="http://www.topografix.com/GPX/1/1">
  <trk>
    <name>${_escapeXml(routeName)}</name>
    <trkseg>
$pointsXml
    </trkseg>
  </trk>
</gpx>
''';

    await gpxFile.writeAsString(gpx);

    final savedPhotoPaths = <String>[];
    if (photos.isNotEmpty) {
      final photosDirectory = Directory('${directory.path}/$fileBaseName');
      await photosDirectory.create();
      for (var index = 0; index < photos.length; index++) {
        final extension = _fileExtension(photos[index].path);
        final photoName = 'foto_${index + 1}$extension';
        final destination = File('${photosDirectory.path}/$photoName');
        await File(photos[index].path).copy(destination.path);
        savedPhotoPaths.add('$fileBaseName/$photoName');
      }
    }

    final metadataFile = File('${directory.path}/$fileBaseName.json');
    await metadataFile.writeAsString(
      jsonEncode({
        'name': routeName,
        'description': description,
        'difficulty': difficulty,
        'photos': savedPhotoPaths,
        'distanceKm': distanceKm,
        'createdAt': DateTime.now().toIso8601String(),
      }),
    );
    return true;
  }

  String _fileExtension(String path) {
    final dotIndex = path.lastIndexOf('.');
    return dotIndex == -1 ? '.jpg' : path.substring(dotIndex).toLowerCase();
  }

  String _escapeXml(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}
