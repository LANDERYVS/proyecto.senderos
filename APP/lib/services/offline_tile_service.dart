import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_map/flutter_map.dart';
import 'package:path_provider/path_provider.dart';

typedef TileDownloadProgress = void Function(int completed, int total);

/// Descarga y sirve teselas raster para poder consultar una zona sin red.
class OfflineTileService {
  static const _tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const _userAgent = 'proyecto.senderos/1.0 contacto@ejemplo.com';

  Future<Directory> _tilesDirectory() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final directory = Directory(
      '${documentsDirectory.path}${Platform.pathSeparator}offline_tiles_tandil',
    );
    await directory.create(recursive: true);
    return directory;
  }

  /// Descarga todas las teselas dentro de [bounds] y entre los zooms indicados.
  /// Devuelve cuantas teselas nuevas se guardaron.
  Future<int> downloadRegion({
    required LatLngBounds bounds,
    int minZoom = 12,
    int maxZoom = 16,
    TileDownloadProgress? onProgress,
  }) async {
    if (minZoom < 0 || maxZoom < minZoom || maxZoom > 19) {
      throw ArgumentError('El rango de zoom debe estar entre 0 y 19');
    }

    final directory = await _tilesDirectory();
    final tiles = <_TileCoordinate>[];
    for (var zoom = minZoom; zoom <= maxZoom; zoom++) {
      final northWest = _tileCoordinate(bounds.north, bounds.west, zoom);
      final southEast = _tileCoordinate(bounds.south, bounds.east, zoom);
      for (var x = northWest.x; x <= southEast.x; x++) {
        for (var y = northWest.y; y <= southEast.y; y++) {
          tiles.add(_TileCoordinate(x, y, zoom));
        }
      }
    }

    var completed = 0;
    var downloaded = 0;
    final client = HttpClient()..userAgent = _userAgent;
    try {
      for (final tile in tiles) {
        final file = File(
          '${directory.path}${Platform.pathSeparator}${tile.zoom}${Platform.pathSeparator}${tile.x}${Platform.pathSeparator}${tile.y}.png',
        );
        if (!await file.exists()) {
          await file.parent.create(recursive: true);
          final request = await client.getUrl(
            Uri.parse(
              _tileUrl
                  .replaceAll('{z}', '${tile.zoom}')
                  .replaceAll('{x}', '${tile.x}')
                  .replaceAll('{y}', '${tile.y}'),
            ),
          );
          final response = await request.close();
          if (response.statusCode != HttpStatus.ok) {
            throw HttpException(
              'No se pudo descargar ${tile.zoom}/${tile.x}/${tile.y}',
              uri: request.uri,
            );
          }
          await file.writeAsBytes(
            await response.fold<List<int>>(
              <int>[],
              (bytes, chunk) => bytes..addAll(chunk),
            ),
          );
          downloaded++;
        }
        completed++;
        onProgress?.call(completed, tiles.length);
      }
    } finally {
      client.close(force: true);
    }
    return downloaded;
  }

  /// Crea una capa que solo lee las teselas guardadas en el dispositivo.
  Future<TileLayer> offlineTileLayer() async {
    final directory = await _tilesDirectory();
    return TileLayer(
      urlTemplate:
          '${directory.path}${Platform.pathSeparator}{z}${Platform.pathSeparator}{x}${Platform.pathSeparator}{y}.png',
      tileProvider: FileTileProvider(),
      userAgentPackageName: 'com.example.proyecto',
    );
  }

  /// Indica si ya existe al menos una tesela descargada en el dispositivo.
  Future<bool> hasDownloadedTiles() async {
    final directory = await _tilesDirectory();
    if (!await directory.exists()) return false;

    await for (final entity in directory.list(recursive: true)) {
      if (entity is File && entity.path.toLowerCase().endsWith('.png')) {
        return true;
      }
    }
    return false;
  }

  _TileCoordinate _tileCoordinate(double latitude, double longitude, int zoom) {
    final scale = 1 << zoom;
    final x = ((longitude + 180) / 360 * scale).floor().clamp(0, scale - 1);
    final sine = math.sin(latitude * math.pi / 180).clamp(-0.9999, 0.9999);
    final y =
        ((0.5 - math.log((1 + sine) / (1 - sine)) / (4 * math.pi)) * scale)
            .floor()
            .clamp(0, scale - 1);
    return _TileCoordinate(x, y, zoom);
  }
}

class _TileCoordinate {
  const _TileCoordinate(this.x, this.y, this.zoom);

  final int x;
  final int y;
  final int zoom;
}
