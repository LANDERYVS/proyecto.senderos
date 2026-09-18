import 'dart:convert';
import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/saved_route.dart';
import 'r2_storage_service.dart';

class RoutePublishException implements Exception {
  const RoutePublishException(this.message);

  final String message;

  @override
  String toString() => message;
}

class RouteStorageService {
  static const _uuid = Uuid();

  RouteStorageService({R2StorageService? r2StorageService})
    : _r2StorageService = r2StorageService ?? R2StorageService();

  final R2StorageService _r2StorageService;

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
        'createdByUser': true,
        'isFavorite': false,
        'createdAt': DateTime.now().toIso8601String(),
      }),
    );

    await publishRoute(
      SavedRoute(
        file: gpxFile,
        metadata: {
          'name': routeName,
          'description': description,
          'difficulty': difficulty,
          'photos': savedPhotoPaths,
          'distanceKm': distanceKm,
        },
      ),
    );

    return true;
  }

  Future<void> publishRoute(SavedRoute route) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      throw const RoutePublishException(
        'Debes iniciar sesión para publicar el sendero.',
      );
    }
    if (!await route.file.exists()) {
      throw const RoutePublishException(
        'No se encontró el archivo GPX en el dispositivo.',
      );
    }

    final senderoId = _uuid.v4();
    final objectPrefix = '${user.id}/$senderoId';

    String remoteGpxPath;
    try {
      remoteGpxPath = await _r2StorageService.uploadGpxToR2(
        file: route.file,
        objectPrefix: objectPrefix,
      );
    } on Exception catch (error) {
      throw RoutePublishException(
        'No se pudo subir el archivo GPX. Comprueba tu conexión. ($error)',
      );
    }

    final remotePhotoPaths = <String>[];
    for (var index = 0; index < route.photos.length; index++) {
      final localPhoto = File(
        '${route.file.parent.path}/${route.photos[index]}',
      );
      if (!await localPhoto.exists()) {
        throw RoutePublishException(
          'No se encontró la foto ${index + 1} en el dispositivo.',
        );
      }

      final extension = _fileExtension(localPhoto.path);
      try {
        final remotePath = await _r2StorageService.uploadFileToR2(
          file: localPhoto,
          folder: 'foto_senderos',
          contentType: _contentTypeForExtension(extension),
          objectPrefix: objectPrefix,
        );
        remotePhotoPaths.add(remotePath);
      } on Exception catch (error) {
        throw RoutePublishException(
          'No se pudo subir la foto ${index + 1}. Comprueba tu conexión. ($error)',
        );
      }
    }

    try {
      await Supabase.instance.client.from('senderos').insert({
        // La BD genera id (bigint identity) automáticamente.
        'user_id': user.id,
        'sendero_nick': route.name,
        'descripcion': route.description,
        'dificultad': route.difficulty,
        'distancia': route.metadata?['distanceKm'],
        'gpx_key': remoteGpxPath,
        'foto_sendero': remotePhotoPaths.isEmpty
            ? null
            : remotePhotoPaths.first,
        'fecha_creacion': DateTime.now().toIso8601String(),
      });
    } on Exception catch (error) {
      throw RoutePublishException(
        'Los archivos se subieron, pero no se pudieron guardar los datos '
        'del sendero en Supabase. ($error)',
      );
    }
  }

  String _fileExtension(String path) {
    final dotIndex = path.lastIndexOf('.');
    return dotIndex == -1 ? '.jpg' : path.substring(dotIndex).toLowerCase();
  }

  String _contentTypeForExtension(String extension) {
    switch (extension) {
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  String _escapeXml(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}
