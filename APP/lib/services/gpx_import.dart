import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:xml/xml.dart';

class GpxRouteData {
  const GpxRouteData({required this.name, required this.points});

  final String name;
  final List<LatLng> points;
}

class GpxImportException implements Exception {
  const GpxImportException(this.message);

  final String message;

  @override
  String toString() => message;
}

class GpxImportService {
  Future<File?> pickGpxFile() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['gpx'],
    );
    final path = files.isEmpty ? null : files.single.path;
    return path == null ? null : File(path);
  }

  Future<GpxRouteData> read(File file) async {
    try {
      final document = XmlDocument.parse(await file.readAsString());
      final points = [
        ...document.findAllElements('trkpt'),
        ...document.findAllElements('rtept'),
      ].map(_pointFromElement).whereType<LatLng>().toList();

      if (points.length < 2) {
        throw const GpxImportException(
          'El archivo GPX no contiene suficientes puntos de ruta.',
        );
      }

      final name = document
          .findAllElements('name')
          .map((element) => element.innerText.trim())
          .firstWhere(
            (value) => value.isNotEmpty,
            orElse: () => file.uri.pathSegments.last.replaceFirst(
              RegExp(r'\.gpx$', caseSensitive: false),
              '',
            ),
          );
      return GpxRouteData(name: name, points: points);
    } on GpxImportException {
      rethrow;
    } on Exception catch (error) {
      throw GpxImportException('No se pudo leer el archivo GPX: $error');
    }
  }

  Future<File> importFile({required File source, required String name}) async {
    final directory = await getApplicationDocumentsDirectory();
    final safeName = name
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final baseName = '${safeName.isEmpty ? 'sendero' : safeName}_$timestamp';
    final destination = File('${directory.path}/$baseName.gpx');
    await source.copy(destination.path);
    await File('${directory.path}/$baseName.json').writeAsString(
      jsonEncode({
        'name': name,
        'description': 'Importado desde un archivo GPX',
        'difficulty': 'Fácil',
        'photos': <String>[],
        'createdByUser': true,
        'isFavorite': false,
        'createdAt': DateTime.now().toIso8601String(),
      }),
    );
    return destination;
  }

  LatLng? _pointFromElement(XmlElement element) {
    final latitude = double.tryParse(element.getAttribute('lat') ?? '');
    final longitude = double.tryParse(element.getAttribute('lon') ?? '');
    if (latitude == null || longitude == null) return null;
    if (latitude.abs() > 90 || longitude.abs() > 180) return null;
    return LatLng(latitude, longitude);
  }
}
