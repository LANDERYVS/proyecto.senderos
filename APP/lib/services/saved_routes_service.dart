import 'dart:convert';
import 'dart:io';

import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../models/saved_route.dart';

class SavedRoutesService {
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
