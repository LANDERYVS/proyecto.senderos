import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../models/explore_trail.dart';
import '../models/saved_route.dart';

class SenderosLocalesService {
  static const _uuid = Uuid();

  Future<List<SavedRoute>> loadRoutes() async {
    final directory = await getApplicationDocumentsDirectory();
    final files =
        directory
            .listSync()
            .whereType<File>()
            .where((file) => file.path.toLowerCase().endsWith('.gpx'))
            .toList()
          ..sort(
            (first, second) =>
                second.statSync().modified.compareTo(first.statSync().modified),
          );

    final routes = <SavedRoute>[];
    for (final file in files) {
      final metadataFile = File(file.path.replaceFirst('.gpx', '.json'));
      Map<String, dynamic>? metadata;
      if (await metadataFile.exists()) {
        try {
          metadata =
              jsonDecode(await metadataFile.readAsString())
                  as Map<String, dynamic>;
        } on FormatException {
          metadata = null;
        }
      }
      routes.add(SavedRoute(file: file, metadata: metadata));
    }
    return routes;
  }

  Future<void> updateRouteDetails({
    required SavedRoute route,
    required String name,
    required String description,
    required String difficulty,
    XFile? photo,
  }) async {
    final metadataFile = File(
      route.file.path.replaceFirst(
        RegExp(r'\.gpx$', caseSensitive: false),
        '.json',
      ),
    );
    final metadata = Map<String, dynamic>.from(route.metadata ?? {})
      ..['name'] = name
      ..['description'] = description
      ..['difficulty'] = difficulty;
    if (photo != null) {
      final photoPaths = (metadata['photos'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList();
      final extension = photo.path.contains('.')
          ? photo.path.substring(photo.path.lastIndexOf('.')).toLowerCase()
          : '.jpg';
      final routeName = route.file.uri.pathSegments.last.replaceFirst(
        RegExp(r'\.gpx$', caseSensitive: false),
        '',
      );
      final photoDirectory = Directory(
        '${route.file.parent.path}${Platform.pathSeparator}$routeName',
      );
      await photoDirectory.create(recursive: true);
      final photoName = 'foto_${_uuid.v4()}$extension';
      await File(
        photo.path,
      ).copy('${photoDirectory.path}${Platform.pathSeparator}$photoName');
      final savedPhotoPath = '$routeName${Platform.pathSeparator}$photoName';
      if (photoPaths.isEmpty) {
        photoPaths.add(savedPhotoPath);
      } else {
        photoPaths[0] = savedPhotoPath;
      }
      metadata['photos'] = photoPaths;
    }
    await metadataFile.writeAsString(jsonEncode(metadata));
  }

  Future<File?> findDownloadedTrail(ExploreTrail trail) async {
    final sourceKey = trail.gpxKey;
    if (sourceKey == null || sourceKey.isEmpty) return null;

    for (final route in await loadRoutes()) {
      if (route.favoriteSourceKey != sourceKey &&
          route.downloadedSourceKey != sourceKey) {
        continue;
      }
      if (await route.file.exists()) return route.file;
    }
    return null;
  }

  Future<File> downloadTrailForOffline(ExploreTrail trail) async {
    final sourceKey = trail.gpxKey;
    final url = trail.gpxUrl;
    if (sourceKey == null || sourceKey.isEmpty || url == null) {
      throw const HttpException(
        'Este sendero no tiene un archivo GPX disponible.',
      );
    }

    final routes = await loadRoutes();
    for (final route in routes) {
      if (route.favoriteSourceKey != sourceKey &&
          route.downloadedSourceKey != sourceKey) {
        continue;
      }
      final metadata = Map<String, dynamic>.from(route.metadata ?? {})
        ..['downloadedSourceKey'] = sourceKey
        ..['gpxDownloaded'] = true
        ..['senderoId'] = trail.id
        ..['name'] = trail.name
        ..['description'] = trail.description
        ..['difficulty'] = trail.difficulty
        ..['distanceKm'] = trail.distanceKm
        ..['photoUrl'] = trail.photoUrl
        ..['author'] = trail.author
        ..['authorPhotoUrl'] = trail.authorPhotoUrl;
      await File(
        route.file.path.replaceFirst(
          RegExp(r'\.gpx$', caseSensitive: false),
          '.json',
        ),
      ).writeAsString(jsonEncode(metadata));
      return route.file;
    }

    final directory = await getApplicationDocumentsDirectory();
    final fileBaseName = 'sendero_${_uuid.v4()}';
    final routeFile = File('${directory.path}/$fileBaseName.gpx');
    final temporaryFile = File('${routeFile.path}.download');
    final metadataFile = File('${directory.path}/$fileBaseName.json');
    final metadataTemporaryFile = File('${metadataFile.path}.tmp');
    final client = HttpClient();

    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('HTTP ${response.statusCode}', uri: Uri.parse(url));
      }
      await response.pipe(temporaryFile.openWrite());
      await metadataTemporaryFile.writeAsString(
        jsonEncode({
          'name': trail.name,
          'description': trail.description,
          'difficulty': trail.difficulty,
          'distanceKm': trail.distanceKm,
          'createdByUser': false,
          'isFavorite': false,
          'availableOffline': false,
          'gpxDownloaded': true,
          'downloadedSourceKey': sourceKey,
          'senderoId': trail.id,
          'photoUrl': trail.photoUrl,
          'author': trail.author,
          'authorPhotoUrl': trail.authorPhotoUrl,
          'createdAt': DateTime.now().toIso8601String(),
        }),
      );
      await temporaryFile.rename(routeFile.path);
      await metadataTemporaryFile.rename(metadataFile.path);
      return routeFile;
    } on Exception {
      if (await temporaryFile.exists()) await temporaryFile.delete();
      if (await metadataTemporaryFile.exists()) {
        await metadataTemporaryFile.delete();
      }
      if (await routeFile.exists() && !await metadataFile.exists()) {
        await routeFile.delete();
      }
      rethrow;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> markTrailAvailableOffline(ExploreTrail trail) async {
    final routeFile = await findDownloadedTrail(trail);
    if (routeFile == null) {
      throw const FileSystemException('No se encontró el GPX descargado.');
    }

    final metadataFile = File(
      routeFile.path.replaceFirst(
        RegExp(r'\.gpx$', caseSensitive: false),
        '.json',
      ),
    );
    Map<String, dynamic> metadata = {};
    if (await metadataFile.exists()) {
      metadata =
          jsonDecode(await metadataFile.readAsString()) as Map<String, dynamic>;
    }
    metadata
      ..['availableOffline'] = true
      ..['mapDownloaded'] = true
      ..['downloadedSourceKey'] = trail.gpxKey
      ..['senderoId'] = trail.id;
    await metadataFile.writeAsString(jsonEncode(metadata));
  }

  Future<void> saveFavorite(ExploreTrail trail) async {
    final senderoId = trail.id;
    final sourceKey = trail.gpxKey;
    final url = trail.gpxUrl;
    if (senderoId == null ||
        sourceKey == null ||
        sourceKey.isEmpty ||
        url == null) {
      throw const HttpException(
        'Este sendero no tiene un archivo GPX disponible.',
      );
    }

    final routes = await loadRoutes();
    for (final route in routes) {
      if (route.favoriteSourceKey != sourceKey &&
          route.downloadedSourceKey != sourceKey) {
        continue;
      }
      final metadata = Map<String, dynamic>.from(route.metadata ?? {})
        ..['isFavorite'] = true
        ..['favoriteSenderoId'] = senderoId;
      final metadataFile = File(route.file.path.replaceFirst('.gpx', '.json'));
      await metadataFile.writeAsString(jsonEncode(metadata));
      return;
    }

    final directory = await getApplicationDocumentsDirectory();
    final fileBaseName = 'favorito_${_uuid.v4()}';
    final routeFile = File('${directory.path}/$fileBaseName.gpx');
    final temporaryFile = File('${routeFile.path}.download');
    final metadataFile = File('${directory.path}/$fileBaseName.json');
    final metadataTemporaryFile = File('${metadataFile.path}.tmp');
    final client = HttpClient();

    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('HTTP ${response.statusCode}', uri: Uri.parse(url));
      }
      await response.pipe(temporaryFile.openWrite());
      await metadataTemporaryFile.writeAsString(
        jsonEncode({
          'name': trail.name,
          'description': trail.description,
          'difficulty': trail.difficulty,
          'distanceKm': trail.distanceKm,
          'createdByUser': false,
          'isFavorite': true,
          'favoriteSourceKey': sourceKey,
          'favoriteSenderoId': senderoId,
          'photoUrl': trail.photoUrl,
          'createdAt': DateTime.now().toIso8601String(),
        }),
      );
      await metadataTemporaryFile.rename(metadataFile.path);
      await temporaryFile.rename(routeFile.path);
    } on Exception {
      if (await temporaryFile.exists()) await temporaryFile.delete();
      if (await metadataTemporaryFile.exists()) {
        await metadataTemporaryFile.delete();
      }
      rethrow;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> removeFavoriteCache(ExploreTrail trail) async {
    final routes = await loadRoutes();
    for (final route in routes) {
      final matchesSourceKey =
          trail.gpxKey != null &&
          (route.favoriteSourceKey == trail.gpxKey ||
              route.downloadedSourceKey == trail.gpxKey);
      final matchesSenderoId =
          trail.id != null && route.favoriteSenderoId == trail.id;
      if (!matchesSourceKey && !matchesSenderoId) {
        continue;
      }
      final metadata = Map<String, dynamic>.from(route.metadata ?? {})
        ..['isFavorite'] = false;
      final metadataFile = File(route.file.path.replaceFirst('.gpx', '.json'));
      await metadataFile.writeAsString(jsonEncode(metadata));
    }
  }

  Future<void> shareRoute(SavedRoute route) async {
    final files = <XFile>[XFile(route.file.path)];
    final metadataFile = File(route.file.path.replaceFirst('.gpx', '.json'));
    if (await metadataFile.exists()) {
      files.add(XFile(metadataFile.path));
    }

    for (final photoPath in route.photos) {
      final photo = File('${route.file.parent.path}/$photoPath');
      if (await photo.exists()) {
        files.add(XFile(photo.path));
      }
    }

    await SharePlus.instance.share(ShareParams(files: files, text: route.name));
  }
}
