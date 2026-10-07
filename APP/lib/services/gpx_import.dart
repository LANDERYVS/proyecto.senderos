import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:xml/xml.dart';

class GpxRouteData {
  const GpxRouteData({
    required this.name,
    required this.points,
    required this.distanceKm,
    required this.elevationGainMeters,
    required this.elevationLossMeters,
  });

  final String name;
  final List<LatLng> points;
  final double distanceKm;
  final double elevationGainMeters;
  final double elevationLossMeters;
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
      return _readContent(
        await file.readAsString(),
        fallbackName: file.uri.pathSegments.last.replaceFirst(
          RegExp(r'\.gpx$', caseSensitive: false),
          '',
        ),
      );
    } on GpxImportException {
      rethrow;
    } on Exception catch (error) {
      throw GpxImportException('No se pudo leer el archivo GPX: $error');
    }
  }

  Future<GpxRouteData> readUrl(String url) async {
    final uri = Uri.parse(url);
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw GpxImportException(
          'No se pudo descargar el sendero (HTTP ${response.statusCode}).',
        );
      }
      return _readContent(
        await response.transform(const Utf8Decoder()).join(),
        fallbackName: uri.pathSegments.isEmpty
            ? 'Sendero'
            : uri.pathSegments.last,
      );
    } on GpxImportException {
      rethrow;
    } on Exception catch (error) {
      throw GpxImportException('No se pudo cargar el sendero: $error');
    } finally {
      client.close(force: true);
    }
  }

  GpxRouteData _readContent(String content, {required String fallbackName}) {
    try {
      final document = XmlDocument.parse(content);
      final routeElements = [
        ...document.findAllElements('trkpt'),
        ...document.findAllElements('rtept'),
      ];
      final points = <LatLng>[];
      var elevationGainMeters = 0.0;
      var elevationLossMeters = 0.0;
      double? previousElevation;

      for (final element in routeElements) {
        final point = _pointFromElement(element);
        if (point == null) continue;
        points.add(point);

        final elevation = double.tryParse(
          element.getElement('ele')?.innerText.trim() ?? '',
        );
        if (elevation == null) continue;
        if (previousElevation != null) {
          final elevationChange = elevation - previousElevation;
          if (elevationChange > 0) {
            elevationGainMeters += elevationChange;
          } else {
            elevationLossMeters -= elevationChange;
          }
        }
        previousElevation = elevation;
      }

      if (points.length < 2) {
        throw const GpxImportException(
          'El archivo GPX no contiene suficientes puntos de ruta.',
        );
      }

      final name = document
          .findAllElements('name')
          .map((element) => element.innerText.trim())
          .firstWhere((value) => value.isNotEmpty, orElse: () => fallbackName);
      const distanceCalculator = Distance(roundResult: false);
      var distanceKm = 0.0;
      for (var index = 1; index < points.length; index++) {
        distanceKm += distanceCalculator.as(
          LengthUnit.Kilometer,
          points[index - 1],
          points[index],
        );
      }
      return GpxRouteData(
        name: name,
        points: points,
        distanceKm: distanceKm,
        elevationGainMeters: elevationGainMeters,
        elevationLossMeters: elevationLossMeters,
      );
    } on GpxImportException {
      rethrow;
    } on Exception catch (error) {
      throw GpxImportException('No se pudo leer el archivo GPX: $error');
    }
  }

  LatLng? _pointFromElement(XmlElement element) {
    final latitude = double.tryParse(element.getAttribute('lat') ?? '');
    final longitude = double.tryParse(element.getAttribute('lon') ?? '');
    if (latitude == null || longitude == null) return null;
    if (latitude.abs() > 90 || longitude.abs() > 180) return null;
    return LatLng(latitude, longitude);
  }
}
